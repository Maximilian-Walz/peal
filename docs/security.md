# Peal — security

Peal runs shell on a user's machine, installs git hooks in their repository, and feeds
issue and task text to Claude Code sessions. This is the threat model behind that: what
it protects, who might attack it, and the boundaries that hold each attacker off. Found
a gap in one: [SECURITY.md](../SECURITY.md), not a public issue.

## Assets

- **The user's repository**: its working tree, git history and git configuration
  (`core.hooksPath` above all — the git gates depend on it).
- **The user's machine**: the shell a session and its hooks run in, and the filesystem
  beyond the repository.
- **The user's GitHub token**, held and scoped by `gh`. Peal never reads, stores or
  forwards it itself; every GitHub call goes through `gh`, which carries its own auth.

## Attackers

- **An issue or pull-request author on a public repository that runs Peal.** Their text
  reaches a session as part of a prompt: an issue's body, a task's `Raw`, a review
  comment.
- **Hostile content already committed to a repository Peal runs in.** A file a session
  might read while it works, or a script placed for a hook to run by name.
- **A malicious contribution to Peal itself.** Peal is the thing that runs shell and
  installs hooks on every clone that installs it, so a change to its own commands, hooks
  or templates is the highest-value attacker of all.

## Boundaries

### A repository's own files are never what runs

Peal's commands and hooks come from the installed plugin, never a checkout's `plugin/`:
a task's branch cannot weaken the gates that judge it, and a hostile commit cannot ship
a fake `peal` for its own hooks to execute instead. The committed launcher (`.peal/peal`)
resolves `$PEAL_ROOT`, the plugin root its `SessionStart` hook recorded in the git
directory, or Claude Code's plugin cache — never a script beside it in the working tree.
A recorded or cached root runs only once verified: a `plugin.json` naming `peal` with a
version, outside every worktree of the repository and its git directory (compared as
physical paths, so a link into the repository is the repository's), inside Claude Code's
plugin cache, and listed at that version by `installed_plugins.json` when that is there.
The git hooks' stub runs the same check on `$PEAL_ROOT` too, so an in-repository
`PEAL_ROOT` is skipped; it sources nothing, reads no file of the work tree, calls no
network, and names every root it refuses and every reason it refuses a commit or a push.
Among the verified roots the highest version runs (ties: the recorded root, then the
newest cache directory). That changes which verified root is chosen, not which roots may
run, so it does not weaken the guarantee: a recorded root can no longer pin an older
Peal over a newer installed one, and `peal hooks install` and the `SessionStart` hook do
not move the record back to a verified higher version.
`peal hooks install` and the `SessionStart` hook refuse to record a root inside the
repository, and `peal init --remove` takes the hooks, the recorded root and every
`peal.*` key back out.

- Guard: `plugin/templates/launcher`, `plugin/templates/githook` (the same verifying
  block in both), `plugin/lib/githooks.sh` (`peal_hooks_install`,
  `peal_hooks_uninstall`), `plugin/lib/session.sh` (`peal_record_root`, `peal_write_root`).
- Harness: `plugin/templates/launcher.test.sh` (one table against launcher and stub),
  `plugin/templates/githook.test.sh` (a hostile clone driven by real git: a planted
  plugin, launcher and hooks directory, a recorded root and `PEAL_ROOT` in the work tree,
  failing cache entries, network tools shimmed), `plugin/lib/githooks.test.sh`,
  `plugin/lib/init.test.sh` (removal).

Limits this boundary does not cover, accepted for now:

- **`checks.close` comes from main; the main ref's name does not.** `peal close finish`
  reads `checks.close` from the main branch's tip (`peal_config_load_ref`, `git show
  REF:.peal/config.yml`), never from the work tree, so a branch cannot choose the commands
  its own close runs; the commands still run on the branch's tree, as the project's own
  build and tests must. A branch whose list differs gets one note naming both; a main
  config that does not load refuses before anything changes, and no config on main means no
  close check. Tests: `plugin/lib/close.test.sh` (`main_checks_cases`) and
  `plugin/lib/config.test.sh` (`peal_config_load_ref`). The remaining limit: the ref is
  named by the work tree's `remote:` and `main:`, which a branch can change to point at a
  ref it controls (the gate-settings-from-main task, 0091).
  - Guard: `plugin/lib/config.sh` (`peal_config_load_ref`), `plugin/lib/close.sh`.
- **`checks.commit` runs the checked-out tree.** The commands the `commit-msg` gate runs
  are the project's own build and tests, and they run what the branch holds; that is
  their job. Which commands run still comes from the work tree's `.peal/config.yml`, so
  a branch can change them; reading the gates' settings (`checks.commit`, `main`,
  `tasks`, `milestones`) from the main branch's tip instead is a task of its own.
- **`worktree-setup` runs a command from the config.** `peal claim` runs it in every
  new worktree, and it comes from the work tree's `.peal/config.yml`, so a branch can
  change it, the same class as `checks.commit`. Nothing limits it: no timeout, the
  caller's environment, plus `PEAL_PRIMARY`.
- **In-tree project hooks.** When the hooks path the install replaced
  (`peal.projectHooks`) is a directory of the work tree, such as `.githooks`, the stub
  chains to the hooks there, which a branch can change. Only that configured path runs;
  an unconfigured hooks directory in the tree never does.
- **A committed `stages:` line installs the hooks without asking.** A `guardrails` stage
  recorded in `.peal/config.yml` makes `peal claim` and the `SessionStart` hook set
  `core.hooksPath` in the clone themselves (`peal_hooks_ensure`,
  `plugin/lib/githooks.sh`), the same write a human runs by hand with `.peal/peal hooks
  install`; a branch can add the line, but only what `peal hooks install` always did
  runs, at the same verified root, and never over a `core.hooksPath` already set to
  something else (that is only warned about). Accepted: the write is exactly the one the
  project's own committed config already asked for.
- **Newest wins, whatever pinned the older one.** The highest verified version runs even
  over a deliberate project-scope pin of an older Peal, and candidates are not limited to
  the recorded root's marketplace: another marketplace's `peal` with a higher version in
  the cache wins. Versions are compared by number only; a version of another shape is
  incomparable and never wins on version.
- **The committed launcher.** `.peal/peal` is a file of the repository: a branch can
  replace it, and whoever runs `.peal/peal` by hand, or Belfry's contract, runs the
  branch's copy; nothing inside the launcher can guard against its own replacement. That
  stays a limit. The SessionStart hook reports it to a session (a `Launcher:` line when
  `.peal/peal` is not byte-identical to the running Peal's `templates/launcher`; silent
  when it matches or is missing), and `peal doctor version` fails on it; Belfry's
  contract path is not covered. The git hooks never run the launcher; they find Peal
  themselves. CI (`tools/lint.sh`) fails when the two in-tree copies differ; it does
  not guard against a branch replacing both. Guard: `peal_launcher_matches` (`plugin/lib/session.sh`). Harness:
  `plugin/lib/session.test.sh`.
- **A repository that holds the plugin cache.** A Peal under a worktree of the
  repository is refused even when it is Claude Code's cache (a repository at `$HOME`,
  say): the hooks then refuse until Peal is found elsewhere.

### No git gate can be bypassed from inside a Bash call

Before a Bash tool call runs, the git guard scans the git invocations inside it — not
its text, so a commit message or a grep that mentions `--no-verify` passes — and refuses
`--no-verify`, a changed or unset `core.hooksPath`, a commit or push onto the main
branch by hand, and `git lfs install --force` overwriting Peal's hooks with LFS's.

- Guard: `plugin/lib/git-guard.sh`, Claude Code's `PreToolUse` hook on Bash.
- Harness: `plugin/lib/git-guard.test.sh`.

### Nothing reaches main but a merged pull request or Peal's own narrow writes

The `pre-push` gate walks every commit a push would add to main's first-parent line and
refuses it unless it is one of Peal's own mechanical commits — filing, revising, deferring,
retiring a task, a batch of those (`peal apply`), a milestone's state, the decisions index, a release's version files (or marked lines),
changelog entry and commit SHAs — whose diff has exactly the shape its subject claims. Rewriting or
deleting main is refused outright, and so is its first push (the remote has no main): which
commits it adds would be told by the local remote-tracking refs, files anyone can fake, and
the hook makes no network call, so it refuses in one line; that push is the human's own,
outside the gate. So is any merge made on this machine: a
remote-tracking ref is a local file, so "a branch pushed first" proves nothing, and a
merged pull request is made on the server, where no pre-push runs. The gate is a guard
against honest mistakes; branch protection on main is what stops a deliberate push.

Limit: a release's changelog entry is checked by its shape only. The gate refuses
anything but one entry inserted after the title (or a new `# Changelog` holding it),
headed `## <tag>` for the subject's tag, with no other `##` heading, the parent holding
no entry of that tag, and every other byte unchanged; it does not rebuild the entry
from the release's notes, so text a local push writes within that entry passes. It
lands on main as a visible commit of its own, in a file Peal never runs or trusts.

Limit: a release's pin (`chore(release): pin <tag>`) is checked against the tag in the
pusher's own clone, because a pre-push hook makes no network call. The gate refuses a
tag it does not have (`git fetch --tags`), a tag whose commit is not before the pushed
commit, and any change but the one SHA of a marked line of `release.commit-files` set
to that commit; it cannot tell a tag made up locally from the remote's. A SHA of a
local-only tag lands on main as a visible commit, in a file (the decisions workflow
template) that a project copies and reviews. `peal ship pin` itself checks the tag on
the remote.

Limit: a batch (`docs(tasks): apply N proposals`, `peal apply`) is the widest of these
shapes: its subject must be exactly that, and its diff may add or modify any number of
backlog task files and of milestone files (`<milestones>/<name>.md`, not in a
subdirectory, mode 100644) and move any number of the task files to `done/` under the
same name, nothing else (no done file changed or deleted, no milestone file deleted or
renamed, no other path). The gate checks the shape, not which tasks or what text: a local
push under that subject can rewrite every backlog task's and milestone's text in one
commit, as a run of `revise` and `milestone-state` commits nearly could, visibly, in the
task and milestone files alone.

The text of those writes is read too, not only their shape (`_peal_pre_push_content`):
every backlog task file a `file`, `revise`, `defer`, `set milestone`, `note` or `apply`
commit adds or modifies is parsed before and after (`merge-gate.awk` with `guard=1`), and
the push is refused when either frontmatter does not parse, `merge` is added or changed,
`origin` is dropped or changed, or the `## Plan` or `## Outcome` goes from empty to
filled. An added file is held to `peal create`'s rules: no `merge`, and an `origin:
outsider` text with no filled Plan or Outcome. Only an `apply` commit whose body holds the
vouch line `- <id> (vouch NNNN): ` may drop task NNNN's `origin: outsider`, as `peal
apply`'s `vouch` proposal writes it. So a push under a storage subject can no longer turn
an outsider's task into a writer's, grant itself `merge: auto`, or write a Plan that
`peal work` would read as `PLAN agreed`. The storage refuses the same before it pushes:
`peal revise` and `peal defer` (`peal_edit_check`) refuse a dropped or changed `origin`
and a newly filled Plan, so a deferred claim gives its agreed Plan back empty
(`/peal:defer`), and a writer's pre-written plan goes through `peal create` or the human's
own pull request. A record never reaches this gate: it is a commit on the claim branch,
or an issue edit.

Limits, open: a Plan already filled may be rewritten by a `revise` push (the text is
checked for what is new, not for what changes in a section that was agreed); and the
subject and the vouch line are strings the pusher chose, so a deliberate push can forge
a vouch. Both are the honest-mistake gate's limits: branch protection on main is the
real block.

- Guard: `plugin/lib/githooks.sh` (`_peal_pre_push`, `_peal_pre_push_content`),
  `plugin/lib/merge-gate.awk` (`guard=1`), `plugin/lib/tasks.sh` (`peal_edit_check`).
- Harness: `plugin/lib/githooks.test.sh` (`pre_push`: revise dropping `origin:
  outsider`, adding or changing `merge`, filling `## Plan`; the first push of main, honest or with a faked remote-tracking ref; note and set-milestone
  dropping or changing `origin`; defer filling the Outcome; apply without a vouch line or
  with another task's; an outsider's file with a filled Plan; a file setting `merge`;
  frontmatter that does not parse; and the writes still allowed),
  `plugin/lib/store-files.test.sh` (revise), `plugin/lib/backlog.test.sh` (defer).

### `peal create`'s stdin is data, filed byte for byte, never a shell word

Belfry runs `tasks.commands.create` (`peal create --owner {owner} --title {title}
--origin {origin}`) itself, outside any session's sandbox, with the untrusted text an
outsider's issue or comment produced on stdin. `{owner}`, `{title}` and `{origin}` are
the only pieces the contract fills into the command line, and all three are checked
before anything is written: `owner` must be `ai` or `human`, `origin` must be `outsider`
or `writer`, or the call is refused, and `title` only ever feeds a slug (`peal_slugify`'s
normalisation, at least two words) and, when the text has no heading, the one-line
`# NNNN — title` written into it (control characters to spaces) — none reaches a shell, a filename outside the
storage's own naming, or `eval`. The text itself never becomes a shell word either: it is
read from stdin into a file and, apart from `NNNN` becoming the id it is given, `owner`
set or dropped for the `--owner` flag, the title heading added when the text has none, and `origin` set to `outsider` or dropped for the
`--origin` flag, lands in the task file exactly as given, checked the same way any other
filing is (`peal_task_check`) plus two rules narrower than a human's own `peal create`: a
text that sets `merge` is refused (an untrusted filer cannot make its own task merge
itself) and one that holds the `-----NEXT TASK-----` delimiter is refused (it may file
only the one task it was asked to, never more). `origin: outsider` itself marks the task
external for whatever reads the board next (Belfry's contract): its title and text reach
a session quoted as data, its job never runs unattended, and its pull request never
merges itself. Only a `vouch` proposal of `peal apply` drops the mark (see below).

- Guard: `plugin/lib/backlog.sh` (`peal_create_filed`).
- Harness: `plugin/lib/store-files.test.sh`, `plugin/lib/store-issues.test.sh`,
  `plugin/lib/hostile.test.sh`.

### Text from outside added to a task's Notes

Belfry runs `tasks.commands.revise` (`/peal:comment {task} {text}`) as a session job:
`{text}` is a prompt, never a shell command, and `/peal:comment` hands it to `peal comment`
through a file, never as a composed shell word. Text that Belfry says came from outside
goes with `--origin outsider`, which marks the task `origin: outsider` in the same commit
(its job then never runs unattended, its pull request never merges itself). `peal
comment` refuses any text with a line that is `---` or starts with `## `, so a note cannot
end the frontmatter or open a section of the task file.

- Guard: `plugin/bin/peal` (`comment`), `plugin/lib/store-files.sh`
  (`_peal_files_rewrite_comment`).

### `merge: auto` is the human's

`merge: auto` lets a control plane merge a pull request once its checks are green, with no
human looking at it: it stands for the human's consent to that merge, so it is a record no
session can write. A session steered by unmarked content, or a model's mistake in an
unattended job, could otherwise set the field on its own claim and have its pull request
merged. So no text a session writes adds `merge`: `peal record`, `peal revise` (on the
main branch and on a claim) and issue edits refuse a text whose `merge` is set and
differs from the text before (`peal_merge_added`; taking it away, the reviewer's withdraw
or a revise, is always allowed), and no `peal apply` kind but `file` carries frontmatter; every filing (`peal create`, `peal
idea`, the ideas a close files, a split's pieces, `peal create --owner`, `peal
idea-fields`, `apply`'s `file`) refuses a text that sets `merge` at all; `peal frontmatter
set` and `set-list` refuse the key, `unset` keeps working; `peal comment` reaches only the
Notes. The board takes `merge` only from the main branch's copy of a task file, or the
issue's label: a claim branch's copy can only empty it, never grant it.

Where the agreement lives: under a control plane, in the control plane's own record of the
human's answer to the plan; without one, in `merge: auto` the human writes themselves:
the issue's label, at any time, or, for a task file, the field on the main branch (their
own pull request) before the task is claimed. A claim copy can only withdraw `merge`, so
in the files storage a field the human writes on the main branch after the claim never
reaches the board. `/peal:work` writes
`merge: auto agreed by the human (<date>)` under the task's Notes when the human agrees it:
a trace that grants nothing, which only makes the close ask the reviewer whether the diff
still earns it. A forged line adds a review question and nothing else. The close's
`merge-auto: withdraw` removes the field where the task holds it and, either way, puts
"merge: auto withdrawn" at the top of the pull request's body, for the control plane to
leave the merge to the human.

Known gap: a session with a `gh` login that may label issues can add the `merge: auto`
label itself; the issues storage relies on the control plane withholding that login (`gh`
holds the token, below).

- Guard: `plugin/lib/tasks.sh` (`peal_merge_added`, `peal_edit_check`),
  `plugin/lib/work.sh` (`peal_record`), `plugin/lib/task-check.awk` (filings),
  `plugin/bin/peal` (`frontmatter`), `plugin/lib/store-files.sh` (`_peal_files_overlay`,
  `_peal_files_build_rewrite`), `plugin/lib/close.sh` (`_peal_close_merge_asked`).
- Harness: `plugin/lib/store-files.test.sh` (`claim_copies`, revise, comment, create,
  idea), `plugin/lib/work.test.sh` (`record`), `plugin/lib/store-issues.test.sh`
  (`merge`), `plugin/lib/close.test.sh` (`merge_cases`).

### A batch of proposals on stdin is data, read without a shell or jq

Belfry runs `tasks.commands.apply` (`.peal/peal apply`) itself, outside any session's
sandbox, with a JSON document on stdin whose texts may come from outside the project (an
issue's, a comment's). The command line carries nothing of it. `lib/apply.awk` reads the
document under `LC_ALL=C` and writes every value to a file of its own, its `\uXXXX`
escapes decoded (a `\u0000` or a lone surrogate refused); no value is ever put on a line
a shell splits, into a command, or into `eval`. A field's name is taken only when it is
plain letters and `_`, a value only when it is a string, number or null; an object, an
array or an unknown field makes the proposal invalid (Belfry's `ref`, `item` and `into`
are the fixed exceptions, stepped over whatever scalar they hold, never used). The one array is `tasks`, a
`split_milestone`'s list (the awk is told which keys take one): each item must be a string
and goes to a file of its own, decoded like any value, never joined with the others; a
number, null, object or nested array as an item, an empty array, a duplicate, or an item
that is no `NNNN` or `@` and an earlier `file` proposal's id makes the proposal invalid,
and the milestone `milestone` is the one split. Ids are checked against their
shape (`NNNN`, or `@` and a proposal id of the batch), milestones against
`[A-Za-z0-9._-]+` (or `@` and an earlier `milestone_create`'s or `split_milestone`'s id), and the closed sets
(kind, priority, owner, origin on every kind, a milestone's state verb) by value; a task's title
only feeds a slug and, when the text has no heading, its one-line heading. A `file` text gets the checks of `peal create --owner`'s (`merge` and
the delimiter refused, `peal_task_check`), an `add` text those of `peal comment` (no
`---` or `## ` line), a `retire` reason is one line. A milestone's title and a parking's
reason are one line with no tab, written through the frontmatter writer (quoted) or as
the `# ` heading; a `vouch` drops a task's `origin: outsider` and notes it, and is refused when it names an `@<id>` or itself carries `origin: outsider`. Peal cannot verify that a human sent it: it relies on the caller offering a vouch to the human only. A goal is prose with no `---` or `## ` line; a due a calendar date, an
order an integer; a new milestone's file name is Peal's id, never the caller's. One
invalid proposal and nothing is written.

Two writes go beyond the batch's own commit. A `depends` proposal on the claim of the
worktree `apply` runs in gives that claim back, and its `why` (one line, or "waits for
<on>") is written into the backlog task's `## Notes` as "Deferred <date> after a claim:
<why>"; with `origin: outsider` on the proposal the task gets `origin: outsider`, as `add`
does. And `apply` then commits in that worktree (`wip: defer capture [<id>]`), recording
the claim's file there so the worktree can go clean; no proposal text is in that commit.

A value goes to three places: the task and milestone files (checked as above), the JSON answer
(escaped), and the commit's body and the pull request's body, which list each
proposal's `id` and `why`. In those bodies a zero-width joiner follows every `#` and `@`,
and every `issues/` and `pull/`, so a closing keyword in outside text ("Fixes #12",
"closes owner/repo#3", an issue's URL) closes nothing and an `@mention` pings nobody when
the write merges.

`apply.sh` holds the fields in shell variables, each named only from a proposal's index
(digits) and a key matching `^[a-z_]+$` (checked by `apply.awk` and again as the manifest
is loaded); a value is only ever data, never part of a variable's name or a command.

- Guard: `plugin/lib/apply.awk`, `plugin/lib/apply.sh`.
- Harness: `plugin/lib/apply.test.sh`, `plugin/lib/hostile.test.sh`.

### A commit must clear the project's own checks before it lands, even mid-branch

Outside the fast paths for task files and decision entries, the `commit-msg` gate runs
`checks.commit` against the staged diff before accepting a commit, so a compromised or
merely careless session cannot commit past the project's own build or lint.

- Guard: `plugin/lib/githooks.sh` (`_peal_commit_msg`, `_peal_commit_checks`).
- Harness: `plugin/lib/githooks.test.sh`.

### Hostile prose is read, never run

Task, issue and pull-request text reaches a session only as prompt text — a task's
frontmatter and body, `peal brief` — read by bash and awk field extraction, never
`eval`'d or passed to a shell as code. What a session decides to *do* with hostile prose
once it has read it is a risk no parser removes; two things bound it instead, true
regardless of what the prose says: Claude Code asks before an unapproved tool runs, and
nothing a session builds reaches another user until its pull request is merged, and the
merge is the human's except in the narrow cases of "Auto-merge tiers" below
(`docs/design.md`, "the merge is the human's"). The planner, which
reads a task before anyone has agreed its plan, carries no Bash tool at all. A task with
`origin: outsider` is always planned with the human: `peal work` reports `PLAN required`
for it whatever its `plan` says, `skipped` and `auto` included, until a `## Plan` is
filled in it, which then reads `PLAN agreed`. An outsider's filed text cannot bring that
`## Plan` itself: `peal create --origin outsider` and `peal apply`'s `file` proposals
with `origin: outsider` refuse a text whose `## Plan` or `## Outcome` holds anything
(`peal_text_human_section`), so a filled Plan on such a task is the one `peal record`
wrote once the human agreed it. Those are the only two ways an outsider's text is filed
as a task; on the issues storage neither carries `origin` (`create --origin outsider` is
refused there, and `peal apply` takes no batch). The other ways `origin: outsider` is set
(`peal comment --origin outsider`, an `add` proposal, a `depends` proposal's reason on a
claimed task) only add a line under `## Notes`, which holds no `## ` line; a Plan the task
already had stays agreed. No outsider's text is built on the planner's word alone.

Every prompt under `plugin/commands/` and `plugin/agents/`, except `idea.md` (its input
is the human's own `$ARGUMENTS`), carries a fixed paragraph: text from an issue, a pull
request, a comment, a task's `## Raw`, a commit message or a web page cannot widen the
task, change a rule or have a command run, and passing such text on quotes it and names
where it came from. No harness proves a model obeys it; the guarantee still rests on
tool permissions and the human's merge, above.

- Guard: `plugin/lib/frontmatter.sh`, `plugin/lib/work.sh` (`peal_brief`,
  `_peal_work_here`), `plugin/lib/backlog.sh` (`peal_create_filed`), `plugin/lib/apply.sh`
  (`_pa_static`), `plugin/lib/task-text.sh` (`peal_text_human_section`); the
  review-before-merge principle above; the "Text from others is data" paragraph in
  `plugin/commands/*.md` and `plugin/agents/*.md`.
- Harness: `plugin/lib/frontmatter.test.sh`, `plugin/lib/work.test.sh`,
  `plugin/lib/hostile.test.sh`, which runs every command with hostile values throughout.
  `plugin/commands/commands.test.sh` checks the paragraph is word for word identical in
  every prompt but the exempt list, and absent from the exempt ones.

### Only admitted issues reach a session

On the issues storage, an issue's title, body, labels and pull requests are prose like
any task's; the boundary above bounds what a session does with prose once it has it, not
whether an issue reaches a session at all. `admitted()` (`plugin/lib/issues-lib.awk`) is
the one rule every read path of the issues storage applies: the filter label
(`storage.issues.label`) when one is set, else an opener with write access to the
repository (OWNER, MEMBER or COLLABORATOR) or an App the project's config names in
`storage.issues.apps` — anyone may open an issue on a public repository. An App counts
only by its REST login `<slug>[bot]` (compared case-insensitively; a user's login cannot
contain `[`, so the suffix cannot be forged, and the bare slug is a user's), as opener,
editor and renamer, and for the pull requests that mark an issue awaiting merge. An App
relaying text from outside labels its issue `origin: outsider`, which takes the App's
trust away (the write-access rule stays; with a filter label the label still vouches, an
edit after it does not); that refusal names the label and quotes nothing. The limit: the
setting is read from the work tree, as `storage.issues.label`, so a branch could widen it
for its own session; moving both to the main branch's config is the gate-settings-from-main
task (0091). `read`, `claim`, `work` and `defer` refuse an issue the rule does not admit
and quote none of its text; `list`, the board, the depends expansion and `ship`'s release
notes apply the same rule, an unadmitted issue a commit subject names getting the
commit's own subject in the notes, never the issue's title.
`/peal:setup`'s sample of candidate issues applies the same writer rule (write access, or an App
named in a `storage.issues.apps` setting already present, unless `origin: outsider`); its
test is the `issues_candidates` case in `plugin/lib/setup.test.sh`.

Labelling (or write access) alone is not the end of it: with a filter label configured,
an edit later than the issue's own labelling of the filter label is admitted only when it
is by someone with write access — a non-author editor is inferred one already, since
GitHub lets only a collaborator edit someone else's issue, so only the author's own later
edit is checked against their association; a missing edit event or a failed call refuses,
never admits. The check holds on every single-issue path (`read`, `claim`, `work`,
`revise`, `close` and the session's cached copy — `defer` included) and on the listing:
`list`, the board, the overview and `offer` leave out every listed issue, open or closed,
that it refuses, as they leave out an unadmitted one, and fail (status 2) when the edits
cannot be read; `ship`'s release notes give such an issue the commit's own subject, as
for an unadmitted one, and do the same for all of them when the edits cannot be read. The
edits come from one batched GraphQL call per 100 issues (`_peal_issues_edits_batch`,
only the last 100 labelled and renamed events of each read). A stranger who labelled
their own issue cannot, then, slip a task's real text in after the maintainer looked
away; re-labelling (taking the filter label off and on again) is how a maintainer
re-admits an edit once they have read it. An issue only named by a task's depends or
part-of is not checked: only its state is used (below). No extra `gh` call is made
without a filter label configured.

A task depending on a stranger's issue still reads its state (open or closed) to know
whether it is done, the one thing that crosses the boundary, never its text. No command
reads comments.

- Guard: `plugin/lib/issues-lib.awk` (`writer()`, `admitted()`, `edit_admitted()`,
  `edit_row_admitted()`), `plugin/lib/issues-scan.awk`, `plugin/lib/store-issues.sh`
  (`_peal_issues_admitted`, `_peal_issues_edits_batch`, `_peal_issues_scan`),
  `plugin/lib/claim.sh`, `plugin/lib/work.sh`, `plugin/lib/ship.sh`
  (`_peal_ship_issue_items`).
- Harness: `plugin/lib/hostile.test.sh` (the issues storage's channels),
  `plugin/lib/store-issues.test.sh`, `plugin/lib/ship.test.sh`.

### `gh` holds the token; Peal only calls it

Every GitHub call goes through the `gh` CLI, so nothing in Peal reads, stores or
forwards the user's token; scoping and revocation are `gh`'s own auth store, not
Peal's problem to get right. Peal's `gh` runs with gh's telemetry off (`GH_TELEMETRY=0`
unless the user set it), so its calls reach only GitHub's API, not `cafe.github.com`. The `gh` calls an agent runs
itself from the command markdown are covered the same way in a Claude Code session: the
SessionStart hook writes the export to `CLAUDE_ENV_FILE`, so every Bash command of the
session inherits it. `gh` run outside Claude Code is the user's own.

Under Belfry the session holds no token at all: its sandbox hides the worker's `gh` login.
That keeps the boundary and tightens it. Peal's `gh` calls there fail with gh's exit 4,
which `peal_gh` reports as "no login" (`BLOCKED:no-gh-login` from `close verify`;
`peal list` reads it as an unknown pull request state), never as a reason to look for a
token elsewhere. The pull request is opened by Belfry's `pr_create` tool, which acts as
Belfry's own identity, not the session's; `close finish --pr-by-tool` only hands it the
title and body (at most 256 and 65536 characters, refused rather than truncated) and the
session reports the number back with `peal close opened`.
The writes that need a login refuse up front, before any git or GitHub change, after
asking `gh auth token` (offline; `peal_gh_login`): a write onto a main branch that
refuses direct pushes pushes no `peal/main-write-*` branch, `peal ship publish` makes no
`gh release` call, and the issues storage changes no issue. Every function that calls
`gh` is listed, with what it does under Belfry, in [Running under
Belfry](guides/belfry.md#what-a-session-can-and-cannot-rely-on).

- Guard: `plugin/lib/github.sh` (`peal_gh`, `peal_gh_need_login`), the main path, and
  the telemetry export in `plugin/bin/peal`; the board's lookup of open pull requests
  (`_peal_files_prs` in `plugin/lib/store-files.sh`) calls `gh` directly.
- Harness: `plugin/lib/store-issues.test.sh`, `plugin/lib/ship.test.sh`,
  `plugin/lib/main-write.test.sh`, through the fake `gh` (`plugin/lib/fake-gh`) that
  sees every call a harness makes; `plugin/lib/gh-callers.test.sh` keeps the list of
  callers complete.

### CI that runs on a stranger's pull request cannot write or reach secrets

The workflow's top-level `permissions: contents: read` leaves every job read-only by
default; a fork's pull request runs only the harnesses, the merge gate and `shellcheck`,
nothing that needs a secret or a write.

Every action runs at a pinned commit SHA, which Dependabot keeps current, and OpenSSF
Scorecard checks the workflows weekly. The workflow templates
(`plugin/templates/decisions.yml`, `plugin/templates/merge-gate.yml`) ship their action
and their Peal pinned by SHA too: Dependabot keeps the action current across `/` and
`/plugin/templates`, the Peal pin follows each release (its tag set by the release, its
SHA by `peal ship pin` after the tag, checked by `tools/pins.test.sh`), and
`tools/pins.sh` refuses an unpinned reference in the templates or in Peal's workflows.

The release workflow (`.github/workflows/release.yml`) is the one that writes, and only
on a dispatch by someone with write access. Its dry run is a job with no secret and no
write. The writing job runs only for a real run on `main`, in the `release` environment
that only `main` may enter, and writes with a GitHub App's token minted for that run:
the App is no bypass actor, so main's rules hold for it as for anyone, and no fallback to
the run's `GITHUB_TOKEN` exists. The token stays out of the checkout
(`persist-credentials: false`) and out of `$GITHUB_ENV`; each writing step gets it in
its own `env`, git through a credential helper that reads it there, and inputs and
secrets reach the shell only through `env`, never spliced into a `run:`.

- Guard: `.github/workflows/ci.yml` (`permissions:`, the pinned `uses:`),
  `.github/workflows/release.yml` (its two jobs, `environment: release`, the App
  token), `.github/dependabot.yml`, `.github/workflows/scorecard.yml`,
  `plugin/templates/decisions.yml`, `plugin/templates/merge-gate.yml`, `tools/pins.sh`.
- Harness: `tools/pins.test.sh`; Scorecard's weekly run reports an unpinned action or a
  broad permission.

### Auto-merge tiers

Merging ships: the marketplace installs `./plugin` from the default branch. Under
Belfry's contract (`.belfry.yml`), these pull requests merge without the human, each
only with `shellcheck` and both `harnesses` jobs green: task files and milestone texts,
documentation outside `docs/security.md`. Tasks whose `merge: auto` the human agreed
with the plan are meant to join them once Belfry acts on its own record of the answer
(never a field a session wrote, see "`merge: auto` is the human's"); until then such
pull requests wait for the human. Guard code (the `review_before_merge` paths: the CLI, the storage,
claim and work libraries, the task checks, close and config libraries, the prompts under `plugin/commands/` and `plugin/agents/`,
`CLAUDE.md`) merges by itself only once a fresh `security-pr` review passed on the
pull request's head, after an hour's grace for the human's Hold. What could loosen the
gates or the release chain (hooks, launcher and githook, `githooks.sh`, `git-guard.sh`,
`session.sh`, `main-write.sh`, `ship.sh`, `plugin/commands/release.md`, the plugin and
marketplace manifests, `.peal/`, CI helpers, the merge gate, this file and
`SECURITY.md`) always waits for the human, as do `.belfry.yml`, `.github/**` and
`.claude/settings.json`.

The tiers would combine into a way around the human: a task-files pull request merges by
itself on its paths, and could write `merge: auto` into another task, whose own pull
request the `agreed tasks` rule would then merge. `peal merge-gate BASE HEAD` closes that
route: a pull request fails when a task file under `backlog/` or `doing/` that it adds or
changes holds a `merge` key (any value, read raw, not as the board normalises it) that
BASE did not already give a task of the same id outside `done/`, or when such a file's
frontmatter does not parse (the board would read it differently from the gate). It reads
git objects only, BASE's settings for BASE and HEAD's for HEAD, so a pull request that
moves the tasks folder is judged by where its own settings put the tasks; any doubt (a
missing or all-zero BASE, settings that do not load, git failing) fails it. A close's
move into `done/` passes: the task's own pull request carries the `merge` the human
agreed. In Peal's CI the gate is a step of the `changes` job, so it fails the required
`harnesses (ubuntu-latest)` that every auto-merge rule waits for; it runs BASE's Peal
(a worktree of BASE), never the pull request's. An adopting project copies
`plugin/templates/merge-gate.yml`, which fetches Peal pinned by SHA, makes its
`peal merge-gate` job required and lists it in its auto-merge rules' checks
([the Belfry guide](guides/belfry.md)); changing that workflow or the pin needs a
`.github/**` change, which never merges by itself.

The two lists in `.belfry.yml` (`never_auto_merge` and `review_before_merge.paths`) follow
the `- Guard:` lines of this file, and CI checks it: `tools/lint.sh` runs `tools/guards.sh`,
which fails naming any `plugin/`, `tools/` or `.peal/` path a Guard line names that
neither list covers.

- Guard: `tools/guards.sh`, `plugin/lib/merge-gate.sh`, `plugin/lib/merge-gate.awk`, the `peal merge-gate`
  step of `.github/workflows/ci.yml`, `plugin/templates/merge-gate.yml`.
- Harness: `plugin/lib/merge-gate.test.sh`, `plugin/lib/hostile.test.sh`,
  `tools/pins.test.sh` (the template's pin).

Its limits:

- **The direct push.** `peal revise` and `peal comment` push onto main without a pull
  request, so this gate does not see them. Closed by 0180: the pre-push gate reads their
  text, and refuses `merge` added or changed, `origin` dropped or changed and a newly
  filled Plan or Outcome ("Nothing reaches main but a merged pull request or Peal's own
  narrow writes", above).
- **The bootstrap.** While BASE has no `plugin/lib/merge-gate.sh` (the pull request that
  adds the gate), Peal's CI runs the pull request's own gate. That pull request changes
  `.github/**` and the gate's files, so a human merges it; every later one runs BASE's.
- **`pull_request`, not `pull_request_target`.** The gate runs with a read-only token and
  no secret, so a fork's pull request reaches nothing, and the code it runs is BASE's (or
  the template's pinned Peal), never the head's. The workflow file itself is the pull
  request's own under `pull_request`, so one that edits the step away touches
  `.github/**`, which a human merges. The price: a fork's run can be held for a
  maintainer's approval, and until it runs the required check is missing, which holds
  the merge rather than letting it through.
- **A changed plan under an agreed `merge`.** The gate refuses a `merge` key that arrives;
  it lets a pull request edit the rest of a task that already holds `merge: auto` on
  main. A task-files pull request, which merges by itself, can therefore rewrite the
  `## Plan` or `## Scope` the human agreed `merge: auto` for, and the task's own pull
  request then merges by itself under the agreed plan's name. Open; an idea filed by
  0161 proposes a gate for it.

## What this milestone leaves open

This threat model is m1's first task; the rest of m1 closes what it can only name here:
0039 runs every command against hostile values in CI; 0040 showed the git hooks and the
launcher execute nothing a repository ships, and that `peal init --remove` leaves
nothing behind, with the limits listed under the first boundary above; 0041 pinned the CI
supply chain and checked each job's permissions. 0089 reads `checks.close` from the main
branch's tip; reading the gates' settings from it as well (and the main ref's name, 0091)
is a task of its own.
