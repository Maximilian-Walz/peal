---
plan: required
priority: low
touches: [plugin/lib/commit.test.sh]
---

# 0209 — commit.test.sh covers a checks.commit refusal and a failed index restore

## Intent

Task 0093 made `peal commit` restore the index after it refuses a commit. Two of those paths have no test yet:

1. A refusal caused by a failing `checks.commit` item. The index should be put back the way it was before the commit started.
2. A restore that fails itself. `peal commit` should exit 1, keep the index snapshot and name its path.

Add a test case for each to `plugin/lib/commit.test.sh`. This task adds tests only. If a test shows the behaviour is wrong, that is an open question for the planner, not part of this task's scope.

## Scope

## Done when

## Raw

> commit.test.sh covers a checks.commit refusal and a failed index restore
>
> ## Intent
>
> 0093 made `peal commit` put the index back after a refusal. Two paths are still untested: a refusal caused by a failing `checks.commit` item, and a restore that itself fails (exit 1, snapshot kept, path named). Add tests for both.
>
> ## Done when
>
> - `plugin/lib/commit.test.sh` has a case for each path.
>
> ## Notes
>
> - From the m3 milestone review (0093's Outcome).

## Notes

- From the m3 milestone review (0093's Outcome).
- Open question: how to make the restore fail reliably in a test (for example a read-only index, or a stubbed restore step) without changing `plugin/lib/commit.sh` just to make it testable.
- `docs/reference/configuration.md` describes `checks.commit`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
