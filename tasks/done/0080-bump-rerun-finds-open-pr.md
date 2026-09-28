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

---

## Outcome

Built: `peal ship bump` run again before its release pull request merged now finds that pull request and waits for it (same budget, same status 3 when spent) instead of opening a second one with the same change.

- `peal_push_main` (plugin/lib/main-write.sh) takes an optional third argument, REUSE, a subject. On the pull-request route it first looks (`_peal_mw_find_reuse`) for an open pull request into main whose branch starts with `peal/main-write-` and whose title is that subject. Found, it is managed exactly like one just opened: the tail of `_peal_mw_pr` (taken check, mergeable check, auto-merge or self-merge) was pulled out into `_peal_mw_pr_manage`, shared by both paths. Other callers (store-files, decisions) pass no REUSE and behave as before.
- `peal_ship_bump` passes `chore(release): <tag>` as REUSE; the subject is fixed for a tag, so it is known before building.
- Only a pull request whose branch is in the repository itself is reused, never a fork's (the rule `_peal_mw_rivals` and design.md's Races already hold), and only when the branch fetched from the remote still sits at the sha the pull request names. The review caught the first version missing this: a stranger's fork pull request with a matching branch name and the next release's title would have had auto-merge enabled with the maintainer's credentials, or been dropped along with the project's own same-named branch. Otherwise a new pull request is built as before.
- plugin/lib/ship.test.sh reruns the bump while #2 is open: one open pull request, no extra POST, the "is open already; waiting for it" line. A fork pull request carrying the bump title is ignored and left alone. `fake-gh` now reports the real head sha of a pull request it opens, which the sha check reads.
- docs/design.md's `peal ship bump` entry says a rerun before the merge waits for the open pull request.

The task's `touches` named only ship.sh and ship.test.sh; most of the change is in main-write.sh (and fake-gh, design.md), because the waiting machinery lives there and duplicating it in ship.sh would have split one code path in two.

For the next session: REUSE is generic, but only `ship bump` uses it. Other main-write callers could opt in if the same duplicate-pull-request problem turns up for them; not investigated here.

### Reviewer findings not acted on

- `touches` does not list main-write.sh: a scheduling hint only (design.md); noted above rather than rewritten after the fact.
