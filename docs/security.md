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

- Guard: `plugin/templates/launcher`.
- Harness: `plugin/templates/launcher.test.sh`.

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
retiring a task, a milestone's state, the decisions index — whose diff has exactly the
shape its subject claims. Rewriting or deleting main is refused outright.

- Guard: `plugin/lib/githooks.sh` (`_peal_pre_push`).
- Harness: `plugin/lib/githooks.test.sh`.

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

- Guard: `plugin/lib/frontmatter.sh`, `plugin/lib/work.sh` (`peal_brief`); the
  review-before-merge principle above.
- Harness: `plugin/lib/frontmatter.test.sh`, `plugin/lib/work.test.sh`. A harness that
  runs every command with hostile values throughout is task 0039.

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

- Guard: `.github/workflows/ci.yml` (`permissions:`).
- Harness: none yet. Pinning every action by its SHA and setting each job's own minimal
  permissions, so this holds even as the workflow grows, is task 0041.

## What this milestone leaves open

This threat model is m1's first task; the rest of m1 closes what it can only name here:
0039 runs every command against hostile values in CI; 0040 shows the git hooks and the
launcher execute nothing a repository ships, and that `peal init --remove` leaves
nothing behind; 0041 pins the CI supply chain and tightens each job's permissions.
