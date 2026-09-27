---
milestone:
plan: skipped
size: S
depends: []
touches: [plugin/lib/ship.sh, plugin/lib/ship.test.sh]
---

# 0080 — A rerun of `peal ship bump` finds its own open pull request

## Intent

On a protected main, `peal ship bump VERSION` opens a pull request `chore(release): <tag>` and waits for it within a budget; spent, it stops with status 3 and says to run it again once it merged. Run again before the merge, it builds a second pull request with the same change. When this is done, a rerun finds the open `peal/main-write-*` pull request titled `chore(release): <tag>` and waits for that one instead of opening another.

## Scope

- `peal ship bump`: before building, look for an open pull request of Peal's main-write branches whose title is this tag's bump; wait for it (the same budget) rather than open a new one.
- The harness: a rerun during the budget-spent case opens no second pull request.

## Done when

- `plugin/lib/ship.test.sh` reruns the bump while its pull request is open and finds one pull request in the fake GitHub.

## Raw

Found while building 0066: the release command tells the human to rerun once merged, but nothing stops an early rerun from duplicating the pull request.
