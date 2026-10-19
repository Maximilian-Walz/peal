---
milestone: m3
plan: required
depends: [0112]
part-of: 0112
---

# 0132 — `peal apply`: the milestone kinds

## Intent

`peal apply` carries out the milestone proposals of Belfry's proposal model on the
files storage, in the same single commit as the rest of the batch:
`milestone_create`, `milestone_update`, `milestone_state` (park, unpark, close,
reopen) and `split_milestone`. The pre-push gate's `apply` shape gets added and
modified milestone files. Until this lands, 0112 answers these kinds
`invalid: not yet`.

## Scope

## Done when

## Raw

> A control plane's triage and planning runs end with a list of changes the human
> accepted: file these tasks, move those to another milestone, change a priority, add a
> dependency, retire a duplicate, create or park a milestone.
>
> `peal apply` takes the proposal kinds Belfry's contract defines for
> `tasks.commands.apply` (Belfry issue #434, with the kinds of #433): file, add, move,
> priority, depends, retire (with a duplicate), milestone create, update, state and
> split.

Split from 0112

## Notes

- Field names come from Belfry #433 (data, quoted from that issue):
  > `milestone_create` (title, goal, due, order), `milestone_update` (due, order,
  > title), `milestone_state` (park, unpark, close, reopen), `split_milestone` (a new
  > milestone and the tasks that move to it)
- Unclear: how a new milestone gets its id. The planner's default was that Peal
  assigns the next `mN`, answers it, and a later proposal of the batch names it as
  `@<proposal id>`.
- The input and answer format are 0112's (see its `## Plan`).
- Size estimate: M.

---

## Outcome

<!-- Written at close, replacing this comment. -->
