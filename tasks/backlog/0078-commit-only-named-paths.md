---
plan: required
touches: [plugin/lib/commit.sh]
priority: high
---

# 0078 — `peal commit` with paths commits only those paths

## Intent

`peal commit "<msg>" <paths>` stages the named paths with `git add -- "$@"` and then commits the whole index, so whatever was already staged goes into the commit too. In 0057 about 22 sandbox placeholder files rode along that way, and it took a `git rm --cached` commit to take them out. With paths given, the commit should hold only those paths (`git commit -- <paths>`), or refuse while other paths are staged.

## Scope

## Done when

## Raw

> From task 0057, which could not file it itself: the sandbox blocks the push to main. peal commit with paths commits only those paths. `peal commit "<msg>" <paths>` stages the named paths with `git add -- "$@"` but then commits the whole index, so anything already staged goes into the commit too. In 0057 about 22 sandbox placeholder files rode along that way, and it took a `git rm --cached` commit to take them out. When paths are given, commit only those paths (`git commit -- <paths>`), or refuse while other paths are staged.

## Notes

Revised 2026-09-28: priority high: goes into Peal's next patch release (daily-use fixes after m1)

- Open: only the named paths, or a refusal while others are staged?
- Open: what `peal commit` without paths should do; it commits the whole index today.
- Related: 0075 (sandbox placeholder files no longer count as uncommitted work).

---

## Outcome

<!-- Written at close, replacing this comment. -->
