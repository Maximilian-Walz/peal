# Peal — design

Peal turns a repository's tasks into a process Claude Code sessions can follow: task
files with YAML frontmatter, and commands that claim, plan, implement, close, file,
split, defer, revise and retire them, grouped by milestones.

Peal generalises the task-file process of one real project, the *reference project*.
That process grew under daily use: every script and rule in it exists because a session
once went wrong without it. Peal keeps those lessons and drops what only that project
needs. Issue #2 settled the decisions below; the build is split into the issues listed at the end.
The lookup (every command, flag, setting and field) is in [the reference](reference/README.md);
this page keeps the reasons.

## Principles

- **Tasks and their state live in git.** A task is a file; who holds it is derived from
  refs (a task branch, its worktree, the file's directory on the main branch), never from
  a status field someone must remember to update. Any worktree, on any branch, gets the
  same answer. (A project whose tasks are GitHub issues keeps them there instead; see
  [Storage](#storage).)
- **The pushed branch is the lock.** A claim pushes the task's branch; a second claim of
  the same task fails on git's own rejection. Numbering new tasks works the same way: a
  push that loses the race retries with the next number. Where the main branch refuses
  direct pushes, the same commit goes through a pull request that merges itself, and the
  lower pull request number wins a number ([Writes onto main](#writes-onto-main)).
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
| tasks | list, offer, claim (printing the worktree), board, idea and create commands | the `commands` backend of its contract |
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
    create: .peal/peal create --owner {owner} --title {title} --origin {origin}
    board: .peal/peal board
    milestone: .peal/peal milestone-state {id} {state} --reason {reason}
    retire: .peal/peal retire {task} --reason {reason}
    revise: /peal:comment {task} {text}
actions:
  milestone-review:
    title: Milestone review
    prompt: /peal:milestone-review {milestone}
    triggers: [milestone]
```

Where the pieces meet, and why:

- The commands of the contract (`list`, `offer`, `board`, `create`, `claim`,
  `milestone-state`) print exactly the shapes Belfry reads
  ([CLI](reference/cli.md#peal-list)). `claim` is idempotent, so a re-run job continues
  where the last one stopped.
- The board's `after_deploy` list (pull requests a task waits on) is Belfry's contract
  too: Peal passes it through and never reads it.
- `/peal:work NNNN` notices it is already inside NNNN's worktree and skips its own claim.
  It reads no Belfry variable: the same check serves a human who opened a session in the
  worktree by hand. The reference used a Belfry environment variable here; Peal does
  without.
- `/peal:idea` is the one deliberate exception: off a task branch it reads
  `BELFRY_SESSION` to tell a Belfry session from an ordinary one, because running
  `peal idea` in the shell of a Belfry session hangs (its sandbox has neither `gh`'s login
  nor SSH keys). The command calls Belfry's `task_create` tool instead. `peal create` is
  what Belfry itself runs, outside the sandbox. On a task branch an idea queues offline
  as always.
- `/peal:close` waits for the pull request's checks in the foreground with a budget,
  re-running while the verdict is `WAIT`. That works headless and interactive alike.
- `peal milestone-state` is the change Belfry makes itself on GitHub for its
  `github-issues` backend. The review, an action Belfry offers when a milestone is closed,
  ends with one question, "Close <milestone>?", and makes that change on yes.

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

A subagent's frontmatter cannot read the project's config, so `/peal:work` passes each its
model and starts each with `peal brief ROLE`, which gives it the task, the context
documents and the project's own rules. The planner has no Bash; the brief gives it what it
would otherwise have to parse the config for.

`/peal:work` is a script's decisions plus a conversation: `peal work` decides every step a
script can (resume, claim, offer), and the session stops for the human to agree the plan,
asking through `AskUserQuestion` so the same step works interactive and headless. The
plan is recorded on the claim, where a restarted session finds it. The implementer builds
and its `QUESTION`s go to the human; the main session never writes the task's code.

The backlog commands call the storage only, through the `peal` CLI. `/peal:idea` composes
a task in one pass, never asking, so filing costs the human no attention. `/peal:defer`
gives a claim back that nothing was built on, keeping its number and what was learned.
`/peal:retire` and `/peal:revise` write straight into the storage, so the human confirms
first, and both refuse a claimed task: a claimed task's text is its session's. `/peal:comment`
only adds a dated line to a free task's Notes, so it asks nothing: it is the prompt Belfry's
triage runs, headless, to add to a task, and text from outside marks the task `origin:
outsider`. Each is in [Commands](reference/commands.md).

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
| SessionStart orientation | moves | current milestone, this worktree's task, other claims, open splits, `/peal:next`'s hint. A project adds its own lines with its own hook; Claude Code runs both. |
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

A task is a Markdown file with YAML frontmatter, its state the directory it is in
together with refs ([Tasks](reference/tasks.md)). There is no status field: a field
someone must remember to update goes stale, and a directory and a branch cannot.

Text from a task can come from a stranger, so a malformed id is refused where it enters,
a bad slug is skipped with a warning, and free text is passed only as data
(`plugin/lib/hostile.test.sh` holds every command to that).

Peal reads and writes a small subset of YAML: scalars, and lists of scalars in flow or
block style. That keeps the scripts dependency-free (bash and git on a bare machine, as
in the reference) while every file stays valid YAML for any other tool.

A project may add its own fields, declared under `task.fields`. Peal carries them through
every command and refuses undeclared keys when filing, so a typo fails at once instead of
being ignored for ever.

**A depends cycle is refused** where a task is filed, revised or deferred, since every
task on it would stay blocked for ever. One made by hand is shown, not refused, so it can
be found and fixed.

**`touches`** is carried on the board so that a scheduler like Belfry does not start two
tasks on the same files side by side. It is a hint: a wrong one costs a missed parallel
slot, nothing more, so nothing refuses on it.

**`after_deploy`** is carried on the board unchanged, for a scheduler that holds a task back
until its server contains the pull requests it lists. Peal does nothing else with it.

The section structure is a convention Peal's commands rely on: `Raw` is the human's words
and never rewritten, `Outcome` is written at close and must not be empty. The plan is
agreed only once the `Plan` section holds something.

### Claim states

A claim's state is derived from refs and the main branch on the remote, never from the
calling worktree: any worktree, on any branch, gets the same answer. `done` outranks every
other state. The states and their meaning are in
[Tasks](reference/tasks.md#claim-states).

## Claims and the session hooks

- **`peal offer`** orders by milestone bucket first, then priority, then split, then
  number. Priority never lifts a task into an earlier bucket: the current milestone is the
  human's decision, a priority is one task's. A human task is never offered, since only
  the human can deliver it.
- **`peal claim`** is the lock: it branches from the remote's main, moves the file to
  `doing/` in one commit and pushes the branch, and a push that loses to another claim
  takes everything back. A claimed task prints its worktree again, so a re-run continues.
  Scope paths another claim already changes are warned about, never refused: a hint of
  a clash costs less than a refused claim. A fresh clone gets its git gates here too, before
  anything else ([Git gates](#git-gates)).
- **`peal release`** removes a claim's worktree and branch, the tip kept as
  `refs/reaped/NNNN-slug` for 30 days, and stays whenever anything would be lost: it is the
  calling worktree, a session touched it lately, the task is not done on main, or the
  worktree holds uncommitted or unpushed work. Landed means done on main, so a squash
  merge counts. A claim `peal defer` gave back goes although its task is not done.
- **SessionStart** installs the git gates in a fresh clone whose config records
  `guardrails`, in the orientation itself (a hook's stderr never reaches the session), so
  a session that never claims is covered. On a new session it restarts the turn budget,
  fetches and reaps the claims `release` would let go of, then prints the orientation: the
  current milestone, this worktree's task, the other claims, the open splits and
  `/peal:next`'s hint. The hint reuses the same list: no second read, no fetch, no `gh`.
- **PostToolUse** is the heartbeat that keeps a worktree from being reaped, and the turn
  budget: at the task's size tier the session is nudged once to close or split.
- **SessionEnd** commits uncommitted work as a `wip:` autosave and pushes the branch, so
  a session that ends abruptly loses nothing. A sandbox's device mount is left out of it
  (`peal_status_porcelain`, `peal_untracked_devices`); seen from outside the sandbox the
  same path is an ordinary empty file, and the autosave commits it like any other
  untracked file (0087), the remedy being git's own `.gitignore` or `.git/info/exclude`,
  not Peal code.

The heartbeat, the turn count and the autosave's log live in the worktree's git
directory, where no commit sees them. The hooks are listed in
[CLI](reference/cli.md#peal-hook).

## Closing a task

`/peal:close` runs in the task's worktree once its `## Done when` holds, or once the task
is decided against. `peal close` holds every step a script can check; the command holds
the judgement (the review, routing the findings, the Outcome, the summary). The steps are
in [CLI](reference/cli.md#peal-close).

- **`begin`** declares the close with a sentinel that arms the Stop hook, so a session
  cannot end with the close half done. It refuses what cannot be closed and notes, never
  refusing, what the human will want to know.
- **The review** runs unless every path of the diff lies under `review.skip-paths`. Each
  finding is fixed, filed as an idea, escalated or rebutted: none is dropped silently.
  For a task holding `merge: auto` the report says whether the diff is still the small,
  low-risk work the plan promised.
- **`finish`** checks everything before it changes anything, so a refusal leaves the
  branch as it was. What fails after the ideas are filed keeps the close in progress, and
  running it again goes on where it stopped: the ideas filed are taken off the queue as
  they are, so a rerun never files one twice, and the `docs(tasks): close` commit is
  empty when nothing else changed, since a pull request needs one. More than three
  escalations refuse: the task was underspecified, and the human decides first.
- **The pull request's body** is generated, so every pull request says the same things in
  the same order, and the project's `pr.sections` are asked for, not remembered.
- **`verify` and `wait`** answer with one verdict, and anything they cannot verify is
  `BLOCKED`, never `READY`. The budget is nine minutes, under a tool call's ten.
- **The Stop hook** is silent unless a close is in progress. It never refuses twice in a
  row, and a sentinel another session left behind is cleared, not enforced.
- **`peal check`** is the gate for what only CI sees: a done task with no Outcome, a task
  id two files use, a depends cycle. This repository's CI runs the branch's own
  `peal check` from `tools/lint.sh`.

## Milestones

Milestones are data, the model Belfry shares (its issue #3): an id, a title, a state, an
order and an optional due date. Each is one Markdown file, its data as frontmatter and its
prose (goal, acceptance criteria, the review) as the body
([Tasks](reference/tasks.md#milestone-files)).

The state is written, not inferred: the reference took "the newest milestone doc" as
current, which cannot express a parked milestone or one planned ahead. More than one
`current` is refused.

The reference's pools map onto this: its current milestone is the `current` one,
"unassigned" is no milestone, "later" is a `parked` milestone, and its "process" pool,
claimed only by name, is an `open` milestone. Its "any" pool, never offered, becomes its
own `parked` milestone rather than folding into "later": it held more than the recurring
drift check (which becomes `/peal:drift`), and a migration keeps what else was on it.

Every milestone has a review task, `depends: [milestone]`, whose session runs
`/peal:milestone-review`. The same command runs without a task, as a Belfry action with
the `milestone` trigger. `peal milestone-review` prints what a script can know; the
command walks the acceptance criteria, files loose ends as ideas, triages the backlog and
ends with one question. `peal milestone-state` is the one way a state changes, for the
review, for Belfry's lane actions and for a human in a shell
([CLI](reference/cli.md#peal-milestone-state)). Milestone files are read-only during an
ordinary task: a milestone's state is not a task's to change.

## Configuration

A project keeps everything of Peal's in `.peal/`, and every setting has a default
([Configuration](reference/configuration.md)). A setting exists only where two real
projects would differ; everything else is a convention with no setting (the
`backlog`/`doing`/`done` directories, `NNNN-slug.md` names, one task per branch and pull
request, the commit subject grammar, which pushes may reach main directly, the close
sequence). A key Peal does not know is refused, so a typo fails at once.

The project's own rules for the planner, reviewer, drift check and milestone review are
files under `.peal/` that Peal appends, rather than settings: they are prose, and the
project knows better.

`worktree-setup` exists because a task worktree lacks the local files git does not carry
(`.env`, `*.local.yaml`). It is a command taken from the checkout's config, like
`checks.commit`, so it has the limits [Security](security.md) names.

## Writes onto main

The storage's writes (`create`, `revise`, `retire`, `defer`, `set-milestone`, `comment`,
`milestone-state`) and `peal decision publish` build their commit on a temporary index
from the fetched main (`lib/main-write.sh`), so they touch no worktree and run anywhere.
They reach main one of three ways, the setting `main-writes`: `push`, `pr` or `auto`
(the settings are in [Configuration](reference/configuration.md)).

`auto` is the default because Peal cannot know a repository's rules before it pushes, and
both kinds are common. An unprotected main keeps the one-step push; a protected one (a
public project's usual ruleset) keeps working without a setting or a human step beyond
allowing auto-merge. A push first, and a pull request once the remote itself refuses
main, is remembered in git config `peal.mainWrites` so the next write does not try again.
`push` is for a project that wants a refusal to stay an error; `pr` for one that wants
every write reviewed, or whose remote refuses in a way git does not report as a
rejection of main.

A write returns once auto-merge is on, since waiting would hold a session for minutes;
a caller that needs main to hold the change waits explicitly
(`PEAL_MAIN_WRITE_WAIT=merged`, [CLI](reference/cli.md#environment-variables-and-git-config)).
Until the merge a read of main does not find the write, so its "no task" says a Peal pull
request may still be open. A conflict that arises after the command returned is left to a
human.

**Races.** Two writes built on the same main both open. A filing's rivals are the open
pull requests against main from the repository itself, never a fork's. The filing counts
the task files on their branches when it picks its number, and looks again once its pull
request is open and before Peal merges it: the lower pull request number wins, and the
loser closes its pull request and files again with the next free number, in a pull
request saying "Replaces #N". A pull request GitHub reports unmergeable is closed the
same way and the write built again. Each is bounded (`PEAL_PUSH_ATTEMPTS`). A rival
numbered higher that merges first, or a clash after auto-merge took over, is left to CI,
where `peal check` refuses two task files with one id; the `push` route needs no `gh`
and leaves a clash there to CI too.

**In CI.** `templates/decisions.yml` publishes with a `PEAL_TOKEN` secret when the project
sets one, else the workflow's `GITHUB_TOKEN`. A pull request opened with `GITHUB_TOKEN`
starts no workflow, so on a main that requires checks it waits for a human; `PEAL_TOKEN`
lets its checks run and auto-merge take it.

## Git gates

`peal hooks install` (the `guardrails` stage of `peal init`) writes one small hook under
every git hook name into the repository's git directory and points `core.hooksPath` there.
Living outside every branch, no branch can weaken them. Each finds the installed Peal the
way the launcher does, runs Peal's gate for `pre-push` and `commit-msg`, then the project's
own hook of the same name, so Peal never displaces a hook a project already relies on. A
gate that cannot find Peal refuses rather than waves through. The hooks never run what the
repository ships: the stub reads no file of the work tree, calls no network, and verifies
every root before it runs it, `$PEAL_ROOT` included (an in-repository one is skipped with
a message; see [Distribution](#distribution)). Every refusal names its reason. The limits
that remain (`checks.commit`, in-tree project hooks, gate settings read from the work
tree) are in [docs/security.md](security.md).

`core.hooksPath` belongs to each clone, not to the repository: a committed `guardrails`
stage in `stages:` only says the project wants the hooks, so a fresh clone runs the
install itself, at the start of the work rather than at its first refusal
(`peal_hooks_ensure`, `plugin/lib/githooks.sh`), from `peal claim` and the `SessionStart`
hook, both covered whether or not the other runs first. A `core.hooksPath` already set to
something other than these stubs is a clone's own choice: `peal_hooks_ensure` only warns
and names `.peal/peal hooks install`, which chains to it, rather than installing over it
unasked. `peal close begin`, `peal close finish` and `peal commit` stay pure refusals: the
backstop for whatever `peal_hooks_ensure` could not fix, never the first word on it.

- **pre-push** lets onto the main branch only what the lifecycle commands write, told by
  subject and checked by the diff's shape. `docs(tasks): file ...` only adds backlog task
  files; `docs(tasks): revise`, `defer`, `set milestone of`, `note on` modify exactly one,
  the subject's `[NNNN]`; `docs(tasks): retire` moves that one to `done/` under its name;
  with the decisions module on, `docs(decisions): regenerate the index` changes the index
  alone; `docs(tasks): milestone` only modifies milestone files; `chore(release): <tag>`
  only modifies files of `release.version-files`, each byte for byte what setting its
  field to the tag's version makes of its parent's, and `release.changelog`: its
  parent's with one entry inserted after the title, headed `## <tag>`, the parent
  holding none of that tag and the entry no other `##` heading, or added as
  `# Changelog` and that entry (its shape, not its text: [Security](security.md)).
  Merges whose other parents a pushed
  branch already holds pass too. Nothing else, no rewrite of main, no deletion. A pull
  request merged on the server runs no client hook, and a write through a pull request
  pushes only its `peal/main-write-*` branch, which the gate leaves alone
  ([Writes onto main](#writes-onto-main)).
- **commit-msg** checks the subject grammar and the id, and runs the project's
  `checks.commit` ([CLI](reference/cli.md#peal-githook)). A `(tasks)` or `(decisions)`
  commit skips them because it touches only those directories; `wip:` skips them because
  an autosave must never be refused. The id is required on a task's branch only: on any
  other named branch (a hotfix, a pin, an ad-hoc job) a subject without `[NNNN]` passes
  and `checks.commit` still runs. `peal commit` still refuses the main branch, so such
  work goes on a branch of its own, then a pull request.
- **The git guard**, a PreToolUse hook on Bash, refuses in a Peal repository a commit on
  the main branch, a gate bypass (`--no-verify`, `commit -n`, `core.hooksPath` changed or
  set inline, `GIT_CONFIG_*` around a git call) and a push to main. It parses the git
  invocations a command runs, `bash -c`, `eval` and substitutions included, so a message
  or heredoc that mentions them passes. It is a signpost; the hooks are the gates.

## Storage

Two things are kept apart: *where tasks live*, and *how a session works a task*. The
workflow (plan, implement, close, the PR conventions, milestone review) is Peal's value
and serves a project whose tasks are GitHub issues as well as one with task files. So the
commands talk to a small storage interface with two implementations, selected by the
`storage.kind` setting: `files` (the default) and `issues`. Belfry already *reads* tasks
from either place; Peal does not duplicate that, and an issues project's claims are
Belfry's, so either recognises the other's.

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

Ids, the mapping of an issue's labels and lines to frontmatter, the states of an issue,
who is admitted and the claims on issues are in [Storage](reference/storage.md).

Why labels rather than a frontmatter block in the body: they show and filter on GitHub,
and Belfry reads `needs:` labels already. Why an admission rule: anyone may open an issue
on a public repository, so what reaches a session must have been vouched for by someone
with write access. `admitted()` (`plugin/lib/issues-lib.awk`) is that one rule, and every
read path applies it, not only the listing (`docs/security.md`, "Only admitted issues
reach a session"; `plugin/lib/hostile.test.sh` holds the issues storage's channels to it
too). Why the claim label is no lock: for a project run by one Belfry, or by hand, a
worktree is a claim already, and the label only shows it.

In the scripts the interface is a set of shell functions (`peal_store_list`,
`peal_store_create`, ...) in one file per implementation (`lib/store-files.sh`,
`lib/store-issues.sh`), selected by `storage.kind`. The commands and the `peal` CLI call
only these functions. Everything above them (offer ordering, dependency and split
expansion, milestone rules, close) is storage-independent. The issues storage's harness
runs against a fake `gh` over recorded API shapes.

## Decision records

An **optional module**, off unless `decisions:` names a directory. Architectural
decisions as numbered, append-only files, with the tooling that keeps them honest:
numbers reserved by push-as-lock (`refs/decisions/NNNN`), a check that an added entry
holds a reservation, the supersedes pairing check, the generated index (never edited in a
PR, regenerated on main after a merge), and the brief of decisions naming the paths a
task or diff touches, which the planner and reviewer read instead of the whole index.
The commands are in [CLI](reference/cli.md#peal-decision).

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

`Status` is `accepted` or `superseded by NNNN`. Once merged, an entry's one edit is its
`Status` line, made in the pull request of its successor. The check looks only at what
the branch changes, which keeps the pairing check off merged entries, whose text is frozen
however it was worded then. The reservation is a ref named by the number alone, so two
branches after the same number contend for the same ref and the loser retries. The guard,
a PostToolUse hook, shows the session what the check finds; a reservation it cannot verify
is only a warning, since the check in CI is the gate.

## Releases

`/peal:release` makes a release from what Peal knows better than commit messages do: the
tasks finished since the last release, with their Outcomes. It works in either storage,
claims nothing, and asks the human one question. `peal release` is the claims' command,
so the release's steps are `peal ship ...`, each rerunnable on its own
([CLI](reference/cli.md#peal-ship)), because a release that fails halfway must go on
from where it stopped.

- What went in is read from the main branch's commits since the last release, squash
  merges as the close's pull requests make them, so a task's Outcome and pull request are
  found from its commit. A `feat` or `fix` commit of no task is an item of its own.
- The bump is proposed, not decided: `major` for a breaking item, `minor` for a feature,
  `patch` for fixes. `release-note: none` leaves a task out of both notes and bump.
- `peal ship bump` writes the project's version files and changelog entry onto main through the storage's own
  route, so a protected main works, and refuses anything it cannot set safely before it
  writes (`lib/version-field.awk`, which the pre-push gate runs too).
- `peal ship tag` never moves a release: a tag that exists is refused.
- `peal ship wait` exists for a project whose tag starts a workflow that publishes
  something (an image), and reports what those runs logged.

The command proposes, shows the notes, and asks "Release <version>?" in one
`AskUserQuestion` (under Belfry, its inbox), then sets the version files, tags,
publishes and waits.


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
  It tries `$PEAL_ROOT` (taken as it is: whoever sets it chose what runs), then the root
  the SessionStart hook records in the repository's git directory each session, then the
  newest Peal in Claude Code's plugin cache (any marketplace's `peal`), and fails with an
  install hint otherwise. A recorded or cached root runs only once verified: an absolute
  path with an executable `bin/peal`, a `.claude-plugin/plugin.json` naming `peal` with a
  version, outside every worktree of the repository and its git directory, inside
  `${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/cache/`, and, when Claude Code's
  `installed_plugins.json` is there, a path and version its `peal@` entries list. A root
  refused is named on stderr with the reason and the next is tried. The git hooks run the
  same check (one block, the same text in both templates), `$PEAL_ROOT` included. The
  SessionStart hook does not record a root inside the repository.

The `peal` CLI is the one entry point for all scripts (`peal list`, `peal claim`, ...);
commands and hooks call it too, so there is a single place that loads config and storage.

## Setting up a project

`peal init --stage STAGE` writes one stage of a project's setup, deterministically;
`/peal:setup` is the conversation on top, which decides the options. The split is the
process's own rule: what a script can do, a script does, so a stage is safe to run again,
taken back by `peal init --remove STAGE`, and never commits: the caller commits, so the
human reviews one commit. `stages:` in `.peal/config.yml` records the stages set up so
other commands know what is there. The stages (`tasks`, `guardrails`, `milestones`,
`belfry`) and what each writes and removes are in [CLI](reference/cli.md#peal-init).

`/peal:setup` without a stage sets up `tasks` and nothing more: a first run that asks
once and commits one change is one a human will try. Each stage but `tasks` needs it
first. A `guardrails` stage in the committed config says the project wants the hooks;
`core.hooksPath` is each clone's own, so a fresh clone runs the stage again itself
(`peal_hooks_ensure`, [Git gates](#git-gates)).

`/peal:next` finds the rest once `tasks` is set up. It reads local facts only (never
Belfry, never `gh`, never a fetch), so it is cheap enough for the SessionStart hint, and
it prints the one next thing with the best evidence for it, in a fixed order: the stages,
then a current milestone's missing review task, then the features within the stages. Why
a fixed order: a suggestion that changes between runs cannot be trusted. Why a decline
lasts 90 days: nagging is how a tool is uninstalled. Nothing changes unasked
([Commands](reference/commands.md#pealnext)).

### `peal doctor`

When Peal does not work in a project, nobody should have to guess why. `peal doctor` runs
its checks and reports one problem per finding: a sentence and one fix, worded
`.peal/peal ...` where the fix is a command. Every finding is a problem; there is no warn
level. It reads local refs only and never fetches, so a claim that landed on the remote
but was never fetched into this clone passes silently. The `belfry` check runs the
contract's read commands only, and only once their words are literally Peal's, never
through `bash -c`: a doctor that ran whatever `.belfry.yml` says would be a hole. The
checks and the output are in [CLI](reference/cli.md#peal-doctor).

## Migrating an existing project

Adopting Peal is a migration, not a rewrite: tasks keep their numbers, history stays, the
project's own tooling keeps working through the extension points. For a project with its
own task-file process, such as the reference: install the plugin, convert the task
headers and milestone docs (`peal migrate`, [CLI](reference/cli.md#peal-migrate)), move
project settings into the config, replace the generic scripts, commands, subagents and
hooks with Peal's, keeping every piece the
[scope tables](#scope-what-moves-what-stays) mark as staying, and point `.belfry.yml` at
the launcher. All of it lands as one task, one PR, in the project itself. See
[`docs/migrating.md`](migrating.md) for the walkthrough.


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

Belfry ran this repository from those issues until #15 switched it over: Peal runs on
itself. The issues still open became task files under `tasks/backlog/`, each keeping its
issue's number (`#38` is `0038`), and were closed with a pointer to their task; the
milestones are `docs/milestones/`; `.belfry.yml` is the `commands` backend through the
launcher, written by `peal init --stage belfry`. New work is filed with `/peal:idea`, not
as an issue.
