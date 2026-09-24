---
milestone:
plan: skipped
size:
depends: []
---

# NNNN — Title

<!-- Every field is optional; delete what does not apply.
  milestone  a milestone id (a file in the milestones directory); none: unassigned.
  plan       required or skipped: whether the planner runs before the implementer.
  size       S, M or L, the tool-call tiers of the sizes setting; the planner sizes it.
  depends    task ids that must be done first; `milestone` for every other task of this
             task's milestone (a milestone's review task only); `human` for a hold only
             a human lifts, by removing it. Depending on a split task waits for its pieces.
  part-of    the task this one was split from; written by a split only.
  needs      capabilities a worker must have, e.g. [display, gpu].
  model      the implementer's model when not the default, once the plan is agreed.
  priority   urgent, high, normal or low; none is normal. Orders the offer within a
             milestone, never across milestones.
  breaking   true when the task breaks something users rely on: the next release is major.
  release-note  none to leave the task out of the release notes.
  A project's own fields are declared under task.fields in .peal/config.yml. -->

## Intent

One paragraph: what changes when this is done, written for someone with no memory of
any earlier session.

## Scope

The files and areas this task may touch. Work outside them is a new task.

## Done when

Concrete, checkable statements. Prefer "this test asserts X" over "X works".

## Raw

The human's own words, verbatim. Never rewritten.

## Notes

Context and constraints the planner should not have to rediscover.

---

## Outcome

<!-- Written at close, replacing this comment: what was built, what was decided, what was
     found and left (each a new task), and what the next session needs to know. -->
