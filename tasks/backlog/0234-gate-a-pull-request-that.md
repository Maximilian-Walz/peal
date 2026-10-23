---
milestone: m6
plan: required
priority: high
touches: [plugin/lib/merge-gate.sh, plugin/lib/merge-gate.test.sh, docs/security.md]
---

# 0234 — Gate a pull request that rewrites the plan of a task holding `merge: auto`

## Intent

The merge gate of 0161 stops a pull request from bringing in a `merge` key, but it does not look at the rest of a task that already holds `merge: auto` on main. A task-files pull request merges by itself, so it can rewrite the `## Plan` or `## Scope` the human agreed `merge: auto` for; the task's own pull request then merges by itself, under consent given for a different plan. The task closes that route: the gate either refuses such a rewrite or drops `merge` along with it, and it also refuses a second file that carries an id already holding an agreed `merge` (the gate matches agreed consent by id alone, and only `peal check` notices duplicates today). If some part of the route stays open, `docs/security.md` says why.

## Scope

## Done when

## Raw

> Gate a pull request that rewrites the plan of a task holding `merge: auto`
>
> ## Intent
>
> The merge gate of 0161 refuses a `merge` key that arrives through a pull request, but lets a pull request edit the rest of a task that already holds `merge: auto` on main. A task-files pull request, which merges by itself, can rewrite the `## Plan` or `## Scope` the human agreed `merge: auto` for; the task's own pull request then merges by itself under the agreed plan's name. Once this is done that route is closed, or docs/security.md says why it stays open.
>
> ## Scope
>
> - `plugin/lib/merge-gate.sh`: refuse a changed `## Plan`, `## Scope` or `## Done when` on a task whose `merge` is set (or any body change), or drop `merge` with the change, since the consent was for the old plan.
> - The gate also refuses a second file carrying an already agreed id (today it matches an agreed `merge` by id only; `peal check` reports duplicates, the gate does not).
> - `docs/security.md`: the "A changed plan under an agreed `merge`" limit closed, with the tests.
>
> ## Done when
>
> - Tests in `merge-gate.test.sh`: a pull request that changes `## Plan` of a `merge: auto` task fails the gate; a duplicate-id file with an agreed id fails it.
> - `docs/security.md` updated.
>
> ## Raw
>
> > Should be fixed: a gap of the same kind is not documented. The gate stops a task-files pull request from *adding* `merge`. It does not stop one from *rewriting the Scope or Plan* of a task that already has `merge: auto` [...] Fix: add a limit bullet, and queue an idea for a gate that, for example, refuses a changed `## Plan` or `## Scope` on a task whose `merge` is set.
>
> (The reviewer of 0161, its finding 1.)
>
> ## Notes
>
> - plan: required. Open: which sections count, and refuse vs. drop `merge`.
> - 0177 (merged) moved where consent is recorded; check how that changes this gap's shape first. 0180 covers the direct-push route.

## Notes

- Open: which sections count as the agreed plan (`## Plan`, `## Scope`, `## Done when`, or any body change).
- Open: refuse the pull request, or drop `merge` with the change (the consent was for the old plan).
- First check how 0177 (merged: auto is recorded outside the task's branch and never read back from a claim copy) changes this gap's shape; the fix may now belong where consent is recorded rather than in the task file's body.
- 0180 covers the direct-push route; this task is the pull-request route only.
- `docs/security.md`, the limit "A changed plan under an agreed `merge`", is the one to close or update.
- `docs/design.md` on the merge gate and consent bears on the choice.

---

## Outcome

<!-- Written at close, replacing this comment. -->
