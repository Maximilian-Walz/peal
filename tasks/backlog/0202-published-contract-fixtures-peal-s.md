---
plan: auto
size: M
depends: []
touches: [plugin/lib/apply.test.sh, plugin/lib/store-issues.test.sh, plugin/lib/doctor.sh, .github/workflows/ci.yml, .belfry.yml]
---

# 0202 — Published contract fixtures: Peal's CI checks its .belfry.yml and its commands' outputs against fixtures the control plane publishes

## Intent

No test in either project runs the other: each models the other by hand. Peal's `apply.test.sh` writes "a batch as the control plane's ApplyBatch marshals it" and checks the answer "as ApplyResult reads it", and `store-issues.test.sh` asserts the control plane recognises Peal's claim from a hand-made worktree. These are fixtures, which is right, but they are the only guard against drift, and nothing ever runs them against the real counterpart: that is how `apply_kinds` and the `max_concurrent` rename slipped through unnoticed (Peal's own `.belfry.yml` was invalid for a day). When this is done the control plane publishes a sample `apply` batch, its expected result lines and sample board and milestone lines as files, and Peal's CI copies them into its harness and checks Peal's `.belfry.yml` and each command's output against them.

## Scope

- Wait for the control plane's fixtures (filed on its side as the published contract fixtures issue); then Peal's harness reads them instead of hand-copied shapes, and CI validates `.belfry.yml` against the contract's current rules (the control plane's `belfry check`, when it can run in CI).
- `peal doctor belfry`'s shape checks are the first user of the same fixtures.

## Done when

- `apply.test.sh` and the board tests read the published fixtures; deleting one makes them fail.
- CI fails on a `.belfry.yml` the control plane's checker refuses.

## Raw

> yes, go ahead with all of it and file those proposals.

## Notes

- Boundary review section 1.5 and 4.3. The control plane's side is filed there (B8); this task cannot start before it ships.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
