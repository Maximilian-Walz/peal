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
  same answer. (A project whose tasks are GitHub issues keeps them there instead; see
  [Storage](#storage).)
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
| milestones | milestones as data; `peal milestone-state`; `/peal:milestone-review {milestone}` | a milestone list in the board output; `tasks.commands.milestone` for its Close, Park and Un-park; actions with the `milestone` trigger |
| a session | `/peal:work` and `/peal:close` in the claimed worktree | claim before the session; finished means a PR open and green |
| the human | questions through `AskUserQuestion` | routes them to its inbox |
| releases | `/peal:release {version}` | an action marked `release: true`, which its Releases tab's button runs |

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
    milestone: .peal/peal milestone-state {id} {state} --reason {reason}
    retire: .peal/peal retire {task} --reason {reason}
actions:
  milestone-review:
    title: Milestone review
    prompt: /peal:milestone-review {milestone}
    triggers: [milestone]
```

- `list` prints `NNNN state slug detail...`, states `free`, `claimed-live`, `parked`,
  `awaiting-merge`, `blocked`, `done` (see [Claim states](#claim-states)). The detail of
  a free task is its milestone (`-` for none) and, in a split, `split:<origin>
  <done>/<total>`; of a blocked one `needs:<id>,...`, followed by `cycle: 0042 → 0043 →
  0042` when the task lies on a depends cycle (`#42 → #43 → #42` for issues); of a claim
  `wt:<path>`, `remote:<remote>`, `N commit(s) ahead, last <date>`, or `pr:#N <url>`
  (`pr:unknown` without `gh`). A task not done whose priority is not normal ends its
  detail with `priority:<urgent|high|low>`, and a human task not done with `owner:human`.
- `offer` prints `CANDIDATE <id> <bucket> <title>` lines for a pool, best first.
- `claim` is idempotent: a task already claimed on this machine prints its existing
  worktree, so a re-run Belfry job continues where the last one stopped. The last line is
  the worktree path.
- `board` prints one JSON object per task (`id`, `state`, `slug`, `title`, `milestone`,
  `depends`, `part_of`, `size`, `plan`, `needs`, `priority`, `owner`, `touches`, `merge`,
  `pr`, `path`, `ref`, and `cycle`, the list detail's cycle, which the contract lets a
  board add; each but `id` and `state` only when set, so a normal priority, an AI's task
  and the project's default merge are no field), and one
  `{"milestone":{...}}` line per milestone, exactly the shapes of Belfry's contract.
- `/peal:work NNNN` notices it is already inside NNNN's worktree (the branch is the task's
  branch and `tasks/doing/` holds its file) and skips its own claim. It does not read any
  Belfry variable: the same check serves a human who opened a session in the worktree by
  hand. The reference used a Belfry environment variable here; Peal does without.
- `/peal:close` waits for the PR's checks in the foreground with a budget, re-running
  while the verdict is `WAIT`. That works headless and interactive alike.
- `milestone` changes a milestone's state (`done`, `parked`, `open`) in the storage, the
  same change Belfry makes itself on GitHub for its `github-issues` backend; see
  [Milestones](#milestones). The review, an action Belfry offers when a milestone is
  closed, ends with one question, "Close <milestone>?", and makes that change on yes.

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

A subagent's frontmatter cannot read the project's config, so `/peal:work` passes each
its model (`peal work` prints them) and starts each with `peal brief ROLE`: the task, the
main branch, the current milestone, the size tiers, the `context` documents, and
`.peal/planner.md` or `.peal/reviewer.md` verbatim. The planner has no Bash; the brief
gives it what it would otherwise have to parse the config for.

`/peal:work [id | pool]` runs `peal work`, which decides every step a script can: in a
task's worktree (its branch and its claim) it prints the task, where its plan stands
(`required`, `agreed`, `skipped`) and the subagents' models, and claims nothing; outside
one it claims an id, or offers a pool for the human to pick from through
`AskUserQuestion`. After a claim the session enters the worktree (`EnterWorktree`); the
planner runs when the plan is required, and the session stops for the human, asking
through `AskUserQuestion` so the same step works interactive and headless. The agreed
plan goes into the task's `Plan` section, the size, a non-default `model:`, the
planner's `touches` and, only when the human agreed it, `merge: auto` into its frontmatter, and `peal record ID plan` puts that text on the claim (the storage's
`record`). The implementer builds; its `QUESTION`s
go to the human and back to it through `SendMessage`. The main session never writes the
task's code.

The backlog commands call the storage only, through the `peal` CLI:

- `/peal:idea TEXT` composes a task from the human's words in one pass, never asking:
  `milestone` the current one only with direct evidence (else none, never a parked one),
  `plan` from `plan.required-paths`, `size` left to the planner. `peal idea` queues it in
  a task's worktree, for the close to file, and files it at once anywhere else.
- `/peal:split` files the pieces of this worktree's task in one `peal create --part-of`,
  then narrows the task to its first piece (`peal revise` on one's own claim records the
  text there, as `record` does) or closes it as split.
- `/peal:defer REASON` gives a claim back that nothing was built on: `peal defer` writes
  the task's text, with what the session learned, back into the storage under the same
  number (for task files, onto the backlog file on main) and marks the claim deferred;
  `peal release ID`, run from outside the worktree, then deletes it although the task is
  not done, as the SessionStart reaping does once the claim is idle. Work on the branch
  refuses it: that ends through a close.
- `/peal:retire ID REASON` and `/peal:revise ID ...` write straight into the storage, so
  the human confirms first (`revise` shows its `--dry-run` diff); both refuse a claimed
  task.

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
| `depends` | a list of task ids that must be done first, plus two keywords: `milestone` (every other task of this task's milestone, written only on a milestone's review task) and `human` (never resolves by itself). Depending on a task that was split waits for it and all its pieces. A cycle is refused (below). |
| `part-of` | the task this one was split from; filed by `/peal:split` only. |
| `needs` | capabilities a worker must have, Belfry's vocabulary; carried to the board. |
| `model` | the implementer's model when not the default, written after the human agrees the plan. |
| `breaking` | `true` when the task breaks something its users rely on: the next release is a major one ([Releases](#releases)). |
| `release-note` | `none` leaves the task out of the release notes. |
| `priority` | `urgent`, `high`, `normal` or `low`; absent means normal. Orders the offer within a milestone, never across milestones; `/peal:idea` sets it only when the idea says so plainly, `/peal:revise` changes it. The board carries it, `peal overview` marks urgent `!` and high `↑`. |
| `owner` | `ai` or `human`; absent means ai. A human task is work only the human can deliver: the offer never offers it and `/peal:work` refuses it, while `peal claim` still makes its worktree for the human (or Belfry's Start). A `depends` on it waits until it is done, like any other; the `human` keyword, by contrast, never resolves by itself. The board, the list and `peal overview` carry it. |
| `merge` | `auto`; absent means the project's default. The human agreed that the task's pull request may merge itself once its checks are green, as Belfry's merge rules can require. The planner may recommend it for small, low-risk work; `/peal:work` writes it only when the human agrees the plan, `/peal:idea` never, `/peal:revise` can remove it. When the review finds the diff larger or riskier than that plan, its report ends `merge-auto: withdraw` and `peal close finish` removes the field and says so in the pull request's body. The board carries it. |
| `touches` | a list of paths, directories or globs (`*`, `?`, `[...]` within a directory, `**` across) the task will likely change, relative to the repository's root; no entry absolute or holding a comma, and on issues none making a label over GitHub's 50 characters. The planner writes it when the human agrees the plan; `/peal:idea` only when the idea names the files plainly. The board carries it, so a scheduler like Belfry does not start two tasks on the same files side by side. A hint: a wrong one costs a missed parallel slot, nothing more. |

**A depends cycle is refused,** since every task on it would stay blocked for ever. Where
a task text is filed, revised or deferred, the depends graph is built as the read model
expands it (`milestone`, split origins), with the new text in place; a cycle through a
task the text adds or changes, which that task was not on before, exits 1 with
`refused: depends cycle 0042 → 0043 → 0042` (`#42 → #43 → #42` for issues; a task still
to be filed shows as `NNNN` or `PART1`). A task depending on its own milestone is no
cycle: the expansion leaves the task itself out. A cycle made by hand is shown instead:
`list` and `board` show its tasks as blocked with the cycle, `peal check` names it.

**A project may add its own fields,** declared in `.peal/config.yml` under
`task.fields` (name, and optionally the allowed values). Peal carries them through every
command unchanged and refuses undeclared keys when filing, so a typo fails at once
instead of being ignored forever.

Peal reads and writes a small subset of YAML: scalars, and lists of scalars in flow
(`[a, b]`) or block style. That keeps the scripts dependency-free (bash and git on a bare
machine, as in the reference) while every file stays valid YAML for any other tool.

The section structure (`Intent`, `Scope`, `Done when`, `Raw`, `Notes`, `Outcome`) is a
convention Peal's commands rely on: `Raw` is the human's words and never rewritten,
`Outcome` is written at close and must not be empty or a placeholder. A task with
`plan: required` gets a `Plan` section after `Notes` once the human agrees the planner's
plan; until it holds something, the plan is not agreed.

### Claim states

Derived from refs and the main branch on the remote, never from the calling worktree:

| State | Means |
|---|---|
| `free` | no branch; claimable |
| `claimed-live` | the branch has a worktree, or exists only on the remote |
| `parked` | a local branch ahead of main without a worktree; `claim` resumes it |
| `awaiting-merge` | the branch tip holds the task under `done/`; waits for the human's merge |
| `blocked` | a `depends` entry is not done yet, or the task lies on a depends cycle |
| `done` | the file is under `done/` on main; outranks every other state |

## Claims and the session hooks

- **`peal offer POOL [--top N]`** prints `CANDIDATE <id> <bucket> <title>` for the best N
  (3) free tasks and `MORE <bucket> <count>` for each bucket with some left over. The pool
  is a comma list of milestone ids, `current` and `unassigned`; each is a bucket (`current`
  becomes the current milestone's id), in the pool's order; a human task (`owner: human`)
  is never offered. Within a bucket by priority
  (urgent, high, normal, low; priority never lifts a task into an earlier bucket), then
  the free members of an open split, then by number; their titles say `(part of
  <origin>, <done>/<total> done)`. A parked, done or unknown milestone in the pool is
  refused.
- **`peal claim ID [--print-path]`** fetches, then refuses a task that is done, awaiting
  merge, blocked, claimed elsewhere, or of a parked, done or unknown milestone. It branches
  from the remote's main into `{worktrees}/NNNN-slug`, moves the file to `doing/` in one
  commit (`docs(tasks): claim NNNN slug [NNNN]`) and pushes the branch: a push that loses
  to another claim takes everything back. A task claimed on this machine prints its
  worktree again; a parked claim gets its worktree back and is pushed. `--print-path`
  makes the worktree's path the last line. `--next [POOL]` claims the offer's best
  candidate for POOL (`current,unassigned`), the next one when a claim loses its race.
  A human task is claimed by its id like any other; `/peal:work` refuses it.
  Scope paths (backticked in `## Scope`) that another claim's branch changes already are
  warned about, never refused.
- **`peal release ID`** removes a claim's worktree and branch (the remote's too, if it
  holds nothing more), the tip kept as `refs/reaped/NNNN-slug` for 30 days. It stays,
  with the reason, while it is the calling worktree, a session touched it in the last 30
  minutes, the task is not done on main, the worktree holds uncommitted changes, or the
  branch holds commits not pushed. Landed means done on main, so a squash merge counts.
  A claim `peal defer` gave back goes although its task is not done, and although a
  session touched it lately.
- **SessionStart**: on a new session (`startup`, `clear`) the turn budget restarts, the
  remote is fetched and every claim under the worktrees directory that `release` would
  let go is reaped (a deferred one only once idle); a landed one kept for uncommitted or unpushed work says so. Then the
  orientation: the current milestone, this worktree's task, the other claims, the open
  splits.
- **PostToolUse**: the heartbeat that keeps a worktree from being reaped, and the turn
  budget: the main session's tool calls in a task's worktree are counted, and at the
  task's size tier (M while unsized) the session is nudged once to close or split.
- **SessionEnd**: when the main session ends (`logout`, `prompt_input_exit`, `other`) in a
  task's worktree, uncommitted work is committed as `wip: session-end autosave [NNNN]` and
  the branch pushed.

The heartbeat, the turn count and the autosave's log live in the worktree's git
directory, where no commit sees them.

## Closing a task

`/peal:close` runs in the task's worktree once its `## Done when` holds, or once the task
is decided against. `peal close` holds every step a script can check; the command holds
the judgement (the review, routing the findings, the Outcome, the summary).

- **`peal close begin`** declares the close: a sentinel in the worktree's git directory
  arms the Stop hook. It refuses outside a task's worktree, without the git hooks
  installed, with more than one task under `doing/`, and on a branch that adds a backlog
  file. It notes, never refusing: how far the branch is behind main (task files not
  counted), the paths a merge of main would conflict in, milestone files the branch
  changes, the ideas queued, an empty `## Scope` or `## Done when`. Then it names the file
  the Outcome goes in (the task file; for an issue, a file of the close's own in the git
  directory, since an issue has no Outcome section), the project's PR sections, the diff
  and the `## Done when`.
- **The review** runs unless every path of the diff lies under `review.skip-paths`. Each
  finding is fixed on the branch, filed as an idea, escalated under `### Escalations` in
  the Outcome, or rebutted under `### Reviewer findings not acted on`. For a task holding
  `merge: auto` the report ends in one line, `merge-auto: keep` or `merge-auto: withdraw`:
  whether the diff is still the small, low-risk work the plan promised.
- **`peal close finish --summary TEXT [--section TITLE TEXT]... [--review-file FILE]`**
  refuses, before anything changes, a missing summary or PR section, an empty Outcome or
  one with a placeholder left, more than three escalations (the task was underspecified:
  the human decides first), a task holding `merge: auto` without the reviewer's report
  and its `merge-auto` line (FILE), an uncommitted path besides the Outcome's text, the
  git hooks missing, and a failing `checks.close` command. Then it files the queued ideas
  in one push (a storage that files one at a time, like issues, takes off the queue
  exactly those filed, so a rerun never files one twice), on `merge-auto: withdraw`
  removes `merge: auto` from the task through the storage's `record` (a commit on the
  branch, or the issue's label), commits the storage's finish as `docs(tasks): close
  ID [ID]` (the file's move to `done/`; an empty commit when the branch holds nothing
  else, since a pull request needs one), pushes, and opens the pull request, or updates
  the title and body of the one open for the branch. Whatever fails after the flush keeps
  the close in progress; finish run again goes on where it stopped.
- **The pull request's body** is generated (`peal close body` prints it): the count of
  escalations and a withdrawn `merge: auto` first, then the summary bullets; `Fixes #N` for an issue, which closes it on merge; the split it is part of; the
  project's `pr.sections`, each an item `"Title: what to write"` whose text the session
  passes to finish; the Outcome; the ideas filed from the worktree; the branch's commits.
- **`peal close abort REASON`** calls a close off, the reason logged in the git directory;
  the queued ideas stay queued.
- **`peal close verify`** prints one verdict about the branch checked out: `READY` (open
  and green; `:merged`, `:pr-closed`, `:no-checks` for a repository without Actions
  workflows), `WAIT:<why>` (checks pending or not registered yet, mergeability unknown),
  or `BLOCKED:<why>` (the close unfinished, uncommitted or unpushed work, no pull request,
  conflicts, failing checks, no `gh`, ...). Anything it cannot verify is `BLOCKED`, never
  `READY`. **`peal close wait`** runs it again until the verdict is not `WAIT` or its
  budget (nine minutes, under a tool call's ten) is spent; the command runs wait again
  while it says `WAIT`.
- **The Stop hook** is silent unless a close is in progress in the worktree; then it
  refuses to let a turn end while the Outcome is empty or holds a placeholder, or work is
  uncommitted or unpushed. It never refuses twice in a row, and a sentinel another session
  left behind is cleared, not enforced.
- **`peal check`** refuses a task file under `done/` whose Outcome is empty or holds a
  placeholder, and names each depends cycle among the tasks not done (the work tree's
  task files; for issues, the storage's).

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

A parked milestone may say why in `reason`, free text: `reason: 'until #12, other/repo#43'`
names the issues it waits for, a form Belfry reads to suggest un-parking once they are
closed. On GitHub the reason is the rest of the description's first line after "Parked:".
The board's milestone line carries it as `reason`.

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

Every milestone has a review task, `depends: [milestone]`, whose session runs
`/peal:milestone-review`. The same command runs without a task, as a Belfry action with
the `milestone` trigger, given the milestone's id. `peal milestone-review [ID]` prints what
a script can know: the milestone's tasks not done (its review task aside), the milestone
that becomes current next, the parked milestones and their reasons, the milestone's
text, and the project's steps from `.peal/review.md`, then `READY` or `OPEN <count>`. The
command walks the acceptance criteria (each met, with its evidence, or carried forward
as an idea), runs the project's steps, files the loose ends through `/peal:idea`, and
triages the backlog (tasks without a milestone, parked milestones whose reason has gone,
open tasks moved on). It ends with one `AskUserQuestion`, "Close <milestone>?", with its
summary, and on yes runs `peal milestone-state ID done --review FILE`.

`peal milestone-state ID done|parked|open [--reason R] [--review FILE]` is the one way a
milestone's state changes, for the review, for Belfry's lane actions, and for a human in
a shell. For task files it rewrites the milestone's file straight onto the main branch
(`docs(tasks): milestone ID STATE`, which the pre-push gate lets through when it only
modifies milestone files). When no milestone is current afterwards, it also makes the
first open milestone by order current, in the same commit. For issues it closes or
opens the GitHub milestone and writes or removes the "Parked" line of its description;
which milestone is current follows from the due dates. The review goes under `## Review,
<date>` in the file or the description. A milestone in that state already is left as it
is. Milestone files are read-only during an ordinary task; `/peal:close` warns when a
branch touches one.

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
  sections: []                  # extra prose sections close asks the session for: "Title: instruction"
commit:
  areas: []                     # allowed <area> values in commit subjects; empty allows any
models: {planner: opus, reviewer: opus, implementer: sonnet}
task:
  fields: {}                    # the project's own frontmatter fields
storage:
  kind: files                   # where tasks live: files (task files) or issues (GitHub issues)
  issues:
    repo: ""                    # owner/name; empty: the remote's GitHub repository
    label: ""                   # only issues with this label are tasks; empty: the issues
                                # opened by someone with write access
release:
  tag-prefix: v                 # release tags are <prefix>MAJOR.MINOR.PATCH
  wait-ci: false                # /peal:release waits for the workflow runs of the tag
  report: []                    # texts whose lines in those runs' logs the release reports
decisions: false                # the decisions module, or its directory to turn it on
stages: []                      # the setup stages peal init has done
```

Conventions with no setting: the `backlog`/`doing`/`done` directories, `NNNN-slug.md`
names, one task per branch and PR, the task sections, the commit subject grammar
`<type>(<area>): <what> [NNNN]`, which pushes may reach main directly, and the close
sequence. A setting exists only where two real projects would differ.

## Git gates

`peal hooks install` (the `guardrails` stage of `peal init`) writes one small hook under every git hook
name into the repository's git directory (`<git-common-dir>/peal/hooks`) and points
`core.hooksPath` there. Living outside every branch, no branch can weaken them. Each finds
the installed Peal the way the launcher does, runs Peal's gate for `pre-push` and
`commit-msg` (`peal githook NAME`), then the project's own hook of the same name: in the
hooks path the install replaced (kept as git config `peal.projectHooks`), else the git
directory's `hooks/`. A gate that cannot find Peal refuses rather than waves through.

- **pre-push** lets onto the main branch merges whose other parents a pushed branch
  already holds, and the storage's own writes, told by subject and checked by the diff's
  shape: `docs(tasks): file ...` only adds backlog task files; `docs(tasks): revise`,
  `defer`, `set milestone of`, `note on` modify exactly one, the subject's `[NNNN]`;
  `docs(tasks): retire` moves that one to `done/` under its name; with the decisions
  module on, `docs(decisions): regenerate the index` changes the index alone. Nothing
  else, no rewrite of main, no deletion. A pull request merged on the server runs no client hook.
- **commit-msg** checks the subject `<type>(<area>): <what> [NNNN]`, types `feat fix test
  refactor docs chore wip`; the area is one of `commit.areas` (then required), `tasks`,
  or `decisions` with the decisions module on. `wip: <what>` skips the checks and needs
  no id; a `(tasks)` commit must touch only the tasks directory and skips them too, as a
  `(decisions)` commit the decisions directory. `chore(peal): <what>`, a project's setup
  (`/peal:setup`), needs no id and skips them, touching only what `peal init` writes:
  `.peal/`, `.claude/settings.json`, `.belfry.yml`, the tasks and milestones directories.
  Otherwise each `checks.commit` item runs when the
  commit touches its paths: `"src/ *.cs: dotnet test"` runs on a change under `src/` or to
  a `.cs` file, an item without paths always. Git's own subjects (merge, revert, fixup)
  pass the grammar; a merge still pays the checks.
- **`peal commit SUBJECT [--body TEXT | --body-file FILE] [PATH...]`** stages, commits and
  reports in one call; refused on the main branch, without the hooks installed, and for a
  new backlog file (those are filed onto main).
- **The git guard**, a PreToolUse hook on Bash, refuses in a Peal repository a commit on
  the main branch, a gate bypass (`--no-verify`, `commit -n`, `core.hooksPath` changed or
  set inline, `GIT_CONFIG_*` around a git call) and a push to main. It parses the git
  invocations a command runs, `bash -c`, `eval` and substitutions included, so a message
  or heredoc that mentions them passes. It is a signpost; the hooks are the gates.

## Storage

Two things are kept apart: *where tasks live*, and *how a session works a task*. The
workflow (plan, implement, close, the PR conventions, milestone review) is Peal's value
and serves a project whose tasks are GitHub issues as well as one with task files. So
the commands talk to a small storage interface with two implementations, selected by
the `storage.kind` setting: `files` (the default) and `issues`. Belfry already *reads*
tasks from either place; Peal does not duplicate that, and an issues project's claims
are Belfry's, so either recognises the other's.

The interface:

| Operation | Task files | Issues |
|---|---|---|
| `list` → id, state, fields | the read model over refs and main | the open issues and the 100 closed most recently, their labels, milestones and the open PRs that fix them, and the refs |
| `read id` → fields, body | the file on main or its branch | the issue as a task text: frontmatter from its milestone, labels and reference lines, `# N — Title`, the body |
| `create fields body [part-of]` → id | a new backlog file pushed to main, numbered by push-as-lock | a new issue; the frontmatter becomes its milestone, labels and "Part of #N" / "Depends on #N" lines; a text naming a number not known yet is edited once it is |
| `edit id fields body reason` | the backlog file rewritten on main, reason in `## Notes` | title, body, milestone and managed labels rewritten, reason as a comment; refused when the issue changed meanwhile |
| `set-milestone id m` | the frontmatter field | the issue's milestone |
| `claim id` → worktree | the branch pushed, worktree added, file moved to `doing/` | label `in progress`, worktree `{worktrees}/issue-N` on branch `issue/N` (continuing the remote's `issue/N` if there is one) |
| `release id` | the branch and worktree removed, the tip kept | the same, and the label taken off an open issue |
| `finish id done` | file moved to `done/` with its Outcome, in the PR | says what closes it: the PR's body says `Fixes #N` |
| `finish id retired reason` | file moved to `done/` with the reason, on main | closed as not planned, the reason a comment |
| `comment id text` | appended under `## Notes` | a comment |
| `record id text` | the claimed task's file rewritten on its branch, committed | title, body and managed labels rewritten |
| `defer id reason text` | the claim's text, the reason in `## Notes`, onto the backlog file on main; refused for any commit beyond the claim but those of its own file | title, body, milestone and managed labels rewritten, reason as a comment; refused for any commit on `issue/N` |
| `milestones` | the milestone files | the repository's milestones |
| `milestone-text id` | the milestone's file on main | the milestone's description |
| `milestone-state id state reason review` | the milestone's file (and the next current one's) rewritten on main | the milestone closed or opened, its "Parked" line and review in the description |

**Ids.** A task file's id is four digits (`0042`), an issue's its number (`42`). The
commands and the read model take either; the commit subject's `[NNNN]` is the id, so
`[42]` in an issues project.

**An issue as a task.** Belfry's conventions where it has one, so a board reads the same
in both:

| Task field | On the issue |
|---|---|
| title | the issue's title; the slug is its first five words |
| `milestone` | the issue's milestone, by title |
| `depends` | lines `Depends on #3, #7` (with `human` and `milestone` too), read up to the first word that is none of those |
| `part-of` | a line `Part of #3` |
| `needs` | labels `needs: <capability>` |
| `size`, `plan`, `model`, `breaking`, `release-note`, the project's own fields | labels `<field>: <value>` |
| `priority` | labels `priority: urgent`, `priority: high`, `priority: low`, Belfry's; of two the higher counts, none is normal |
| `owner` | the label `owner: human`, Belfry's; none is ai |
| `merge` | the label `merge: auto`, the one Belfry reads; none is the project's default |
| `touches` | labels `touches: <path>`, one per entry, Belfry's |

Labels rather than a frontmatter block in the body: they show and filter on GitHub, and
Belfry reads `needs:` labels already. The sections (Intent, Scope, Raw, ...) are the
body's own headings, as in a file. A filter label (`storage.issues.label`, like Belfry's
`tasks.github-issues.label`) limits which issues are tasks; without one, only issues
opened by someone with write access are (anyone may open one on a public repository),
and only pull requests from the repository itself or by such a person mark an issue
awaiting merge.

**States of an issue:** `done` when closed; `awaiting-merge` while such an open PR says
`Fixes #N` (closes, resolves, ...); `claimed-live` when `issue/N` has a worktree here or
the issue carries the label; `parked` for a local `issue/N` ahead of main without a
worktree; then `blocked` and `free` by the same rules as for files.

**Claims.** Belfry's `github-issues` backend claims before the session starts: the worker
makes `<clone>-wt/issue-N` on `issue/N`, the server adds the label. `peal claim` makes
exactly that, so Belfry's worker reuses Peal's worktree and its board shows the claim, and
`peal claim N` on a task Belfry claimed prints the worktree Belfry made. A worktree alone
is a claim already: Belfry labels only when the session starts. The label is no lock (two
claims at the same moment can both add it); for a project run by one Belfry, or by hand,
that is enough. The session hooks find the task from the branch, and read its size from a
copy of its text the claim keeps in the worktree's git directory, so a tool call costs no
request to GitHub.

**What stays open.** GitHub's own sub-issues are not read as `part-of`, and `read` gives
the body without the comments; the commands that need either (#8 to #10) read them with
`gh` directly or extend the interface.

In the scripts the interface is a set of shell functions (`peal_store_list`,
`peal_store_create`, ...) in one file per implementation (`lib/store-files.sh`,
`lib/store-issues.sh`), selected by `storage.kind`. The commands and the `peal` CLI call
only these functions. Everything above them (offer ordering, dependency and split
expansion, milestone rules, close) is storage-independent. The issues storage needs `gh`,
logged in; its harness runs against a fake `gh` over recorded API shapes.

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

An entry is `<dir>/NNNN-slug.md`, in the reference's shape, so its entries move over
unchanged:

```markdown
# 0042 — Title
Date: 2026-09-24
Status: accepted

**Decision.** What was decided.
**Why.** Why, and what was weighed.
**Rules out.** What it excludes, so it is not argued again.
```

`Status` is `accepted` or `superseded by NNNN`, anything after the number free (the
reference narrows a partial supersession there). An entry that supersedes another has a
paragraph starting `**Supersedes** decision NNNN` (or `decisions NNNN and MMMM`, a link
`[NNNN](...)`, `**Supersedes (in part).**`). Once merged, an entry's one edit is its
`Status` line, made in the pull request of its successor.

- **`peal decision reserve SLUG`** takes the next number past every entry on the
  remote's main, every `refs/decisions/*` on the remote and every entry in the work tree,
  and pushes a marker commit (`reserve decision NNNN: slug (branch B, date)`, on the
  empty tree) to `refs/decisions/NNNN`. The ref is the number alone, so two branches
  after the same number contend for the same ref; the loser's push is not a fast-forward
  and fails, and it retries with the next number. A push failing for another reason is
  not retried. It then scaffolds the entry in the work tree, placeholders to fill in;
  nothing is committed. Refused on the main branch and on a detached HEAD.
- **`peal decision check`**, and `peal check` with the module on, refuse: an entry that
  is not well-formed (its name, its heading with its own number, its `Status`, a
  successor that exists, no placeholder left, a number used once); and, for what the
  branch changes since it left main (commits, the work tree and new files alike): a
  change to the index, a deleted entry, a `Status` turned `superseded by NNNN` without
  NNNN being an entry the branch adds whose `**Supersedes**` names it, an added entry
  whose `**Supersedes**` names an entry whose `Status` does not say so, and an added
  entry whose number the branch holds no reservation of (the marker names another
  branch, or there is none). The branch is `GITHUB_HEAD_REF` in a pull request's
  workflow, whose checkout is a merge commit, else the one checked out. Checking only
  what the branch changes keeps the pairing check off merged entries, whose text is
  frozen however it was worded then.
- **The guard**, a PostToolUse hook on Edit and Write, runs the check when an entry or
  the index is written, and shows the session what it finds. A reservation it cannot
  verify (the remote out of reach) is only a warning; the check in CI is the gate.
- **The index**, `<dir>/index.md`: the accepted entries by number, then the superseded
  ones with their successors. `peal decision index` prints it. `peal decision publish`
  regenerates it from the remote's main and pushes it there as `docs(decisions):
  regenerate the index`, built on a temporary index like the storage's own writes (so it
  touches no worktree and runs anywhere) and let through by the pre-push gate when it
  changes the index alone. `templates/decisions.yml` is the workflow a project copies to
  run it after every merge that changes the directory.
- **`peal decision brief --task FILE | --diff [BASE]`** prints the entries whose text
  names a path of the task (its `## Scope`, or `## Intent` and `## Notes` while the
  Scope is empty) or of the diff since the branch left main: a path being a word of two
  or more `/`-separated parts or a file name with an extension, matched as written, by
  its last part, and by each of its directories three or more parts deep. Superseded
  entries are counted, not shown. `peal brief planner` includes the task's, `peal brief
  reviewer` the diff's.
- **The close.** `peal close finish` lets uncommitted entries through its clean-tree
  check, refuses on anything the check finds, and commits the entries as
  `docs(decisions): record NNNN [ID]` of their own, right before the task's move to done.
  The commit gate allows the area `decisions` with the module on, for a commit that
  touches the decisions directory only, and skips the project's checks for it as for
  `tasks`.

## Releases

`/peal:release [version]` makes a release from what Peal knows better than commit
messages do: the tasks finished since the last release, with their Outcomes. It works in
either storage, claims nothing, and asks the human one question. `peal release` is the
claims' command, so the release's steps are `peal ship ...`, each rerunnable on its own:

- **`peal ship propose`** reads the last release: the highest tag
  `<release.tag-prefix>MAJOR.MINOR.PATCH` reachable from the remote's main branch (a
  pre-release, `v1.1.0-rc.1`, is never the last release). It prints `LAST <tag>`, an
  `ITEM kind id prs title` line per item since, and `PROPOSE <tag> <bump>`: `major`
  when an item is breaking, `minor` when one is a feature, `patch` when all are fixes,
  `first` (`v0.1.0`, with every done task) without an earlier release; or `NOTHING
  since <tag>`.
- **What went in** is read from the main branch's commits since the last release,
  squash merges as the close's pull requests make them (`Title [ID] (#PR)`). For task
  files: each file the range adds under `done/`, but those retired (`docs(tasks):
  retire`); the pull request from the commit adding it. For issues: each issue a
  subject names (`[42]`) that is closed as completed, and all its pull requests in the
  range. For both, each `feat` or `fix` commit of no such task (nor of an issue closed
  as not planned) is an item of its own, its subject the line.
- **Kinds.** Breaking: `breaking: true`, a label `breaking` or `breaking: true`, or a
  subject `type!:`. A fix: a commit subject starting `fix`, or an issue labelled `bug`.
  A feature otherwise. `release-note: none` (field or label) leaves the task out of the
  notes and of the version's bump.
- **`peal ship notes VERSION`** prints the notes: a first line (`v0.2.0: 2 features, 1
  fix since v0.1.0.`, the tag's message), then the sections Breaking, Features and
  Fixes, one line per item: its title and the first sentence of its Outcome (for an
  issue, of the Outcome its first pull request's body holds), then the task (a link to
  its file at the tag on GitHub, or `#42`) and its pull requests. Once the tag exists,
  the notes are those of its range, whatever landed since.
- **`peal ship tag VERSION`** tags the remote's main branch, annotated, and pushes the
  tag. It refuses a tag that exists (here or on the remote; a release is never moved)
  and a version not above the last release; a push that fails takes the tag back.
- **`peal ship publish VERSION`** creates the GitHub release with the notes (`gh release
  create --notes-file`), or brings an existing one up to date (`gh release edit`); on a
  remote not on GitHub the tag is the release.
- **`peal ship wait VERSION`**, run when `release.wait-ci` is `true`, waits for the
  workflow runs the tag's push started, with a budget as `peal close wait` has, and
  prints a `RUN` line per run, a `REPORT` line per text of `release.report` (the first
  line of the runs' job logs holding it: an image digest, say), then `READY`,
  `FAILED:<run> <url>`, `NONE:<why>` (no run within five minutes of the tag), or
  `WAIT:<why>` when the budget is spent.

The command proposes, shows the notes, and asks "Release <version>?" in one
`AskUserQuestion` (under Belfry, its inbox), then tags, publishes and waits.

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

and sets itself up with `peal init` (below), which writes those lines itself.

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

## Setting up a project

`peal init --stage STAGE` writes one stage of a project's setup, deterministically;
`/peal:setup` is the conversation on top, which decides the options. A stage is safe to
run again (what is there already is kept and said so) and taken back by `peal init
--remove STAGE`, which leaves the tasks themselves alone. Nothing is committed: each
stage prints what it created, updated, kept or removed, for the caller to commit.
`stages:` in `.peal/config.yml` records the stages set up, in this order, so other
commands know what is there.

| Stage | Writes | `--remove` |
|---|---|---|
| `tasks` | `.peal/config.yml` (`stages:`, and Peal's defaults as comments), the launcher `.peal/peal`, and for task files the tasks directory's `backlog/`, `doing/`, `done/` (a `.gitkeep` in each empty one) and `TEMPLATE.md` (a project's own is kept); `--storage issues [--label L]` writes `storage.kind: issues` and the label instead (empty by default: the write-access rule), keeping a `repo` set by hand, and `--storage files` removes it. Last, the `.claude/settings.json` lines of [Distribution](#distribution): the file is created when absent, the keys inserted into it when present (`lib/settings-json.awk`, keeping the rest as written); when it does not parse, the lines to add are printed and the stage exits 1. | refused while another stage is set up. The template, the `.gitkeep`s, the directories left empty, `storage`, `stages`, the launcher, Peal's lines in the settings (the file and `.claude/` when nothing else is left); the config file when it holds nothing else. |
| `guardrails` | `peal hooks install`. The session hooks come from the plugin's `hooks.json`, so nothing is written to the settings. | `peal hooks uninstall`: `core.hooksPath` back to what it was. |
| `milestones` | for task files a first milestone, `m1.md` (`current`, `--title T`, "First milestone" by default), unless the milestones directory holds one; for issues nothing but the record (the repository's milestones are the milestones). | `m1.md` while it is as the stage wrote it. |
| `belfry` | `.belfry.yml`: the `commands` backend of [Peal and Belfry](#peal-and-belfry) (with `retire` and a parking reason) for task files, `github-issues` with the label, `start: /peal:work {task}` and `idea: /peal:idea {idea}` for issues; the actions Peal provides (`milestone-review`, `release`) as comments to uncomment. A `.belfry.yml` that is not Peal's is left alone, the contract printed, status 1. The file is to be checked with `belfry check` once Belfry has one; until then the stage says it skipped the check. | the file while it is as the stage writes it; otherwise status 1, for the human to remove it. |

`peal init --survey` writes nothing: it prints, a `key value` line each, what the
conversation decides from: the stages set up and the next one, the storage, the branch,
the GitHub repository with its open issues and milestones, the recent commits that close
an issue, the README, TODO lists and marks, the CI files, a tasks directory already
there, whose `.belfry.yml` is there, and the storage to recommend (the one set up; else
`issues` for a GitHub project that already works from issues, so nothing moves; else
`files`).

**`/peal:setup [STAGE]`** runs in the human's own session. Without a stage it sets up
`tasks` and nothing more: it reads the repository, recommends the storage in two
sentences and asks once, shows what the stage writes, and commits it as one `chore(peal)`
commit on a `peal/setup-<stage>` branch (never on the main branch), which it offers to
push as a pull request. Then it proposes one or two first tasks from what it read (a
TODO, a gap the README admits; for issues, it names fitting open issues instead of
filing), files those the human picks, and ends in five lines: what was set up, what the
human can do now (`/peal:idea`, `/peal:work`), and the next stage for later, not set up.
`/peal:setup STAGE` sets up that stage the same way. Its `milestones` stage asks the
first milestone's title and offers to file its review task (`depends: [milestone]`),
once the milestone is on the main branch; its `belfry` stage offers to turn the
milestone review action on.

Each stage but `tasks` needs `tasks` set up first. A `guardrails` stage recorded in the
committed config says the project wants the hooks; `core.hooksPath` is each clone's own,
so a fresh clone runs the stage again.

## Migrating an existing project

Adopting Peal is a migration, not a rewrite: tasks keep their numbers, history stays,
the project's own tooling keeps working through the extension points. For a project with
its own task-file process, such as the reference:

1. **Install** the plugin: `peal init --stage tasks` and `--stage guardrails`, keeping
   the existing `tasks/` layout and template.
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
6. **Point `.belfry.yml`** at the launcher (the `belfry` stage writes Peal's).

All of it lands as one task, one PR, in the project itself.

## Building Peal

Issue #2 filed one issue per buildable piece, with `Depends on #N` where order matters;
#22 came later, before #8 to #13, so that those are built against both storages:

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
| #13 | `/peal:setup` and the Belfry integration | #6, #7, #35 |
| #14 | migration from an existing task-file process | #4, #5, #13 |
| #15 | Peal runs on itself | #9, #10, #11, #13 |
| #22 | issues storage: Peal's workflow on GitHub issues | #5, #7 |
| #35 | `peal init`: the setup stages, written deterministically | #6, #7, #9 |

Until Peal can run on itself, Belfry runs this repository from those issues
(`.belfry.yml`); #15 switches it over.
