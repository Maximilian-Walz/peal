---
milestone: m9
plan: auto
size: S
depends: []
touches: [plugin/commands/defer.md, docs/guides/belfry.md]
---

# 0223 — /peal:defer ends by calling the control plane's task_release or task_defer when present, so one record exists

## Intent

Under the control plane there are three ways a session gives a task back and they leave three records (its #705): Peal's `/peal:defer` edits the backlog file and deletes the claim, which the control plane does not see, so it counts the job as friction and never offers the task again although the board shows it free; the control plane's `task_defer` loses the session's notes; `task_release` tells the session to give the claim back the project's way, which `/peal:defer` refuses when anything was built. When this is done `/peal:defer` ends by calling the control plane's tool when it is present, as `close` does with `wait_ci`, with an `until` when the wait is another project's task or release, and a task that was built keeps its branch.

## Scope

- `plugin/commands/defer.md`: after Peal's own defer, call `task_defer` (waits for a task) or `task_release` (nothing waits; `until` for another project's task, release or pull request) when the tool is listed; the tool's reply is the end of the session.
- The built-something case: `/peal:defer` keeps the branch and says so instead of refusing, when the control plane asked for the give-back.
- `docs/guides/belfry.md` describes the one path.

## Done when

- `commands.test.sh` asserts the call and its order.
- A defer under the control plane leaves the task free or blocked on the board and the job not counted as friction (checked once live, noted in the Outcome).

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Waits for the control plane's #705 and its belfry#716 (`until`). Plan after both are decided.
- Security: none beyond "the merge is the human's": a kept branch opens no pull request.

---

## Outcome

<!-- Written at close, replacing this comment. -->
