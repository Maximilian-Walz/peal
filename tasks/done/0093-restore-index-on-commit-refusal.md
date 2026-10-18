---
milestone: m3
plan: required
size: S
depends: []
touches: [plugin/lib/commit.sh, plugin/lib/commit.test.sh, docs/reference/cli.md]
---

# 0093 — Restore peal commit's own `git add` when the gate refuses

## Intent

`peal commit` runs `git add` (either the named paths, or `-A`) before the commit-msg gate
judges the commit. When the gate refuses (a failing `checks.commit` item, a bad subject),
`peal commit` reports the refusal but leaves everything it staged, staged. A session that
retries after fixing the problem may be fine with that, but a session that gives up or
changes plan is left with a stage it never asked for. Decide whether `peal commit` should
unstage what its own `git add` staged when the gate refuses (mirroring what it already
does for a new backlog file), and if so, build it.

## Scope

`plugin/lib/commit.sh` (`peal_commit`): the gate-refusal path (`git commit` returning
non-zero) and the backlog refusal, which today unstages only the backlog file and leaves
the rest of a `git add -A` staged (widened by the human, 2026-10-18). Not the
nothing-staged refusal (snapshot cleaned up, no restore); not a refusal before `git add`
runs (main branch, detached HEAD, no hooks).

## Done when

- A decision is written down: restore the index to what it held before `peal_commit`'s own
  `git add`, on a gate refusal, or a documented decision that today's behavior (leave it
  staged) is fine.
- If built, covered by a case in `plugin/lib/commit.test.sh` alongside "the gate refuses"
  (something already staged before the call stays staged; what `peal_commit` added is
  gone), and the `peal commit` paragraph of `docs/reference/cli.md` says so (there is no
  `peal commit` bullet in `docs/design.md`).
- The backlog refusal restores the index the same way, covered by a test.

## Raw

> From task 0078's planning (2026-09-28): "Undoing peal commit's own `git add` when the
> gate refuses: not in this task; file it as an idea." Noted while narrowing 0078
> (`peal commit` with paths commits only those paths) to leave this out of scope.

## Notes

Related: 0078, which built the paths-only commit and could not take this on too.

Human's answers at planning (2026-10-18):
- Decision: restore (m3 promises "a refused commit leaves the index as it was").
- Document in `docs/reference/cli.md` only; `docs/design.md` has no `peal commit` bullet.
- Exact restore of the index (byte copy), even if a hook or check staged something itself.
- The backlog refusal restores the index the same way too (in scope now), with a test.
  A backlog file staged before the call therefore stays staged after it.
- Nothing-staged refusal: clean the snapshot up, no restore.
- `plugin/agents/implementer.md` unchanged.
- Message: keep "the commit was refused (above)", append "the index is as it was"; exit 1.
- A failed restore: exit 1, keep the snapshot and name its path.
- No index file before the call: a refusal removes the index. No split-index handling.

## Plan

Approach: just before `git add` (`plugin/lib/commit.sh:71-75`), copy the index file
(`git rev-parse --git-path index`, which handles worktrees and `GIT_INDEX_FILE`) to a
`mktemp` file; remember when there was no index file. On the gate refusal
(`commit.sh:102-105`) and the backlog refusal (`commit.sh:84-89`, replacing its per-file
unstage), put it back atomically (copy to a sibling temp file, `mv` over the index; or
remove the index if there was none), report and return 1. Remove the snapshot on every
exit after it is taken (success, backlog, nothing staged, gate); no `trap ... RETURN`
that would leak into the sourcing shell. A failed restore says so, names the snapshot
path, keeps the file and returns 1. Gate refusal message: "commit: the commit was refused
(above); nothing was committed, the index is as it was". Update the header comment
(`commit.sh:6-12`).

Rejected: `write-tree`/`read-tree` (loses intent-to-add entries, skip-worktree bits, stat
cache; fails on unmerged entries); per-path `git reset` (drops the caller's own staged
content of a path edited after staging).

Files: `plugin/lib/commit.sh`, `plugin/lib/commit.test.sh`, `docs/reference/cli.md`
(`peal commit` paragraph, lines 200-205).

Verification, in `plugin/lib/commit.test.sh` replacing "the gate refuses" (lines 65-70,
dropping the `git reset -q` at line 70) and adjusting the backlog-refusal case:
1. Paths mode: `p` staged as "p1", then edited on disk to "p2"; new `e`;
   `peal commit "no grammar" e` exits 1 with the refusal text; HEAD unchanged; `git diff
   --cached --name-only` is exactly `p`; `git show :p` is "p1"; `e` is `??`.
2. Everything mode (no paths): same setup and checks.
3. Optionally a refusal by a failing `checks.commit` item.
4. Backlog refusal with `-A`: other files `git add -A` staged are unstaged again; a path
   staged before the call stays staged.
5. Existing cases pass. Run `bash plugin/lib/commit.test.sh` and shellcheck.

Ranges: tasks/doing/0093-restore-index-on-commit-refusal.md:1-43,
plugin/lib/commit.sh:1-107, plugin/lib/commit.test.sh:1-142, plugin/lib/test-lib.sh:43-60,
docs/milestones/m3.md:1-27, docs/reference/cli.md:200-205, docs/design.md:425-457,
plugin/agents/implementer.md:23-28, tasks/backlog/0102-peal-commit-takes-m-and.md:1-41
(same function; a textual merge conflict is possible).

Touches: plugin/lib/commit.sh, plugin/lib/commit.test.sh, docs/reference/cli.md.

---

## Outcome

Built: when a refusal follows `peal commit`'s own `git add`, the index is put back the way
it was before the call. `peal_commit` (`plugin/lib/commit.sh`) takes a byte copy of the
index file (`git rev-parse --git-path index`, so worktrees and `GIT_INDEX_FILE` work)
right before `git add`. `_peal_commit_restore` puts it back atomically (copy to a sibling,
then `mv`). If there was no index file before the call, it removes the index instead. Two
refusals restore:
- the gate refusal, exit 1, message "…nothing was committed, the index is as it was";
- the backlog refusal, exit 2 as before, which now restores the whole index instead of
  unstaging only the backlog file.

The nothing-staged refusal and a failing `git add` only remove the snapshot. If the
restore itself fails, `peal commit` returns 1, keeps the snapshot and names its path.
`docs/reference/cli.md` says all this in the `peal commit` paragraph.

Decided, with the human at planning:
- Restore rather than leave the stage, as m3's criterion promises.
- An exact byte-for-byte restore. Anything a hook or check staged during the refused
  commit is undone too.
- `write-tree`/`read-tree` was rejected because it loses intent-to-add entries,
  skip-worktree bits and the stat cache.
- Unstaging each path was rejected because it would drop the caller's own staged content
  for a path edited after staging.
- The backlog refusal was brought into scope. So a backlog file the caller staged before
  the call now stays staged; the "backlog named" test changed to say so.

Tests (`plugin/lib/commit.test.sh`):
- the gate refusal, in paths mode and in everything mode: a path staged as "p1" and edited
  to "p2" on disk stays staged at "p1", and the added file is untracked again;
- the backlog refusal: the added file is unstaged again, a path staged before the call
  stays staged.

All 135 pass, and shellcheck is clean.

Not tested: a refusal by a failing `checks.commit` item (it takes the same commit-msg
failure path as a bad subject), and a failed restore.

The review found that a failing `git add` left the snapshot in `$TMPDIR`. Fixed in its own
commit.

For the next session: 0102 changes the same function (argument parsing), so expect a
textual merge conflict there.
