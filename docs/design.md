# Peal — design

Peal turns a repository's tasks into a process Claude Code sessions can follow: task
files with YAML frontmatter, and commands that claim, plan, implement, close, file,
split, defer, revise and retire them, grouped by milestones.

Peal generalises the task-file process of one real project, the *reference project*.
That process grew under daily use: every script and rule in it exists because a session
once went wrong without it. Peal keeps those lessons and drops what only that project
needs. Issue #2 settled the decisions below; the build is split into the issues listed at the end.

## Principles

- **Tasks and their state live in git.** A task is a file; who holds it is derived from
  refs (a task branch, its worktree, the file's directory on the main branch), never from
  a status field someone must remember to update. Any worktree, on any branch, gets the
  same answer.
- **The pushed branch is the lock.** A claim pushes the task's branch; a second claim of
  the same task fails on git's own rejection. Numbering new tasks works the same way: a
  push that loses the race retries with the next number.
- **What must happen every time is a hook or a refusing script, not a reminder.** Prose
  in a command is for judgement; anything checkable is checked.
- **Hooks come from outside the branch.** A branch cannot weaken the gates policing it.
  The reference got this by running hooks from the primary checkout; Peal gets it for
  free, since the plugin's hooks come from the installed plugin, not the working tree.
- **One task, one session, one branch, one worktree, one pull request.** A session ends
  when its PR is open and its checks are green; the merge is the human's.
- **Generic in Peal, specific in the project.** Peal calls into the project where the
  project knows better (its checks, its context documents, its PR sections), and never
  absorbs the project's own tooling.

## Peal and Belfry

Peal and [Belfry](https://github.com/Maximilian-Walz/belfry) are separate projects that
fit together.

- **Peal never needs Belfry.** Every command works in an interactive session with
  nobody else involved.
- **Belfry never knows Peal.** Belfry talks to projects through its contract
  (`.belfry.yml`); Peal is one tooling that answers it.

Where they meet is small and written down, so either can change without the other
following:

| | Peal provides | Belfry expects |
|---|---|---|
| tasks | list, offer, claim (printing the worktree), board and idea commands | the `commands` backend of its contract |
| milestones | milestones as data | a milestone list in the board output |
| a session | `/peal:work` and `/peal:close` in the claimed worktree | claim before the session; finished means a PR open and green |
| the human | questions through `AskUserQuestion` | routes them to its inbox |

A project's `.belfry.yml` for Peal is then:

```yaml
tasks:
  backend: commands
  commands:
    list: .peal/peal list
    offer: .peal/peal offer "{pool}" --top 10
    pool: current,unassigned
    claim: .peal/peal claim {task} --print-path
    start: /peal:work {task}
    idea: /peal:idea {idea}
    board: .peal/peal board
```

- `list` prints `NNNN state slug detail...`, states `free`, `claimed-live`, `parked`,
  `awaiting-merge`, `blocked`, `done` (see [Claim states](#claim-states)). The detail of
  a free task is its milestone (`-` for none) and, in a split, `split:<origin>
  <done>/<total>`; of a blocked one `needs:<id>,...`; of a claim `wt:<path>`,
  `remote:<remote>`, `N commit(s) ahead, last <date>`, or `pr:#N <url>` (`pr:unknown`
  without `gh`).
- `offer` prints `CANDIDATE <id> <bucket> <title>` lines for a pool, best first.
- `claim` is idempotent: a task already claimed on this machine prints its existing
  worktree, so a re-run Belfry job continues where the last one stopped. The last line is
  the worktree path.
- `board` prints one JSON object per task (`id`, `state`, `slug`, `title`, `milestone`,
  `depends`, `part_of`, `size`, `plan`, `needs`, `pr`, `path`, `ref`), and one
  `{"milestone":{...}}` line per milestone, exactly the shapes of Belfry's contract.
- `/peal:work NNNN` notices it is already inside NNNN's worktree (the branch is the task's
  branch and `tasks/doing/` holds its file) and skips its own claim. It does not read any
  Belfry variable: the same check serves a human who opened a session in the worktree by
  hand. The reference used a Belfry environment variable here; Peal does without.
- `/peal:close` waits for the PR's checks in the foreground with a budget, re-running
  while the verdict is `WAIT`. That works headless and interactive alike.

## Scope: what moves, what stays

Every piece of the reference's process, and what becomes of it. *Moves*: Peal owns it,
generalised. *Stays*: project-specific, the project keeps it. *Extension point*: Peal
does the generic part and calls something the project provides.

### Commands

| Reference piece | Verdict | Notes |
|---|---|---|
| `/work` | moves | resume, pool offer through `AskUserQuestion`, claim, planner, implementer. The "main's last CI run is red" warning is dropped: it read one project's workflow name. |
| `/close` | moves, with extension points | begin/finish/abort/verify/wait, reviewer, finding routing, Outcome, idea flush, generated PR body. The project supplies its checks and any extra PR sections (the reference asks for a player-facing note and screenshots). |
| `/idea` | moves | triage of `milestone` and `plan` by config ([Configuration](#configuration)); queues on a task branch, files straight away on main. |
| `/split` | moves | pieces with `part-of`, filed in one push. |
| `/defer` | moves | notes back onto the task's backlog file, claim deleted, number kept. |
| `/retire` | moves | unclaimed task to done with a dated reason, straight onto main. |
| `/revise` | moves | unclaimed task's body rewritten in place, straight onto main. |
| `/milestone-review` | moves, with extension points | readiness check, acceptance criteria, triage of the backlog, next milestone. The project supplies its review steps (the reference plays the build with the human, captures a render, runs a code-health counter). |
| `/drift` | moves, with an extension point | the loop (read, compare, file one idea per discrepancy, fix nothing) is generic; the list of what to compare is the project's (`.peal/drift.md`). Its recurring "drift-check" task file does not move: a recurring checklist is a command, not a task. |
| asset-pipeline command (starts a 3D model and briefs the human) | stays | project tooling. It uses Peal's `idea` and `claim` like any other caller. |

### Subagents

| Reference piece | Verdict | Notes |
|---|---|---|
| planner | moves, with an extension point | restatement, approach, size challenge, questions, model verdict. Reads the context documents the project lists instead of the reference's design docs by name. |
| implementer | moves | builds the agreed plan, commits as it goes, hands back `DONE`, `QUESTION` or `STOPPED` with a fixed status block. |
| reviewer | moves, with an extension point | the generic checks (scope, Done when evidence, decisions, repeat rot from the last milestone review). The project's architecture rules come from `.peal/reviewer.md` (the reference checks its engine layering there). |

Model routing moves as defaults: planner and reviewer on Opus, implementer on Sonnet
unless the task's `model:` says otherwise. The project may override them in config.

### Scripts

| Reference piece | Verdict | Notes |
|---|---|---|
| task state (the read model) | moves | behind the storage interface. |
| task offer, task claim, task release | moves | |
| task board | moves | plus milestone lines. |
| task overview (human status summary) | moves | as `peal overview`. |
| idea filing, idea queue | moves | numbering by push-as-lock; batch flush at close. |
| defer (both phases), retire, revise | moves | |
| close begin / finish / abort / verify / wait | moves | project checks as an extension point. |
| PR body generator | moves, with an extension point | Outcome, ideas filed, commits, plus the project's PR sections. |
| commit helper | moves | commit subject grammar is Peal's; the build gate is the project's checks. |
| shared shell library | splits | the git, frontmatter and state helpers move; the build-path regex and everything engine-related stay. |
| Belfry claim gate | dropped | replaced by the worktree check above. |
| Outcome placeholder check | moves | part of `peal check`. |
| PR freshness check and workflow | stays | a CI concern of repositories merging without branch protection; not the task process. A candidate for a later optional module. |
| decisions: reserve, reservation check, supersedes check, index, index publish, decisions-for-paths brief | moves as the optional decisions module | see [Decision records](#decision-records). |
| prompt byte budgets (check and hook) | stays | useful, but not the task process. |
| design-doc index check, engine sidecar check, pipefail-grep lint, code-health counter, engine play/render/bench/dump/selftest scripts, image similarity, PR screenshots to an orphan branch, golden regeneration, the human's direct "tweak" to main, session cost | stays | project tooling. Screenshots reach a PR through the project's PR sections. |
| test fixture library and every `*.test.sh` | moves with its script | Peal's scripts keep the reference's habit: every script has a harness, and CI runs them all. |

### Hooks

| Reference piece | Verdict | Notes |
|---|---|---|
| SessionStart orientation | moves | current milestone, this worktree's task, other claims, open splits. A project adds its own lines with its own hook; Claude Code runs both. |
| SessionStart worktree reaping | moves | landed, clean, pushed and idle worktrees are removed; the tip is kept under `refs/reaped/`. |
| turn budget | moves | nudges at the task's size tier. |
| Stop close guard | moves | silent unless a close is in progress; then refuses an empty Outcome and uncommitted or unpushed work. |
| SessionEnd autosave | moves | `wip:` commit and push of a dirty or unpushed task branch. |
| git guard (PreToolUse on Bash) | moves, generic rules only | no commit on the main branch, no gate bypass, no push to main outside the lifecycle commands. |
| engine layering guard | stays | |
| decision-entry guards | move with the decisions module | |
| byte-budget guard | stays | |
| git `pre-push` | moves | the only thing that lets the lifecycle commands' direct pushes onto main through, and nothing else: added backlog files, one modified backlog file, a backlog-to-done move. |
| git `commit-msg` | moves, with an extension point | subject grammar and task id are Peal's; the build-and-test gate runs the project's `checks.commit`. |
| git LFS delegation hooks | stays | Peal's git hooks chain to a project's own hook of the same name. |

### Documents

| Reference piece | Verdict | Notes |
|---|---|---|
| task template | moves | as Peal's template, frontmatter per [Task files](#task-files). |
| process doc, git doc | move as Peal's documentation | the project's own process doc shrinks to what is its own. |
| milestone docs | stay the project's content | in Peal's milestone format ([Milestones](#milestones)). |
| decision records | stay the project's content | the module only provides the tooling. |
| `.belfry.yml` | stays | a few lines, shown above. |

## Task files

A task is a Markdown file `tasks/<dir>/NNNN-slug.md`. The number is four digits, the slug
2–5 kebab-case words. Its state is the directory (`backlog`, `doing`, `done`) together
with refs; there is no status field. The title is the first heading, `# NNNN — Title`.

The header is real YAML frontmatter:

```markdown
---
milestone: m08
plan: required
size: M
depends: [0271, human]
part-of: 0190
needs: [display, gpu]
model: opus
---

# 0305 — Title

## Intent
## Scope
## Done when
## Raw
## Notes

---

## Outcome
```

Peal's fields, all optional:

| Field | Meaning |
|---|---|
| `milestone` | a milestone id; absent means unassigned. |
| `plan` | `required` or `skipped`. `/peal:idea` sets it from the config's `plan.required-paths` and the declared size. |
| `size` | `S`, `M` or `L`, tool-call tiers from config; empty until the planner sizes it. |
| `depends` | a list of task ids that must be done first, plus two keywords: `milestone` (every other task of this task's milestone, written only on a milestone's review task) and `human` (never resolves by itself). Depending on a task that was split waits for it and all its pieces. |
| `part-of` | the task this one was split from; filed by `/peal:split` only. |
| `needs` | capabilities a worker must have, Belfry's vocabulary; carried to the board. |
| `model` | the implementer's model when not the default, written after the human agrees the plan. |

**A project may add its own fields,** declared in `.peal/config.yml` under
`task.fields` (name, and optionally the allowed values). Peal carries them through every
command unchanged and refuses undeclared keys when filing, so a typo fails at once
instead of being ignored forever.

Peal reads and writes a small subset of YAML: scalars, and lists of scalars in flow
(`[a, b]`) or block style. That keeps the scripts dependency-free (bash and git on a bare
machine, as in the reference) while every file stays valid YAML for any other tool.

The section structure (`Intent`, `Scope`, `Done when`, `Raw`, `Notes`, `Outcome`) is a
convention Peal's commands rely on: `Raw` is the human's words and never rewritten,
`Outcome` is written at close and must not be empty or a placeholder.

### Claim states

Derived from refs and the main branch on the remote, never from the calling worktree:

| State | Means |
|---|---|
| `free` | no branch; claimable |
| `claimed-live` | the branch has a worktree, or exists only on the remote |
| `parked` | a local branch ahead of main without a worktree; `claim` resumes it |
| `awaiting-merge` | the branch tip holds the task under `done/`; waits for the human's merge |
| `blocked` | a `depends` entry is not done yet |
| `done` | the file is under `done/` on main; outranks every other state |

## Milestones

Milestones are data, the model Belfry shares (its issue #3): an id, a title, a state
(`open`, `current`, `done`, `parked`), an order, and an optional due date.

Each milestone is one Markdown file in the milestones directory (`docs/milestones/` by
default), its data as frontmatter and its prose (goal, acceptance criteria, the review)
as the body:

```markdown
---
id: m08
title: Combat
state: current
order: 8
due: 2026-11-01
---
```

`id` defaults to the file name without `.md`, `title` to the first heading. Peal refuses
a milestones directory with more than one `current` milestone. The state is written, not
inferred: the reference took "the newest milestone doc" as current, which cannot
express a parked milestone or one planned ahead.

What the states mean to Peal:

| State | Offered by a bare `/peal:work` | Claimable by number |
|---|---|---|
| `current` | yes, first | yes |
| no milestone | yes, after `current` | yes |
| `open` | no; `/peal:work <milestone-id>` offers it | yes |
| `parked` | no | no; a milestone review or the human moves the task out first |
| `done` | no | no (its tasks are done) |

The reference's pools map onto this: its current milestone is the `current` one,
"unassigned" is no milestone, "later" is a `parked` milestone, and its "process" pool,
claimed only by name, is an `open` milestone. Its "any" pool held only the recurring drift
check, which becomes `/peal:drift`.

Every milestone has a review task, `depends: [milestone]`, which `/peal:milestone-review`
walks and which marks the milestone `done` and the next one `current`. Milestone files are
read-only during an ordinary task; `/peal:close` warns when a branch touches one.

## Configuration

A project keeps everything of Peal's in `.peal/`:

| Path | What |
|---|---|
| `.peal/config.yml` | settings, below |
| `.peal/peal` | the launcher, committed ([Distribution](#distribution)) |
| `.peal/reviewer.md`, `.peal/planner.md` | optional: the project's own rules for these subagents, appended to their prompts |
| `.peal/drift.md` | optional: what `/peal:drift` compares |
| `.peal/review.md` | optional: the project's steps for `/peal:milestone-review` |

Settings, all optional, with their defaults:

```yaml
remote: origin
main: main                      # the branch tasks land on
tasks: tasks                    # holds backlog/, doing/, done/ and TEMPLATE.md
milestones: docs/milestones
branch-prefix: task/
worktrees: ../{repo}-wt         # each claim is {worktrees}/NNNN-slug
sizes: {S: 60, M: 120, L: 200}  # tool calls; the turn budget nudges at the tier
plan:
  required-paths: []            # a task touching one of these gets plan: required
review:
  skip-paths: [docs/, tasks/]   # a diff only here skips the reviewer
context: []                     # documents the planner, reviewer and /peal:idea read
checks:
  commit: []                    # commands the commit-msg gate runs; each may name paths it applies to
  close: []                     # commands close runs before opening the PR
pr:
  sections: []                  # extra prose sections close asks the session for: title and instruction
commit:
  areas: []                     # allowed <area> values in commit subjects; empty allows any
models: {planner: opus, reviewer: opus, implementer: sonnet}
task:
  fields: {}                    # the project's own frontmatter fields
storage: files                  # where tasks live; files, the task files, is the one there is
decisions: false                # the decisions module, or its directory to turn it on
```

Conventions with no setting: the `backlog`/`doing`/`done` directories, `NNNN-slug.md`
names, one task per branch and PR, the task sections, the commit subject grammar
`<type>(<area>): <what> [NNNN]`, which pushes may reach main directly, and the close
sequence. A setting exists only where two real projects would differ.

## Storage

Two things are kept apart: *where tasks live*, and *how a session works a task*. The
workflow (plan, implement, close, the PR conventions, milestone review) is Peal's value
and would serve a project whose tasks are GitHub issues too. So the commands talk to a
small storage interface, and task files are its first and, for now, only implementation.
An issues implementation comes when a project wants Peal's workflow on its issues.
Belfry already *reads* tasks from either place; Peal does not duplicate that.

The interface:

| Operation | Task files | Issues (not built) |
|---|---|---|
| `list` → id, state, fields | the read model over refs and main | issues, labels, linked PRs |
| `read id` → fields, body | the file on main or its branch | the issue body |
| `create fields body [part-of]` → id | a new backlog file pushed to main, numbered by push-as-lock | a new issue (with "Part of #N") |
| `edit id fields body reason` | the backlog file rewritten on main, reason in `## Notes` | the body edited, reason as a comment |
| `set-milestone id m` | the frontmatter field | the issue's milestone |
| `claim id` → worktree | the branch pushed, worktree added, file moved to `doing/` | label `in progress`, worktree, branch |
| `release id notes` | notes back to the backlog file, branch deleted | label removed, notes as a comment |
| `finish id done` | file moved to `done/` with its Outcome, in the PR | PR with `Fixes #N` |
| `finish id retired reason` | file moved to `done/` with the reason, on main | closed as not planned, with the reason |
| `comment id text` (optional) | appended under `## Notes` | a comment |
| `milestones` | the milestone files | the repository's milestones |

What each lifecycle command does in both kinds:

| Command | Task file | Issue |
|---|---|---|
| `/peal:idea` | new file in the backlog | new issue |
| `/peal:revise` | edit the file | edit the body, reason as a comment |
| `/peal:split` | new files with `part-of` | new issues with "Part of #N" (or GitHub sub-issues) |
| `/peal:defer` | release the claim, notes kept | release the claim, notes as a comment |
| `/peal:retire` | retired, with the reason | closed as not planned, with the reason |
| `/peal:work`, `/peal:close` | claim, worktree, PR | label, worktree, PR with `Fixes #N` |

In the scripts the interface is a set of shell functions (`peal_store_list`,
`peal_store_create`, ...) in one file per implementation, selected by a `storage` setting
that has one value today. The commands and the `peal` CLI call only these functions.
Everything above them (offer ordering, dependency and split expansion, milestone rules,
close) is storage-independent.

## Decision records

An **optional module**, off unless `decisions:` names a directory. Architectural
decisions as numbered, append-only files, with the tooling that keeps them honest:
numbers reserved by push-as-lock (`refs/decisions/NNNN`), a check that an added entry
holds a reservation, the supersedes pairing check, the generated index (never edited in a
PR, regenerated on main after a merge), and the brief of decisions naming the paths a
task or diff touches, which the planner and reviewer read instead of the whole index.

Why a module rather than core or project-specific: nothing in it is specific to one
project, and the close sequence and both subagents integrate with it (a decision entry
committed right before the task's move to done, the brief in their prompts), so leaving
it to each project would mean re-plumbing those integrations. But plenty of projects
record no decisions, and the task process must not require them.

## Distribution

This repository is a Claude Code plugin marketplace with one plugin, `peal`. A project
installs it for everyone working on it, sessions Belfry starts included, through its
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "peal": {"source": {"source": "github", "repo": "Maximilian-Walz/peal"}}
  },
  "enabledPlugins": {"peal@peal": true}
}
```

and runs `/peal:init` once, which writes `.peal/config.yml`, the launcher, the task
template and directories, and sets `core.hooksPath` to Peal's git hooks.

Finding Peal's scripts at run time:

- **Inside Claude Code** (commands, subagents, hooks): `${CLAUDE_PLUGIN_ROOT}`, the
  installed plugin's directory.
- **Outside** (git hooks, Belfry's `commands` backend, a human in a shell): the committed
  launcher `.peal/peal`, a short script that finds the plugin and runs its `peal` CLI.
  It tries `$PEAL_ROOT`, then the root the SessionStart hook records in the repository's
  git directory each session, then the newest Peal in Claude Code's plugin cache, and
  fails with an install hint otherwise.

The `peal` CLI is the one entry point for all scripts (`peal list`, `peal claim`, ...);
commands and hooks call it too, so there is a single place that loads config and storage.

## Migrating an existing project

Adopting Peal is a migration, not a rewrite: tasks keep their numbers, history stays,
the project's own tooling keeps working through the extension points. For a project with
its own task-file process, such as the reference:

1. **Install** the plugin (settings above) and run `/peal:init`, keeping the existing
   `tasks/` layout.
2. **Convert headers.** `peal migrate headers` rewrites each task's `key: value` header
   into a frontmatter block: space- or comma-separated `depends` and `needs` become YAML
   lists, trailing comments are dropped, the pools map to milestones (a numbered milestone
   to its id, "unassigned" to no field, "later" to a `parked` milestone, "process" to an
   `open` one). It prints anything it cannot convert.
3. **Convert milestones.** `peal migrate milestones` adds frontmatter to each milestone
   doc, the newest `current`, earlier ones `done`, and creates the `parked` and `open`
   milestones the pools needed.
4. **Move project settings into config:** plan paths, reviewer skip paths, context
   documents, commit areas, checks (the build and test gate), PR sections.
5. **Replace the generic scripts, commands, subagents and hooks with Peal's,** keeping
   every piece the [scope tables](#scope-what-moves-what-stays) mark as staying, and
   moving project rules for the reviewer and planner into `.peal/`.
6. **Point `.belfry.yml`** at the launcher.

All of it lands as one task, one PR, in the project itself.

## Building Peal

Issue #2 filed one issue per buildable piece, with `Depends on #N` where order matters:

| Issue | Piece | Depends on |
|---|---|---|
| #3 | plugin skeleton: marketplace, `peal` CLI, launcher, config, frontmatter, CI | |
| #4 | milestones as data | #3 |
| #5 | storage interface and the task-file implementation | #3, #4 |
| #6 | git gates: pre-push, commit-msg, commit helper, git guard | #5 |
| #7 | claim, offer, release and the session hooks | #5 |
| #8 | subagents and `/peal:work` | #7, #5 |
| #9 | close | #6, #8 |
| #10 | backlog commands: idea, split, defer, retire, revise | #5, #7 |
| #11 | milestone review and drift | #9, #10 |
| #12 | decisions module | #9 |
| #13 | `/peal:init` and the Belfry integration | #6, #7 |
| #14 | migration from an existing task-file process | #4, #5, #13 |
| #15 | Peal runs on itself | #9, #10, #11, #13 |

Until Peal can run on itself, Belfry runs this repository from those issues
(`.belfry.yml`); #15 switches it over.
