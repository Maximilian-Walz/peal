# The `peal` CLI

`peal --help` is the source; this page groups it and adds output shapes, exit statuses
and environment variables. Inside Claude Code `peal` is on the Bash tool's path; outside
it, in git hooks, Belfry's commands and a shell, use the launcher `.peal/peal`. Tasks
live in the storage `storage.kind` names ([Storage](storage.md)). The reasons are in
[the design](../design.md).

Exit statuses, unless a command says otherwise: 0 done, 1 refused or failed, 2 misuse or
malformed input (`refused: ...`), 3 still waiting.

## `peal --version`

Prints Peal's version.

## `peal init`

Sets a stage of the project up, safe to run again. Nothing is committed: it prints what
it created, updated, kept or removed. Each stage but `tasks` needs `tasks` first.

- `peal init --stage STAGE [--storage files|issues] [--label L] [--title T]`: `tasks`
  (config, launcher, tasks directories and template, or the issues storage with its
  label, and the plugin's lines in `.claude/settings.json`), `guardrails` (the git gates),
  `milestones` (a first milestone, `--title`), `belfry` (`.belfry.yml`). Recorded as
  `stages:` in the config, in that order.
- `peal init --remove STAGE`: takes the stage back and leaves the tasks alone. `tasks` is
  refused while another stage is set up. `belfry` removes the file only while it is as
  the stage wrote it, else status 1.
- `peal init --survey`: writes nothing; prints `key value` lines: the stages set up, the
  storage, the branch, the GitHub repository with open issues and
  milestones, commits closing issues, README, TODO lists, CI files, local-looking ignored
  files (`local-files`), a tasks directory, `.belfry.yml`, the storage to recommend.

## `peal next`

What to adopt next, from local facts only.

- `peal next [--all | ITEM]`: `SUGGEST item try evidence`, up to three `ALSO` lines, or
  `NONE`. `--all` adds `DECLINED item date` lines. An `ITEM` is offered regardless of the
  catalogue or a decline.
- `peal next --decline ITEM`: sets `declined.ITEM` to today in `.peal/config.yml`,
  blocking it for 90 days. Refused without the file.

## `peal migrate`

Converts a project's own process. Never commits. See [migrating](../migrating.md).

### `peal migrate headers`

`peal migrate headers [--parked P,...] [--open P,...] [--none P,...]` rewrites each
task's `key: value` header into frontmatter, in place. Lists become flow lists, trailing
comments are dropped, a numbered milestone becomes `mNN`, a pool in `--none` drops the
field, one in `--parked` or `--open` stays as that id. A file already in frontmatter is
left alone. What it cannot convert goes to stderr, that file untouched; status 1 if
anything was reported.

### `peal migrate milestones`

`peal migrate milestones [--parked P,...] [--open P,...]` adds frontmatter to each
numbered milestone doc (the highest number `current`, the rest `done`), and makes a file
for every `--parked` or `--open` pool without one. Status 2 rather than a second
`current`; status 1 for a doc with no number or a milestone id a task uses with no file.

## `peal check`

Reports what is not valid: the milestone files, a task under `done/` without an Outcome
(empty or a placeholder), a slug not kebab-case, a task id two or more files use
(`peal: task id NNNN is used by A and B`), a depends cycle among the tasks not done, and
with the decisions module on, `peal decision check`.

## `peal doctor`

`peal doctor [CHECK...]` runs the named checks, or all: `config`, `version`, `hooks`,
`gh`, `claims`, `belfry`. Local refs only, never a fetch.

- Output: `ok`, `FAIL` or `skip` lines, each naming its check; a `  fix: ...` line under
  each `FAIL`; last `doctor: N problem(s)`.
- Status 0 healthy, 1 any problem, 2 an unknown `CHECK`, outside a git repository, or no
  `.peal/`.
- `config`: `pr.security`, when set, names a file that exists;
  the config loads, and `storage.kind`, `main-writes`, `sizes.*`, `stages`,
  `release.wait-ci` and `models.*` hold valid values.
- `version`: `.peal/peal` matches the plugin's launcher template; then the installed
  Peal against this session's.
- `hooks`: only with `guardrails`. `core.hooksPath` unset or foreign, a stub missing,
  not executable or changed.
- `gh`: only for `issues`. `gh` missing or not logged in.
- `claims`: a claim `peal release` would let go of, one landed with uncommitted or
  unpushed work, a prunable worktree.
- `belfry`: only with `tasks.backend: commands`. Runs its `list`, `board` and `offer`
  commands, only when they are literally `.peal/peal list`, `board` or `offer ...`, and
  checks their output shape.

## `peal config`

`peal config [KEY]` prints the effective settings, or one of them. See
[Configuration](configuration.md).

## `peal frontmatter`

Reads and writes frontmatter, Peal's YAML subset (scalars, lists in flow or block style).

### `peal frontmatter check`

`peal frontmatter check FILE` refuses a frontmatter outside the subset.

### `peal frontmatter keys`

`peal frontmatter keys FILE` prints its keys.

### `peal frontmatter get`

`peal frontmatter get FILE KEY` prints a value, or a list's items one per line.

### `peal frontmatter set`

`peal frontmatter set FILE KEY VALUE`.

### `peal frontmatter set-list`

`peal frontmatter set-list FILE KEY [ITEM...]`.

### `peal frontmatter unset`

`peal frontmatter unset FILE KEY`.

## `peal milestones`

`peal milestones [--json]`: one line per milestone, `id state order due title`, or the
board's `{"milestone":{...}}` lines. From the milestone files or the storage's
milestones.

## `peal hook`

The Claude Code hooks; `hooks.json` runs them. Terse here; the reasons are in
[the design](../design.md#claims-and-the-session-hooks).

### `peal hook session-start`

Records where Peal is installed; installs the git gates when the config records
`guardrails` and they are missing (`peal_hooks_ensure`); on a new session (`startup`,
`clear`) restarts the turn budget, fetches, and reaps the claims `peal release` would let
go of, and the worktrees a release left in place once idle (`reaped leftover PATH`);
prints the orientation, with a `Launcher:` line (every source) when the committed
`.peal/peal` differs from the running Peal's `templates/launcher`, whether a branch
changed it or it is older than the plugin. Also appends `export GH_TELEMETRY="${GH_TELEMETRY:-0}"` once to
Claude Code's `CLAUDE_ENV_FILE` (when set), so the session's own `gh` calls run with
telemetry off; it never fails the hook.

### `peal hook post-tool-use`

The heartbeat that keeps a worktree from being reaped, and the turn budget: one nudge, at
the task's size tier (M while unsized), to close or split.

### `peal hook session-end`

Autosaves a task branch as `wip: session-end autosave [NNNN]`, pushed.

### `peal hook stop`

While a close is in progress, refuses to stop with the Outcome empty or work uncommitted
or unpushed. Never refuses twice in a row.

### `peal hook git-guard`

The PreToolUse hook on Bash: refuses a commit on the main branch, a gate bypass and a
push to main.

### `peal hook decisions`

The PostToolUse hook on Edit and Write: after a decision entry is written, the findings
of `peal decision check`.

## `peal hooks`

The git gates, one small hook under every git hook name in `<git-common-dir>/peal/hooks`.

### `peal hooks install`

Writes the hooks and points `core.hooksPath` there. Chains to the hooks that were in use
(kept as git config `peal.projectHooks`, else the git directory's `hooks/`). Refuses to
record a Peal inside the repository.

### `peal hooks uninstall`

Removes the hooks, puts `core.hooksPath` back, removes every `peal.*` git config key.

## `peal githook`

`peal githook NAME ARGS...` runs the gate of git hook `NAME`, `pre-push` or `commit-msg`.
Every refusal names its reason. The rules are in [the design](../design.md#git-gates).

- `commit-msg` checks the commit subject grammar: `<type>(<area>): <what> [NNNN]`.
  - Types: `feat fix test refactor docs chore wip`.
  - Areas: one of `commit.areas` (then required), `tasks`, or `decisions` with the module
    on.
  - `wip: <what>` needs no id and skips the checks.
  - A `(tasks)` commit must touch only the tasks directory, a `(decisions)` commit only
    the decisions directory; both skip the checks.
  - `chore(peal): <what>` needs no id, skips the checks and may touch only what
    `peal init` writes.
  - The id is required on a task's branch only (`task/NNNN-slug`, `issue/N`).
  - Otherwise each `checks.commit` item runs when the commit touches its paths.

## `peal commit`

`peal commit [-m] SUBJECT [--body TEXT | --body-file FILE] [PATH...]` stages, commits and
reports. `-m` is optional and only valid first. `--help` (`-h`) prints the usage and
commits nothing; any other leading option is refused with the usage. With PATHs,
resolved from the caller's directory, only those are committed (`git commit --`); the
rest of the index stays staged. Without, everything staged is
committed. Refused on the main branch, without the git hooks when `guardrails` is a set-up
stage (a `tasks`-only project commits ungated), and for a new backlog file.
A refusal after the staging (a new backlog file, the commit-msg gate) puts the index back
exactly as it was before the call: what was staged stays, what `peal commit` staged is
unstaged. If the restore itself fails, the original index is kept in a file the message names.

## `peal list`

`peal list [--fetch] [--no-pr] [--state S[,S...]] [ID...]` prints `ID state slug detail`
per task. `--fetch` fetches first; `--no-pr` does not ask `gh` for pull requests (an
issues storage cannot do without). States: [Tasks](tasks.md#claim-states).

The detail:

- free: its milestone (`-` for none), and in a split `split:<origin> <done>/<total>`;
- blocked: `needs:<id>,...`, then `cycle: 0042 → 0043 → 0042` on a depends cycle
  (`#42 → #43 → #42` for issues);
- claimed: `wt:<path>`, `remote:<remote>`, `N commit(s) ahead, last <date>`, or
  `pr:#N <url>` (`pr:unknown` without `gh`);
- a task not done with a priority not normal ends with `priority:<urgent|high|low>`, a
  human task not done with `owner:human`.

## `peal board`

`peal board [--fetch] [--no-pr]` prints one JSON object per task, then one
`{"milestone":{...}}` line per milestone: the shapes of Belfry's contract.

- Task keys: `id`, `state`, `slug`, `title`, `milestone`, `depends`, `part_of`, `size`,
  `plan`, `needs`, `priority`, `owner`, `origin`, `touches`, `after_deploy`, `merge`, `pr`, `path`,
  `ref`, `cycle`.
- Each but `id` and `state` only when set: no field for a normal priority, an AI's task,
  a task the project wrote itself or the project's default merge.
- `after_deploy` is a list as written in the task: an all-digit entry prints as a number, any other as a string.
- A milestone line carries a parked one's `reason`.

## `peal overview`

`peal overview [--fetch]` prints the open tasks grouped by milestone. Urgent tasks are
marked `!`, high `↑`.

## `peal read`

`peal read ID` prints a task's text, from its branch or the main branch.

## `peal create`

Files tasks; task texts on stdin, `NNNN` standing for the number to come, several texts
separated by lines `-----NEXT TASK-----`. Numbered by push-as-lock: a push that loses the
race retries with the next number. Prints `filed NNNN ...` lines, and where main is written
through a pull request `pull request #N <url>, merging once its checks pass; the number is
final once it merges`. A cycle through a task the text adds or changes exits 1 with
`refused: depends cycle 0042 → 0043 → 0042`.

- `peal create SLUG`: files a task.
- `peal create --part-of ID SLUG...`: files the pieces of a split of `ID`; `part-of:
  ORIGIN`, and `PART1..n` for each other.
- `peal create --batch ID SLUG...`: files ideas found in task `ID`.
- `peal create --owner OWNER --title TITLE [--origin outsider|writer]`: Belfry's
  `tasks.commands.create`. One task, its slug the first five words of `TITLE`. `OWNER`
  (`ai` or `human`) is written into `owner`, winning over the text's own; `outsider` is
  written into `origin`, `writer` or none writes no field; the issues storage has no label for `origin`, so
  `--origin outsider` is refused there, as is an outsider's text with a filled `## Plan`
  or `## Outcome` (`docs/security.md`). Ends with `filed: <id>`.

## `peal idea`

`peal idea SLUG [--now]` queues an idea on a task branch, for the close to file; anywhere
else, or with `--now`, files it at once. The text is on stdin.

## `peal idea-fields`

`peal idea-fields` (issues storage only; refused on task files) reads an idea's text on
stdin and prints the issue `peal create` would open from it: `title: T`, `milestone: M`
when there is one, a `label: L` line per label (`priority`, `needs`, `plan`, `size`, the
project's fields), then `body:` and the body (the `Part of`, `Depends on` and `After
deploy of` lines, then the text without frontmatter and heading). For a control plane
that opens the issue itself; a text that sets `merge` is refused, as `peal create
--owner` refuses it.

## `peal ideas`

`peal ideas [--flush | --export | --drop N|--all]` works the queue: `--flush` files the
ideas, `--export` prints them in full as Markdown, `--drop N` takes one off by position,
`--all` all of them.

## `peal revise`

`peal revise ID --reason R [--dry-run]` rewrites an unclaimed task's text (on stdin) in
place, the reason in `## Notes`. Refused when an issue changed meanwhile. In the worktree
of `ID`'s claim it rewrites the claim's text instead.

## `peal retire`

`peal retire ID --reason R` moves an unclaimed task to `done/` with `R` as its Outcome. An
issue is closed as not planned, `R` a comment.

## `peal set-milestone`

`peal set-milestone ID [M]` sets an unclaimed task's milestone, or removes it. A move
that puts the task on a depends cycle it was not on before (through `milestone` in a
`depends`) is refused with status 1, naming the cycle; nothing is changed.

## `peal comment`

`peal comment [--origin outsider|writer] ID TEXT` adds a dated line to an unclaimed task's
`## Notes`; an issue gets a comment, claimed or not. `--origin outsider` also sets the
task's `origin: outsider` (files storage). A TEXT with a line that is `---` or starts with
`## ` is refused (status 2). Belfry reaches it through `/peal:comment`, the
`tasks.commands.revise` prompt.

## `peal apply`

`peal apply` is Belfry's `tasks.commands.apply`: the changes a triage or planning run
ends with, once the human accepted them, read as one JSON document on stdin,
`{"proposals": [...]}`, and written as one commit (one pull request where main takes pull
requests only), subject `docs(tasks): apply N proposals`, each proposal's `why` in its
body. Task files only; the issues storage refuses (status 2), since Belfry writes a
`github-issues` project itself.

Each proposal is an object with an `id` (Belfry's, echoed back), a `kind`, an optional
`why`, an optional `origin` (`outsider` or `writer`; `""` is none) which only `file` and
`add` act on (a `vouch` carrying `origin: outsider` is refused), and the kind's fields. Belfry's own `ref`, `item` and `into` are ignored,
whatever scalar they hold (an object or array is still refused); every other unknown field makes the proposal invalid. Belfry leaves
empty fields out, so an absent optional field is none:

| kind | fields | what it does |
|---|---|---|
| `file` | `title`, `text`, `milestone`, `priority`, `owner`, `origin` | files `text` as `peal create` does (`NNNN` for its number); the four fields go into the frontmatter, winning over the text's; `title` gives the slug, its first five words; with `origin: outsider`, a text with a filled `## Plan` or `## Outcome` is refused |
| `add` | `task`, `text`, `origin` | a dated line under the task's `## Notes`, as `peal comment`; `origin: outsider` marks the task |
| `vouch` | `task`, `origin` | a human's word that an outsider's task counts as a writer's: drops `origin: outsider` and adds the dated line "Vouched for by a writer: <why>" ("Vouched for by a writer." with no `why`; line breaks in `why` become spaces) under `## Notes`, adding that section when the task has none. A task that is a writer's already is answered done ("already a writer's") and nothing is written. `task` cannot be `@<id>`, and `origin: outsider` is refused |
| `move` | `task`, `milestone` | sets the milestone; absent or `null` removes it (`""` is invalid) |
| `priority` | `task`, `priority` | `urgent`, `high`, `normal` (removes the field) or `low` |
| `depends` | `task`, `on`, `remove` | adds `on` to the task's `depends`, or takes it out with `"remove": true` (absent, `false` or `null` adds). On the task this worktree claims, with nothing built on it, it also gives the claim back as `peal defer` does (a "Deferred <date> after a claim: <why>" line, `waits for <on>`, or `no longer waits for <on>` with `remove`, when there is no `why`; the text is main's backlog copy, so the claim's local edits, a plan or notes, are not carried, unlike `peal defer`; its file here committed as wip afterwards), in the same commit; a claim elsewhere, and any other kind on a claim, are refused |
| `retire` | `task`, `reason` or `duplicate` | moves the task to `done/`, its Outcome "Retired <date> without being claimed: <reason>" or "...: duplicate of <id>" |
| `milestone_create` | `title`, `goal`, `due`, `order` | a new `open` milestone file, `peal init`'s text: `# <title>` (one line), `## Goal` (`goal`, prose with no `---` or `## ` line, else a placeholder), `## Acceptance criteria` (a placeholder); `due` a date, `YYYY-MM-DD`; `order` an integer, by default one past the highest. Its id is Peal's: `m` and one past the highest numeric id, zero-padded when all of them are |
| `milestone_update` | `milestone`, `title`, `due`, `order` | at least one of the three; `title` goes into the frontmatter's `title` when the file has one, else its `# ` heading; `due: null` and `order: null` remove the field |
| `milestone_state` | `milestone`, `state`, `reason` | `state` `park` (parked), `unpark` or `reopen` (open), `close` (done); `reason`, one line, with `park` only. A state the milestone has already changes nothing. Then, when no milestone is current, the first open one by order becomes current, as `peal milestone-state` does |
| `split_milestone` | `milestone`, `tasks`, `title`, `goal`, `due`, `order` | `milestone_create`'s milestone (`title`, `goal`, `due` as there; `order` by default `milestone`'s plus one, not renumbering the rest), and the tasks moved to it: `tasks` is an array of strings, each a task id or an `@<id>` of an earlier `file` proposal, none twice, each in any milestone or none. The answer carries `milestone` (the new id) and no `task`; the moved tasks are in `outcome` |

A `task`, `on` or `duplicate` written `@<id>` is the task the `file` proposal `<id>` of
the same batch files (for `task`, an earlier one). A `milestone` written `@<id>` (in
`file`, `move`, `milestone_update`, `milestone_state`, and a `split_milestone`'s `milestone`)
is the milestone an earlier `milestone_create` or `split_milestone` `<id>` makes. `fold`
and `dismiss` are Belfry's own, no backlog change; both are answered not done. A new milestone's id is
reserved nowhere: two batches making one in rival pull requests conflict, and the second
is made again.

Everything is checked against the main branch as the whole batch leaves it, as the
single commands check it: a task in the backlog and claimed by nobody; a milestone that
exists, is not done and is no parked one a task moves into (parked as the batch leaves it)
or out of (parked at the start and still so); a frontmatter `peal create` accepts (and no
`merge`); no depends cycle the batch closes; no retired task that one not done still
names (the batch may re-point those first); no milestone closed while a task not done,
its review task aside, names it; milestone files `peal milestones` reads.

The answer is one JSON line per proposal, in input order, as Belfry's `ApplyResult` reads
it: `id`, `done` (`true` or `false`), `outcome` (one line: what was done, or why not: the
proposal failed a check, another did so nothing was written, or the write failed),
and `task` (the task a proposal acted on; a `file`'s new one), `milestone` (the
milestone a milestone kind acted on, a new one's id) and `change` where they apply.
`change` is the pull request, when the write went through one; one still open at the
budget (`PEAL_MAIN_WRITE_BUDGET`, 90 s unless set) with auto-merge on answers `done`
too. Exit 0 all done, 2 an invalid batch with nothing changed, 1 a failed write. A
document that is no JSON is one line with `"done": false` and an empty `id`.

## `peal finish`

`peal finish ID` on the task's branch: moves its file from `doing/` to `done/`, staged.
For an issue, says what its pull request must say (`Fixes #N`).

## `peal offer`

`peal offer POOL [--top N]` prints `CANDIDATE <id> <bucket> <title>` for the best `N` (3)
free tasks, best first, and `MORE <bucket> <count>` for each bucket with some left.

- `POOL` is a comma list of milestone ids, `current` and `unassigned`. Each is a bucket,
  in the pool's order; `current` becomes the current milestone's id.
- Within a bucket: by priority (urgent, high, normal, low), then the free members of an
  open split (titled `(part of <origin>, <done>/<total> done)`), then by number.
  Priority never lifts a task into an earlier bucket.
- A human task is never offered. A parked, done or unknown milestone in the pool is
  refused.

## `peal claim`

`peal claim ID [--print-path]` claims a free task, or resumes its parked claim.

- Fetches, then refuses a task that is done, awaiting merge, blocked, claimed elsewhere,
  or of a parked, done or unknown milestone.
- Branches from the remote's main into `{worktrees}/NNNN-slug`, moves the file to
  `doing/` in one commit (`docs(tasks): claim NNNN slug [NNNN]`) and pushes the branch;
  a push that loses to another claim takes everything back.
- A task claimed on this machine prints its worktree again (idempotent). A parked claim
  gets its worktree back and is pushed.
- A free task whose deferred claim is still there ([Claim states](tasks.md#claim-states))
  has it taken over first: a local one released as `peal release` would, one only on the
  remote deleted there, its tip kept under `refs/reaped/` and the delete refused if the
  branch moved meanwhile; one `released ...` line, then the claim.
- The worktree's path may hold an empty directory (what git leaves of a worktree it
  could not delete), which the claim uses, or a worktree a release left in place, which
  the claim removes first as the reaping would (`removed the leftover PATH`). Anything
  else there is in the way; so is a leftover that is the calling worktree or that `git
  worktree remove` refuses, with the SessionStart reaping named as the way out.
- Installs the git gates first when the config records `guardrails` and they are missing:
  the install's line on stdout, before the path. A foreign `core.hooksPath` or a failed
  install only warns, on stderr.
- A new or resumed worktree runs `worktree-setup`, once, its output on stderr. A failure
  is status 2 and rolls nothing back.
- Scope paths (backticked in `## Scope`) that another claim's branch changes already are
  warned about, never refused.
- `--print-path` makes the worktree's path the last line.
- `peal claim --next [POOL] [--print-path]` claims the best candidate of `POOL`
  (`current,unassigned`), the next one when a claim loses its race.
- A human task is claimed by its id like any other.

## `peal release`

`peal release ID` releases a claim: removes its worktree and branch (the remote's too, if
it holds nothing more; a remote branch already gone, deleted on merge, only has its stale
tracking ref pruned, silently), the tip kept as `refs/reaped/NNNN-slug` for 30 days. A
locked git config does not fail it: one `warning:` line names the
`git config --remove-section` that finishes the job. It stays,
with the reason, while:

- it is the calling worktree, unless its claim was deferred;
- a session touched it in the last 30 minutes;
- the task is not done on the main branch (a squash merge counts as done);
- the worktree holds uncommitted changes, or the branch unpushed commits.

A claim `peal defer` gave back goes although its task is not done, and although touched
lately. From its own worktree it is released in place: the branches go, and the worktree
stays, detached at the tip and marked `peal-released`, for the SessionStart reaping to
remove once idle; the `released ...` line says so. From elsewhere, a clean worktree that
`git worktree remove` cannot delete is left in place the same way; one git dropped after
emptying it (its directory busy or not writable) leaves that directory, named in the line;
the next claim of the task uses it.
Not to be mistaken for a release of a version, which is [`peal ship`](#peal-ship).

## `peal defer`

`peal defer --reason R [--dry-run]`, in a claim's worktree: the task's text (on stdin)
written back under its number, the reason in `## Notes`, and the claim marked deferred.
For task files it lands on the backlog file on the main branch; refused for any commit
beyond the claim but those of the task's own file; for issues, the `in progress` label
taken off. Once on main the claim reads as given back
([Claim states](tasks.md#claim-states)). Then `peal release ID`, here or from elsewhere.

## `peal work`

`peal work [ID | POOL]`, the steps of `/peal:work`.

- In a task's worktree: `TASK <id> <file>`, `PLAN skipped|auto|required|agreed` (an absent `plan` is `auto`; `origin: outsider` forces `required`, whatever `plan` says, until a `## Plan` is filled), and
  `MODEL <role> <model>` per subagent. Claims nothing.
- Elsewhere: claims `ID` (`CLAIMED <id> <path>`; refused for a human task) or offers
  `POOL`.

## `peal brief`

`peal brief ROLE` prints what the planner, implementer or reviewer needs of the project:
the task, the main branch, the current milestone, the size tiers, the `context`
documents, and `.peal/planner.md` or `.peal/reviewer.md` verbatim. With the decisions
module on, the planner's brief holds the task's decision entries, the reviewer's the
diff's.

## `peal record`

`peal record ID plan|notes` records the text on stdin on this worktree's claim: the plan
the human agreed, or their answers.

## `peal close`

The steps of `/peal:close`, in the task's worktree.

### `peal close begin`

Declares the close: a sentinel in the git directory arms the Stop hook.

- Refuses outside a task's worktree, without the git hooks (where `guardrails` is set up), with more than one task under
  `doing/`, and on a branch that adds a backlog file.
- Notes, never refusing: how far the branch is behind main, the paths a merge of main
  would conflict in, milestone files the branch changes, the ideas queued, an empty
  `## Scope` or `## Done when`.
- Names where the Outcome goes (the task file; for an issue a file in the git directory),
  the project's `pr.sections`, with `pr.security` set the request for the Security line
  (`--security TEXT`: the boundary of that document the diff touches and how, or `none`),
  the diff and the `## Done when`.

### `peal close finish`

`peal close finish --summary TEXT [--decisions TEXT] [--human-steps TEXT] [--notes TEXT]
[--security TEXT] [--section TITLE TEXT]... [--review-file FILE]`. `--decisions`,
`--human-steps` and `--notes` are optional, given once, never empty; `--human-steps` that
is only none, n/a or `-` is refused (leave it out, or use `--notes`). `--security` is one
line, given once: the boundary the change touches and how, or `none`; a leading
`Security:` is dropped. It is required where `pr.security` names a threat model, and
optional elsewhere. A `pr.sections` item titled `Notes` is refused. The `-file` forms
(`--summary-file FILE`, `--decisions-file FILE`, `--human-steps-file FILE`,
`--notes-file FILE`, `--section-file TITLE FILE`) read the text from a
file. `FILE` is the reviewer's report.

- Refuses, before anything changes: a missing summary or section, a missing `--security`
  where `pr.security` is set, an empty Outcome or one
  with a placeholder, more than three escalations, a task holding `merge: auto` without
  the report and its `merge-auto:` line, an uncommitted path besides the Outcome, missing
  git hooks (where `guardrails` is set up), a remote tip of the branch (fetched first;
  a failed fetch warns and the known ref is used) that is ahead of it, or that holds
  commits this branch rewrote with no commit here of the same tree (the refusal names
  `git merge <remote>/<branch>`), and a failing `checks.close` command (read from the main branch's tip, run on the branch's
  tree; one note when the work tree's list differs; a main config that does not load,
  naming the ref, refuses).
- Then: files the queued ideas in one push; merges a remote tip whose tree equals the
  tree of a commit in the branch (a pushed autosave rewritten locally) with
  `git merge -s ours`, as `Merge <ref>: the pushed autosave, already here [ID]`; on `merge-auto: withdraw` removes
  `merge: auto`; commits the move to `done/` as `docs(tasks): close ID [ID]` (empty when
  nothing else changed); marks an open draft pull request ready for review; pushes;
  opens the pull request or updates the open one.
- Whatever fails after the flush keeps the close in progress; run it again.
- Ends with `closed NNNN: pull request #N URL`.

### `peal close body`

Takes the arguments of `finish` and prints the pull request's body: the count of
escalations and a withdrawn `merge: auto`, then `## Summary` with the summary bullets,
`## Decisions`, `## Human steps` and `## Notes` when given, `Fixes #N` for an issue
(`Task N.` for a file), the split it is part of, each `pr.sections` text, the Outcome, the
ideas filed, then the `Security: ...` line when given (Belfry reads the last such line
outside code blocks, so it comes after the Outcome) and the branch's commits.

### `peal close abort`

`peal close abort REASON` calls the close off, the reason logged in the git directory.
Queued ideas stay queued.

### `peal close verify`

Prints one verdict about the branch checked out.

- `READY` (0): open and green; also `READY:merged`, `READY:pr-closed`,
  `READY:no-checks`.
- `WAIT:<why>` (3): checks pending or not registered yet, mergeability unknown;
  `WAIT:checks-failing-pending`, a check has failed while others still run.
- `BLOCKED:<why>` (1): the close unfinished, uncommitted or unpushed work, no pull
  request, a draft pull request, conflicts, failing checks (only once nothing is pending), no `gh`, anything it cannot verify.

### `peal close wait`

Runs `verify` until the verdict is not `WAIT` or the budget is spent
(`PEAL_CLOSE_WAIT_BUDGET`, 540 seconds; `PEAL_CLOSE_WAIT_INTERVAL`, 20). A failing check
is reported only once nothing is pending, so the whole run has ended. Main writes (idea
filing, ship) still stop at the first failure.

## `peal decision`

The decisions module, when the `decisions` setting names a directory. Entries are
`<dir>/NNNN-slug.md`.

### `peal decision reserve`

`peal decision reserve SLUG` takes the next number past every entry on the remote's main,
every `refs/decisions/*` and every entry in the work tree, pushes a marker commit to
`refs/decisions/NNNN`, and scaffolds `DIR/NNNN-SLUG.md` to fill in. A loser retries with
the next number. Refused on the main branch and on a detached HEAD.

### `peal decision check`

Refuses an entry that is not well-formed, and, for what the branch changes since it left
main: a changed index, a deleted entry, a supersession not paired, an added entry with no
reservation. `GITHUB_HEAD_REF` names the branch in a pull request's workflow.

Well-formed: the file name is `NNNN-slug.md` (four digits, a kebab-case slug), not empty;
the first line is `# NNNN — Title` with the file's own number and a title; a `Status:`
line reads `accepted` or `superseded by NNNN` (NNNN an entry that exists and is not the
entry itself; `decision NNNN` is accepted, anything after the number free); no `<!--`
placeholder is left; the number is used once.

An entry that supersedes another says so in a paragraph starting `**Supersedes**`
(also `**Supersedes (in part).**`), naming right after the verb `decision NNNN`,
`decisions NNNN, MMMM and PPPP`, a link `[NNNN](...)` or a path in backticks
`` `dir/NNNN-slug.md` ``. The pairing, for entries the branch adds or changes: a `Status`
turned `superseded by NNNN` needs NNNN an entry this branch adds whose `**Supersedes**`
names it; an added entry's `**Supersedes**` must name an existing entry whose `Status`
says `superseded by` the added one. A paragraph naming none right after its verb is
refused.

### `peal decision index`

Prints the index, `<dir>/index.md`: the accepted entries by number, then the superseded
ones. A branch never changes it.

### `peal decision publish`

Regenerates the index on the remote's main and pushes it as `docs(decisions): regenerate
the index`, if it changed. Run after a merge.

The close commits the entries a task adds on their own, before the task's move to done,
as `docs(decisions): record NNNN [ID]` (`NNNN, MMMM` for several), the `decisions`
commit area.

### `peal decision brief`

`peal decision brief --task FILE | --diff [BASE]` prints the entries whose text names a
path of the task or of the diff. Superseded entries are counted, not shown.

The paths come from the task's `## Scope` (while that is empty, its `## Intent` and
`## Notes`) or from the files the diff changes since BASE, uncommitted ones included. A
candidate is a word of two or more `/`-separated parts or a file name with an extension,
stripped of backticks, quotes, brackets and trailing punctuation. An entry matches when
its text holds the candidate, its last part, or one of its directories three or more
parts deep, since entries name the directory that governs a file more often than the file.
Each match prints as `NNNN — Title (matched: KEY)` and the first line of its `**Decision.**`.

## `peal milestone-review`

`peal milestone-review [ID]` prints what `/peal:milestone-review` needs of milestone `ID`
(this worktree's task's, else the current one): its tasks not done, the milestone that
becomes current next, the parked ones with their reasons, its text, `.peal/review.md`.
Last line `READY` or `OPEN <count>`.

## `peal milestone-state`

`peal milestone-state ID done|parked|open [--reason R] [--review FILE]` is the one way a
milestone's state changes. `R` says why a parked one waits; `FILE`'s text (`-`: stdin) is
its review, under `## Review, <date>`. When none is current afterwards, the first open
milestone by order becomes current. A milestone already in that state is left as it is.
Files: written straight onto the main branch as `docs(tasks): milestone ID STATE`. Issues:
closes or opens the GitHub milestone.

## `peal ship`

`/peal:release`'s steps, each rerunnable. `VERSION` is `1.2.0` or `v1.2.0`; the tag is
`release.tag-prefix` and the version.

### `peal ship propose`

Reads the last release, the highest tag `<prefix>MAJOR.MINOR.PATCH` reachable from the
remote's main (a pre-release is never the last). Prints `LAST <tag>` (or `none`), an
`ITEM kind id prs title` line per task and per `feat` or `fix` commit of no task since,
then `PROPOSE <tag> <bump>` or `NOTHING since <tag>`. The bump: `major` when an item is
breaking, `minor` when one is a feature, `patch` when all are fixes, `first` (`v0.1.0`)
without an earlier release. Breaking: `breaking: true`, or a subject `type!:`. A fix: a
subject starting `fix`, or an issue labelled `bug`. `release-note: none` leaves a task
out of the notes and the bump.

### `peal ship notes`

`peal ship notes VERSION` prints the notes: a first line (`v0.2.0: 2 features, 1 fix
since v0.1.0.`, the tag's message), then Breaking, Features and Fixes, a line per item.

### `peal ship bump`

`peal ship bump VERSION` sets each file of `release.version-files` to the version without
the prefix, and inserts the release's entry into `release.changelog`, on the remote's
main, in one commit `chore(release): <tag>`. Either key alone is enough. Waits until a
pull request merged, for its checks and the merge however long they take (two hours, or
`PEAL_MAIN_WRITE_BUDGET`; run it in the background). Status 3: the pull request is left
open, its checks failed (named) or the budget ran out; fix it there, then run it again. `already at <version>` when
the files hold it and the changelog has an entry `## <tag>`. Refused for a path outside
the repository, a dotted field of a JSON or TOML file, a missing file or field, a field
not a string; for a nested YAML field (`KEY.KEY`, through block mappings, never into a
list or a flow mapping), a key on its path that is not a mapping, a tab-indented line,
the path there twice (also in two documents; an edit under an anchor changes its aliases
too); for a marked line (`"PATH: \"TEXT\""`), a marker held by no line or by two, a line with no
version or with two, an empty marker or one with a backslash.

The entry is `## <tag> (<UTC date>)`, a blank line, then the notes with their headings one
level down (`### Features`). It goes after the file's title line and its blank line, or at
the very top of a file without a title, the entries below kept byte for byte; a changelog
missing on main is created as `# Changelog` and the entry. It holds what went in up to the
bump: a task merged between the bump and the tag is in the tag's notes, not in it. A
pre-release gets an entry of its own.

### `peal ship tag`

`peal ship tag VERSION` tags the remote's main, annotated, and pushes. Refused for a tag
that exists, a version not above the last release, a version file not at the version, and
a `release.changelog` without an entry `## <tag>` (`peal ship bump` first). The commit
of the tag still holds the previous SHA of `release.commit-files`; `peal ship pin` sets it
after.

### `peal ship pin`

`peal ship pin VERSION` sets the tag's commit SHA (the full `git rev-parse <tag>^{commit}`)
on the one marked line of each file of `release.commit-files`, on the remote's main, in
one commit `chore(release): pin <tag>`, after `peal ship tag`: a release commit cannot
hold its own SHA. Only that SHA changes, and the line's `# vX.Y.Z` is not checked against
the tag (the two settings are independent). Waits as `peal ship bump` does (status 3 if the
pull request is left open: its checks failed or its head moved off the commit Peal built, auto-merge then turned off. Never push onto it: fix the cause in a pull request of its own, then run it again, which closes the stale one and builds afresh on the new main). `already at <sha>` when every file holds it;
`nothing to pin` with the setting empty. Refused for a tag not here and on the remote
(`peal ship tag` first), a tag whose commit the remote's main does not hold, a missing
file, a marker held by no line or by two, a line without exactly one hexadecimal
run as long as the object name (40 digits) with no letter or digit next to it (so a
longer or a short SHA never matches), and a setting item that is not the marked
form.

### `peal ship publish`

`peal ship publish VERSION` creates the GitHub release with the notes, or updates it.
On a remote not on GitHub the tag is the release.

### `peal ship wait`

`peal ship wait VERSION` waits for the tag's workflow runs (`PEAL_SHIP_WAIT_BUDGET`, 540;
`PEAL_SHIP_WAIT_INTERVAL`, 20). Prints a `RUN` line per run, a `REPORT` line per text of
`release.report`, then `READY` (0), `FAILED:<run> <url>` (1), `NONE:<why>` (1, no run
within five minutes) or `WAIT:<why>` (3).

## Environment variables and git config

| Name | Means |
|---|---|
| `PEAL_ROOT` | the Peal to run, taken as it is by the launcher; the git hooks verify it |
| `PEAL_PRIMARY` | the primary checkout's path, set for `worktree-setup` |
| `PEAL_MAIN_WRITE_WAIT` | `merged`: a write through a pull request waits for the merge |
| `PEAL_MAIN_WRITE_BUDGET` | seconds to wait for it, 540 (`peal ship bump` and `pin`: 7200) |
| `PEAL_MAIN_WRITE_INTERVAL` | seconds between polls, 20 |
| `PEAL_PUSH_ATTEMPTS` | tries of a write that keeps losing a race, 5 |
| `PEAL_CLOSE_WAIT_BUDGET`, `PEAL_CLOSE_WAIT_INTERVAL` | `peal close wait`, 540 and 20 |
| `PEAL_SHIP_WAIT_BUDGET`, `PEAL_SHIP_WAIT_INTERVAL` | `peal ship wait`, 540 and 20 |
| `peal.mainWrites` | git config: `pr` once the remote refused main (`main-writes: auto`); `git config --unset peal.mainWrites` forgets it |
| `peal.projectHooks` | git config: the hooks path `peal hooks install` replaced, which the gates chain to |
