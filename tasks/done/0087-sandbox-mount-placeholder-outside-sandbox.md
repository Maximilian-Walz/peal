---
milestone: m2
plan: required
size: S
depends: []
priority: high
touches: [docs/design.md, plugin/lib/common.sh, plugin/lib/common.test.sh, .gitignore]
---

# 0087 — A sandbox mount placeholder looks like real work outside the sandbox

## Intent

peal_status_porcelain and peal_untracked_devices (0084) filter an untracked character
device: a sandbox's /dev/null mounted over a protected path. Seen from outside that
sandbox — a plain host process, a machine that never had the mount active, or the same
worktree once the sandbox is gone — the same path is an ordinary empty regular file, not a
device: `[ -c ]` says no, so nothing filters it. It stays dirty, and the session-end
autosave would commit it as if it were work. Decide whether Peal should do anything about
this case, and if so what.

## Scope

Only paths a sandbox leaves behind as regular files once its mount is gone. Not the
character-device filter itself (0084), which is unaffected.

## Done when

- A decision is written down: either a way to recognize such a placeholder (e.g. a known
  set of paths, an empty-file heuristic, a marker the sandbox setup could leave) that is
  reliable enough not to also swallow a real empty file someone created on purpose, or a
  documented decision that this is out of scope and such a placeholder is just committed
  like any other file.
- If a filter is built, it is covered by a test the way 0084 covers the device filter, and
  `peal_status_porcelain`'s doc comment says so.

## Raw

> Placeholders seen from outside the sandbox (an empty regular file: still dirty, autosave
> would commit it): build as planned, record in the Outcome, file an idea.

(quoted from task 0084's Notes, the human's answer during its planning)

## Notes

Revised 2026-09-28: priority high: goes into Peal's next patch release (daily-use fixes after m1)

Split off from 0084 (char-device-everywhere), which fixed every uncommitted-work check to
filter an untracked character device (and a symlink to one) but explicitly left this case
open. Out of scope for 0084 by the human's own answer during planning.

Planning answers (2026-09-28, human):
- Decision: "the cleanest version", read as (d): out of scope, documented; no filter code.
  Confirmed when agreeing the plan.
- Where: all three: the Outcome, the docs/design.md SessionEnd bullet, and the
  `peal_status_porcelain` comment.
- Peal's own repository gets a root `.gitignore` with the placeholder names, in this task.
- Peal does not write `.git/info/exclude` itself; the docs only suggest it.
- Size S, default model, merge by human review.

## Plan

Decision (d): a placeholder a sandbox leaves as an empty regular file is an ordinary
untracked file to Peal and is committed like any other. Rejected: an empty-file heuristic,
which would swallow `.gitkeep`/`__init__.py`; a sandbox marker, which does not exist, and
Peal never needs Belfry; a known-path filter, which would copy Claude Code's
version-coupled internal deny list and is not generic. The remedy is git's own:
`.gitignore` or the clone-local `.git/info/exclude`. Both cover status, `add -A` and
worktree remove with no Peal code.

Steps:
1. `docs/design.md` (SessionEnd bullet, around :376-381): one or two sentences with the
   decision and the git-exclude remedy.
2. `plugin/lib/common.sh:45-51`, the `peal_status_porcelain` doc comment: say that only the
   character device is filtered; a placeholder seen outside the sandbox is a regular file
   and counts as work, by decision (0087). Comment only; no code change.
3. A root `.gitignore` for Peal's own repository, listing the placeholder names anchored to
   the root (`/.bashrc`, …). Check the list against the 22 paths untracked in 912623c (0057):
   `.bash_profile .bashrc .claude/agents .claude/commands .claude/hooks .claude/launch.json
   .claude/loop.md .claude/output-styles .claude/routines .claude/scheduled_tasks.json
   .claude/settings.local.json .claude/skills .claude/workflows .gitconfig .gitmodules .idea
   .mcp.json .profile .ripgreprc .vscode .zprofile .zshrc`. Before adding a name, make sure
   no tracked file in the repository sits at or under it (`git ls-files`). Tracked paths are
   unaffected by an ignore, but a pattern must not hide a real file someone later adds on
   purpose, e.g. under `.claude/`. A short comment in the file says where the names come
   from.
4. `plugin/lib/common.test.sh` (around :149-196): one case pinning the documented
   behaviour. An empty read-only regular file (e.g. `.mcp.json`, `chmod 444`) in a fixture
   repository without an ignore still counts in `peal_status_porcelain`, and
   `peal_untracked_devices` does not list it.
5. `tools/lint.sh` clean; the common tests pass.

Verification: the decision reads the same in docs/design.md, the comment and the Outcome;
the new test passes; `git status` in this worktree no longer lists the placeholders once
`.gitignore` is in (where any exist on disk).

Touches: docs/design.md, plugin/lib/common.sh, plugin/lib/common.test.sh, .gitignore.

Ranges relied on: plugin/lib/common.sh:45-83, plugin/lib/common.test.sh:1-16 and 149-196,
plugin/lib/session.sh:201-238, plugin/lib/store-files.sh:976-987, docs/design.md:376-381,
tasks/done/0084-char-device-everywhere.md:23-34 and 61-198.

---

## Outcome

Decided, not filtered. A path that a sandbox's `/dev/null` mount leaves behind looks like
an ordinary empty regular file once it is seen from outside that sandbox. Peal treats it as
an untracked file like any other: it counts as work, and the session-end autosave commits
it. The remedy is git's own, `.gitignore` or the clone-local `.git/info/exclude`. Either
covers status, `add -A` and worktree remove without any Peal code. The human chose "the
cleanest version" and confirmed it meant this option.

Rejected alternatives:
- **An empty-file heuristic.** It would also hide `.gitkeep` and `__init__.py`.
- **A marker left by the sandbox.** No such marker exists, and Peal never needs Belfry.
- **A known-path filter (empty + read-only + fixed name list).** It would copy Claude
  Code's internal deny list, which changes between versions, so it is not generic.

Where the decision is written down:
- the SessionEnd bullet in `docs/design.md`,
- the `peal_status_porcelain` doc comment in `plugin/lib/common.sh`,
- this Outcome.

No filter code changed.

Built:
- **A pinning test** in `plugin/lib/common.test.sh`. An empty `.mcp.json` with mode 444
  still shows as `?? .mcp.json` in `peal_status_porcelain`, and `peal_untracked_devices`
  does not list it. The common tests pass: 29 passed, 0 failed.
- **A root `.gitignore` for Peal's own repository**, which the human asked for in this
  task. It holds the 22 names 912623c (0057) had to untrack, each anchored to the root. A
  comment says where they come from. I checked each name with `git ls-files`: no tracked
  file sits at or under any of them. In this worktree, `git status` no longer lists the
  live sandbox mounts.

For the next session:
- Other projects that run Peal in a sandbox need the same ignore entries. The docs suggest
  them, and Peal deliberately does not write them itself (the human's answer).
- `tools/lint.sh` prints "Permission denied" on stderr when it runs inside a sandbox,
  because `find` and `head` hit the live mounts. The exit code stays 0. This was already
  the case before this task.
- Empty directories left behind (`.vscode/`, `.claude/commands/` as directories) are
  harmless, because git never lists an empty directory.

The review found nothing.
