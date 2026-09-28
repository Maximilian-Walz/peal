---
milestone:
plan: required
size:
depends: []
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

Split off from 0084 (char-device-everywhere), which fixed every uncommitted-work check to
filter an untracked character device (and a symlink to one) but explicitly left this case
open. Out of scope for 0084 by the human's own answer during planning.

---

## Outcome

<!-- Written at close, replacing this comment. -->
