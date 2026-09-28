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

Built: the commit-msg gate requires the task id only on a task's branch. On any other
named branch (a hotfix, a pin, an ad-hoc job) a subject without `[NNNN]` passes. The
subject grammar, the types and the areas are unchanged, and `checks.commit` still runs.
The test is `_peal_off_task_branch` in `plugin/lib/githooks.sh`. It loads the storage in
a subshell and asks `peal_store_branch_task` whether the branch is a task's:
`task/NNNN-slug` for files (behind `branch-prefix`), `issue/N` for issues. The id is
still required on a detached HEAD, so a rebase keeps the strict rule, and also when the
settings or the storage do not load. `peal commit` still refuses the main branch.
`docs/design.md` now says ad-hoc work goes on a branch of its own, then a pull request.

Decided: the storage defines a task's branch, not a prefix match. The first version
tested `branch-prefix` only. The reviewer found that under the issues storage this let
every commit on `issue/N` pass without an id, and the fix commit corrected it. A side
effect: under the files storage, a branch like `task/foo` (no `NNNN-slug`) counts as no
task's branch, so its commits need no id.

Verification: `plugin/lib/githooks.test.sh` passes 366, 0 failed. It covers the files
cases (`task/0001-some-task` refuses a subject without an id; on `fix/hotfix` one passes,
`checks.commit` runs and can refuse; a malformed subject and an unknown type are refused)
and the issues cases (`issue/7` refuses a subject without an id; `task/0009-x` is no
task's branch there).
