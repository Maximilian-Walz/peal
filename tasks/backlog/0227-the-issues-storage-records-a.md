---
milestone: m9
plan: auto
size: S
depends: [0203]
priority: high
touches: [plugin/lib/store-issues.sh, plugin/lib/store-issues.test.sh, plugin/commands/work.md, docs/guides/belfry.md]
---

# 0227 — The issues storage records a task's plan and agreed fields through the control plane's task_record when it is offered

## Intent

Under the control plane a session has no gh login once its switch is on (its #671). 0176 found no control-plane tool could stand in for the issues storage's writes, and 0203 makes them refuse with the reason: `peal record` on the issues storage edits the issue body with `gh api PATCH` (`plugin/lib/store-issues.sh:498, 859`) and the labels at :633-636. The control plane adds `task_record` (belfry#727): for the job's own task only, it sets the `## Plan` and `## Notes` sections and the `size:`, `touches:` and `model:` labels, and refuses `merge`, `origin`, `owner` and any milestone. When this is done `peal work` and `peal record` on the issues storage go through that tool when it is offered, `peal_store_record` refuses only when neither gh nor the tool is there, and the control plane can hide the login.

## Scope

- `plugin/lib/store-issues.sh`: `_peal_issues_record` (and the field writes the plan agrees) through `task_record` when the session offers it, as `close` uses `wait_ci` and `pr_create`; `gh` elsewhere.
- `plugin/commands/work.md`: the step that records the plan names the tool under the control plane.
- `docs/guides/belfry.md` and the 0203 inventory: the row moves from "unavailable" to "through task_record".

## Done when

- A harness with a fake `task_record` and a `gh` that fails authentication records a plan and size on an issues-storage task; without either it refuses with 0203's reason.
- `work.md` and `commands.test.sh` carry the branch; the inventory test passes with the row changed.

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Waits for the control plane's belfry#727 deployed; its #671 (HideGhLogin on) waits for this task's release. 0203 is the stopgap this replaces for `record`.
- Security: the gh boundary (`docs/security.md`): one fewer gh write; the tool refuses the state fields, so "the merge is the human's" holds.

---

## Outcome

<!-- Written at close, replacing this comment. -->
