---
milestone: m6
plan: required
priority: high
touches: [plugin/lib/merge-gate.sh, plugin/lib/merge-gate.test.sh, docs/security.md, docs/reference/cli.md, plugin/bin/peal]
size: S
---

# 0234 — Gate a pull request that rewrites the plan of a task holding `merge: auto`

## Intent

The merge gate of 0161 stops a pull request from bringing in a `merge` key, but it does not look at the rest of a task that already holds `merge: auto` on main. A task-files pull request merges by itself, so it can rewrite the `## Plan` or `## Scope` the human agreed `merge: auto` for; the task's own pull request then merges by itself, under consent given for a different plan. The task closes that route: the gate either refuses such a rewrite or drops `merge` along with it, and it also refuses a second file that carries an id already holding an agreed `merge` (the gate matches agreed consent by id alone, and only `peal check` notices duplicates today). If some part of the route stays open, `docs/security.md` says why.

## Scope

- `plugin/lib/merge-gate.sh`: refuse a pull request that changes any byte of a backlog/doing task while keeping its agreed `merge` (a move or rename with the same blob passes; dropping `merge` with the change passes, as today).
- The gate refuses a new or changed backlog/doing file whose id is held by more than one file at HEAD when any of them holds `merge`.
- `docs/security.md`, `docs/reference/cli.md`, `plugin/bin/peal` usage text: describe the two new refusals; the limit "A changed plan under an agreed `merge`" closed.

## Done when

- Tests in `merge-gate.test.sh`: a pull request that changes `## Plan` of a `merge: auto` task fails the gate; a duplicate-id file with an agreed id fails it; unchanged moves/renames and a change that drops `merge` pass.
- `docs/security.md` updated; `merge-gate.test.sh`, `hostile.test.sh` and `tools/lint.sh` green.

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
- 2026-10-26, human (plan): any byte change to a task keeping an agreed `merge` fails the gate (not only the agreed sections); a duplicate id is refused only when `merge` is involved, plain duplicates stay with `peal check`; the implementer may update `docs/reference/cli.md` and `plugin/bin/peal`'s usage text (and one clause of `docs/design.md` if it reads wrong). Refuse vs. drop: the same in a gate, which cannot edit a pull request; the refusal names both ways out.
- 0177's shape: under a control plane the consent lives in its record and a main-side rewrite never reaches the claim; without one the field on main is the only record, so the gate is the place.
- Side finding, filed as an idea: the pull-request gate never checks `origin: outsider`; a task-files pull request can drop it from a task without `merge`.

## Plan

In `peal_merge_gate` (`plugin/lib/merge-gate.sh:98-127`), for each new or changed HEAD file under backlog/ or doing/:

- a. Duplicate ids, before the "no merge, continue" exit (line 111): count HEAD's backlog/doing files of this id from `$hlist`; when more than one and this file or another of that id holds `merge` (`_peal_mg_merge`), refuse: `merge-gate: refused: PATH: another task file holds id NNNN, which holds merge`. An unchanged duplicate BASE already had stays skipped by the same-blob check (line 104).
- b. Rewrites, where the BASE match is found (lines 118-122): the matching BASE file must also have the same blob as HEAD's (`${bline#*$'\t'}`). A move or rename keeps the blob and passes; any change keeping `merge` is refused: `merge-gate: refused: PATH: changes a task whose merge the human agreed; drop merge with the change, or a human merges it`. "sets merge" stays for a merge that arrives.
- c. The header comment (lines 1-11) and the closing line follow.
- Docs: `docs/security.md` auto-merge tiers paragraph (540-551) gains both refusals; the limit "A changed plan under an agreed `merge`" (586-591) rewritten as closed by 0234 with its tests; harness line 566 if needed. `docs/reference/cli.md:94-103` and `plugin/bin/peal:123-130` usage text follow; `docs/design.md:474-477` one clause only if it reads wrong.

Verification, in `merge-gate.test.sh` with fixtures 0002 (backlog, merge: auto) and 0005 (doing, merge: auto), under every awk:
- refused: `## Plan` added/changed on 0002; `## Scope` changed on 0005; a frontmatter change on 0002 with merge kept; 0002 renamed with a body change; 0002 moved to doing with a body change; a new `backlog/0002-other.md` with `merge`; and without `merge`.
- passed: 0002 moved to doing unchanged; renamed unchanged; Plan changed with `merge` dropped; the close shape; a body edit to 0001 (no merge).
- the existing "an edit to a task with merge" case (lines 116-117) moves to the refused side, explicitly.
- `bash plugin/lib/merge-gate.test.sh`, `bash plugin/lib/hostile.test.sh` (lines 403, 707-709), `tools/lint.sh` all green.

Ranges: tasks/done/0177-merge-auto-is-the-human.md:43-61,79-97; plugin/lib/merge-gate.sh:1-135; plugin/lib/merge-gate.awk:1-27; plugin/lib/merge-gate.test.sh:1-155; plugin/lib/store-files.sh:1024-1036; plugin/bin/peal:123-130; docs/security.md:165-186,236-263,522-591; docs/reference/cli.md:86-108; docs/reference/configuration.md:27; docs/design.md:460-477; docs/milestones/m6.md:23-35.

---

## Outcome

`peal merge-gate` now refuses two more shapes of a task-files pull request, closing the route by which `merge: auto` could outlive the plan it was agreed for:

- **A changed task under an agreed `merge`**: a backlog/doing file that keeps the `merge` value main holds for its id must now also keep main's blob. A move or rename with no content change (a claim, a slug change) passes; any other byte change (Plan, Scope, Intent, Raw, Notes, frontmatter) is refused with "changes a task whose merge the human agreed; drop merge with the change, or a human merges it". Dropping `merge` in the same pull request passes, as before. In a gate, "refuse" and "drop `merge`" are the same thing: a gate cannot edit the pull request, so it refuses and names both ways out.
- **A second file of an id holding `merge`**: when HEAD holds more than one backlog/doing file of an id and any of them holds `merge` (a bad frontmatter counts as holding it, so it fails closed), the file the pull request wrote is refused. A duplicate main already had stays unjudged by the same-blob skip. Plain duplicates without `merge` stay with `peal check`, as the human chose.

The human chose the whole-file rule over a section-only compare: no section parser in a security gate, and Raw, Notes and frontmatter (which steer the planner and the claim) are covered too. The cost: on `main-writes: pr`, a comment, revise or milestone change on a task holding `merge` needs a human merge.

0177's shape: under a control plane, consent lives in its record and a rewrite on main never reaches a claim's copy; without one, main's field is the only record, so the gate is where this belongs.

Tests: `merge-gate.test.sh` (174 passed under every awk) gains the refused cases (Plan added and changed on 0002, Scope changed on 0005 in doing, a frontmatter change with merge kept, rename and move with a body change, a second 0002 file with and without merge) and passed cases (unchanged move and rename, a Plan change with merge dropped). The old "an edit to a task with merge" case moved to the refused side. `hostile.test.sh` (2723 passed) and `tools/lint.sh` green. Docs: `docs/security.md` (auto-merge tiers, the limit rewritten as closed by 0234), `docs/reference/cli.md`, the usage text in `plugin/bin/peal`, and the header and step name of `plugin/templates/merge-gate.yml` (a reviewer's finding, fixed). `docs/design.md`'s clause still reads right and was left.

Left: the comment above the merge-gate step in `.github/workflows/ci.yml` still says only "no task file gains a merge key"; it is a comment in a human-merged path and was not worth widening this pull request for. Filed: the pull-request gate never checks `origin: outsider`, so a task-files pull request can drop it from a task without `merge` (the planner's finding).

Next session: `hostile.test.sh` takes about 12 minutes; run it in the background.
