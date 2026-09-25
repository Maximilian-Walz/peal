---
milestone: m2
plan: skipped
depends: []
---

# 0072 — Commits outside a task need no task id

## Intent

The commit-msg gate refuses every commit whose subject lacks a task id, except `wip` and
`chore(peal)`. Work that is not a task (a hotfix, a release commit, a dependency pin, an
ad-hoc job a control plane runs) is refused in a Peal project, though there is no task
to name. When this is done, the task id is required on task branches only: on a branch
outside `branch-prefix`, a subject without `[NNNN]` passes the gate, and `checks.commit`
still runs on it as on any other commit.

## Scope

- The commit-msg gate: the id is optional when the current branch does not start with
  `branch-prefix`; the subject grammar and the checks stay the same.
- `peal commit` keeps refusing the main branch; the docs say how ad-hoc work is committed
  (a branch of its own, then a pull request).

## Done when

- Harnesses: on `task/0001-x` a subject without an id is refused; on `fix/hotfix` it passes
  and `checks.commit` runs; a malformed subject is refused on both.

## Raw

From an infrastructure repository evaluating Peal: dependency bumps, hotfixes and pins
run as ad-hoc jobs there and would all be refused.

## Notes


---

## Outcome
