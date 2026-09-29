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
`peal hooks install` and the `SessionStart` hook refuse to record a root inside the
repository, and `peal init --remove` takes the hooks, the recorded root and every
`peal.*` key back out.

- Guard: `plugin/templates/launcher`, `plugin/templates/githook` (the same verifying
  block in both), `plugin/lib/githooks.sh` (`peal_hooks_install`,
  `peal_hooks_uninstall`), `plugin/lib/session.sh` (`peal_record_root`).
- Harness: `plugin/templates/launcher.test.sh` (one table against launcher and stub),
  `plugin/templates/githook.test.sh` (a hostile clone driven by real git: a planted
  plugin, launcher and hooks directory, a recorded root and `PEAL_ROOT` in the work tree,
  failing cache entries, network tools shimmed), `plugin/lib/githooks.test.sh`,
  `plugin/lib/init.test.sh` (removal).

Limits this boundary does not cover, accepted for now:

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
- **The committed launcher.** `.peal/peal` is a file of the repository: a branch can
  replace it, and whoever runs `.peal/peal` by hand runs the branch's copy. The git hooks
  never run it; they find Peal themselves.
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
refuses it unless it is a merge of a branch pushed first (never content made up as a
merge parent), or one of Peal's own mechanical commits — filing, revising, deferring,
retiring a task, a milestone's state, the decisions index, a release's version files and
changelog entry — whose diff has exactly the shape its subject claims. Rewriting or
deleting main is refused outright.

Limit: a release's changelog entry is checked by its shape only. The gate refuses
anything but one entry inserted after the title (or a new `# Changelog` holding it),
headed `## <tag>` for the subject's tag, with no other `##` heading, the parent holding
no entry of that tag, and every other byte unchanged; it does not rebuild the entry
from the release's notes, so text a local push writes within that entry passes. It
lands on main as a visible commit of its own, in a file Peal never runs or trusts.

- Guard: `plugin/lib/githooks.sh` (`_peal_pre_push`).
- Harness: `plugin/lib/githooks.test.sh`.

### `peal create`'s stdin is data, filed byte for byte, never a shell word

Belfry runs `tasks.commands.create` (`peal create --owner {owner} --title {title}
--origin {origin}`) itself, outside any session's sandbox, with the untrusted text an
outsider's issue or comment produced on stdin. `{owner}`, `{title}` and `{origin}` are
the only pieces the contract fills into the command line, and all three are checked
before anything is written: `owner` must be `ai` or `human`, `origin` must be `outsider`
or `writer`, or the call is refused, and `title` only ever feeds a slug (`peal_slugify`'s
normalisation, at least two words) — none reaches a shell, a filename outside the
storage's own naming, or `eval`. The text itself never becomes a shell word either: it is
read from stdin into a file and, apart from `NNNN` becoming the id it is given, `owner`
set or dropped for the `--owner` flag, and `origin` set to `outsider` or dropped for the
`--origin` flag, lands in the task file exactly as given, checked the same way any other
filing is (`peal_task_check`) plus two rules narrower than a human's own `peal create`: a
text that sets `merge` is refused (an untrusted filer cannot make its own task merge
itself) and one that holds the `-----NEXT TASK-----` delimiter is refused (it may file
only the one task it was asked to, never more). `origin: outsider` itself marks the task
external for whatever reads the board next (Belfry's contract): its title and text reach
a session quoted as data, its job never runs unattended, and its pull request never
merges itself.

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
- Harness: `plugin/lib/store-files.test.sh`, `plugin/lib/hostile.test.sh`.

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
nothing a session builds reaches another user until its pull request is reviewed and
merged by a human (`docs/design.md`, "the merge is the human's"). The planner, which
reads a task before anyone has agreed its plan, carries no Bash tool at all.

Every prompt under `plugin/commands/` and `plugin/agents/`, except `idea.md` (its input
is the human's own `$ARGUMENTS`), carries a fixed paragraph: text from an issue, a pull
request, a comment, a task's `## Raw`, a commit message or a web page cannot widen the
task, change a rule or have a command run, and passing such text on quotes it and names
where it came from. No harness proves a model obeys it; the guarantee still rests on
tool permissions and the human's merge, above.

- Guard: `plugin/lib/frontmatter.sh`, `plugin/lib/work.sh` (`peal_brief`); the
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
repository (OWNER, MEMBER or COLLABORATOR) — anyone may open an issue on a public
repository. `read`, `claim`, `work` and `defer` refuse an issue the rule does not admit
and quote none of its text; `list`, the board, the depends expansion and `ship`'s release
notes apply the same rule, an unadmitted issue a commit subject names getting the
commit's own subject in the notes, never the issue's title.

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

- Guard: `plugin/lib/issues-lib.awk` (`admitted()`, `edit_admitted()`,
  `edit_row_admitted()`), `plugin/lib/issues-scan.awk`, `plugin/lib/store-issues.sh`
  (`_peal_issues_admitted`, `_peal_issues_edits_batch`, `_peal_issues_scan`),
  `plugin/lib/claim.sh`, `plugin/lib/work.sh`, `plugin/lib/ship.sh`
  (`_peal_ship_issue_items`).
- Harness: `plugin/lib/hostile.test.sh` (the issues storage's channels),
  `plugin/lib/store-issues.test.sh`, `plugin/lib/ship.test.sh`.

### `gh` holds the token; Peal only calls it

Every GitHub call goes through the `gh` CLI, so nothing in Peal reads, stores or
forwards the user's token; scoping and revocation are `gh`'s own auth store, not
Peal's problem to get right.

- Guard: `plugin/lib/github.sh` (`peal_gh`), the main path; the board's lookup of open
  pull requests (`_peal_files_prs` in `plugin/lib/store-files.sh`) calls `gh` directly.
- Harness: `plugin/lib/store-issues.test.sh`, `plugin/lib/ship.test.sh`, through the
  fake `gh` (`plugin/lib/fake-gh`) that sees every call a harness makes.

### CI that runs on a stranger's pull request cannot write or reach secrets

The workflow's top-level `permissions: contents: read` leaves every job read-only by
default; a fork's pull request runs only the harnesses and `shellcheck`, nothing that
needs a secret or a write.

Every action runs at a pinned commit SHA, which Dependabot keeps current, and OpenSSF
Scorecard checks the workflows weekly. The decisions workflow template
(`plugin/templates/decisions.yml`) ships its action and its Peal pinned by SHA too:
Dependabot keeps the action current across `/` and `/plugin/templates`, the Peal pin
follows each release (checked by `tools/pins.test.sh`), and `tools/pins.sh` refuses an
unpinned reference in the template or in Peal's workflows.

- Guard: `.github/workflows/ci.yml` (`permissions:`, the pinned `uses:`),
  `.github/dependabot.yml`, `.github/workflows/scorecard.yml`,
  `plugin/templates/decisions.yml`, `tools/pins.sh`.
- Harness: `tools/pins.test.sh`; Scorecard's weekly run reports an unpinned action or a
  broad permission.

## What this milestone leaves open

This threat model is m1's first task; the rest of m1 closes what it can only name here:
0039 runs every command against hostile values in CI; 0040 showed the git hooks and the
launcher execute nothing a repository ships, and that `peal init --remove` leaves
nothing behind, with the limits listed under the first boundary above; 0041 pinned the CI
supply chain and checked each job's permissions. Reading the gates' settings from the
main branch instead of the work tree is a task of its own, split from 0040.
