---
milestone: m6
plan: required
touches: [plugin/lib/merge-gate.sh]
---

# 0255 — The pull-request gate refuses dropping `origin: outsider`

## Intent

The pull-request merge gate never looks at `origin: outsider`. A task-files pull request, which merges by itself, can drop that field from any task that holds no `merge`, turning an outsider's task into a writer's one whose job then runs unattended. The pre-push gate refuses this for direct pushes (0180); the pull-request route stays open. Close it in the merge gate, or say in `docs/security.md` why it stays open.

## Scope

## Done when

## Raw

> Finding, not part of this task. The pull-request gate never checks `origin: outsider`. The pre-push gate refuses dropping it for direct pushes (0180), but a task-files pull request can drop it from any task without `merge`. That turns an outsider's task into a writer's, whose job then runs unattended.

(The planner of 0234.)

## Notes

- Since 0234 a task holding an agreed `merge` cannot change at all through a task-files pull request; tasks without `merge` are the open part.
- `docs/security.md` (the merge gate, outsider origin) and 0180's pre-push rule bear on it.

---

## Outcome

<!-- Written at close, replacing this comment. -->
