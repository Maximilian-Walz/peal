---
milestone:
plan: required
size:
depends: []
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

`plugin/lib/commit.sh` (`peal_commit`), the gate-refusal path only (`git commit` returning
non-zero). Not the backlog refusal, which already unstages; not a refusal before `git add`
runs (main branch, detached HEAD, no hooks).

## Done when

- A decision is written down: restore the index to what it held before `peal_commit`'s own
  `git add`, on a gate refusal, or a documented decision that today's behavior (leave it
  staged) is fine.
- If built, covered by a case in `plugin/lib/commit.test.sh` alongside "the gate refuses"
  (something already staged before the call stays staged; what `peal_commit` added is
  gone), and the design doc's `peal commit` bullet says so.

## Raw

> From task 0078's planning (2026-09-28): "Undoing peal commit's own `git add` when the
> gate refuses: not in this task; file it as an idea." Noted while narrowing 0078
> (`peal commit` with paths commits only those paths) to leave this out of scope.

## Notes

Related: 0078, which built the paths-only commit and could not take this on too.
