---
milestone: m3
plan: required
size: S
touches: [plugin/lib/apply.sh, plugin/lib/apply.test.sh, plugin/lib/hostile.test.sh, plugin/lib/task-text.sh, docs/reference/cli.md, docs/reference/tasks.md, docs/security.md]
---

# 0153 — `peal apply` takes a `vouch` proposal that drops a task's `origin: outsider`

## Intent

Belfry is adding a human-only "Vouch for this text" action (Maximilian-Walz/belfry#588): the human reads an outsider's task and says its text is to count as a writer's from then on. On a project with Belfry's `tasks.commands.apply`, Belfry carries it out as one `vouch` proposal. `peal apply` can set `origin: outsider` today (through `file`, and through `add` with `origin: outsider`), but no kind clears it. Add a `vouch` kind: field `task` (plus the usual `why`). It drops `origin` from the task's frontmatter and adds a dated line under its Notes saying who vouched and why, in the batch's one commit like every other kind.

## Scope

- `plugin/lib/apply.sh`: a `vouch` kind (field `task`, plus `why`) in the kind list, the header comment, `_pa_static` and `_pa_item`.
- `plugin/lib/task-text.sh`: a helper that adds a `## Notes` section holding the line when the task has none.
- `plugin/lib/apply.test.sh`, `plugin/lib/hostile.test.sh`: coverage.
- `docs/reference/cli.md`, `docs/reference/tasks.md` (the `origin` row), `docs/security.md` (the trust boundary).

## Done when

- `apply.test.sh` passes under every awk (`for_each_awk`), no existing expectation edited, with a `vouch` case covering: success (answer `{"id": "v", "done": true, "outcome": "task 0005: vouched for, a writer's now", "task": "0005"}`, one commit `docs(tasks): apply 1 proposal` with body line `- v (vouch 0005): <why>`, `origin` absent, the line `<today>: Vouched for by a writer: <why>` directly under `## Notes`, the earlier outsider note byte-identical, `peal check` clean); a `why` with a newline and a `## ` start ends as one note line; no `why` ends "Vouched for by a writer."; a task without `## Notes` gains the section; a vouch on a writer's task is done with "already a writer's" and main unchanged; `add` with `origin: outsider` then `vouch` in one batch ends with no origin and both lines; and invalids leaving main unchanged: a claimed task, no such task, an unknown field, an `@ref` task, `origin: outsider` on the vouch, no `task`.
- `hostile.test.sh` passes serially and in four shards with its try count unchanged.
- `tools/lint.sh` clean; `tools/docs.test.sh` passes.

## Raw

> Belfry will let the human vouch for an outsider's task (belfry#588). On a commands project it sends a vouch proposal through tasks.commands.apply; peal apply needs a vouch kind that drops origin: outsider from the task file and records it.

## Notes

- Checks as for the other kinds: the task is in the backlog, nobody claimed it, and the batch leaves valid frontmatter. Vouching for a task without `origin` is refused as invalid, or answered done with "already a writer's" (the planner decides which).
- A Notes line from outside stays quoted as data, as it is. Vouching changes the task's origin, not the history of its text.
- `docs/reference/cli.md` ("peal apply") and the kind list at the top of `plugin/lib/apply.sh` name it. `apply.test.sh` covers it, and `hostile.test.sh` feeds `task` and `why` the hostile values as for the other kinds (mind 0152: keep those tries fast).
- Belfry offers Vouch on a commands project only with `apply`, so no single command is needed.

- 2026-10-21, the human's answers at planning: a vouch for a task without `origin` is answered done ("task NNNN: already a writer's") and writes nothing; the Notes line says a fixed "a writer" (no `by` field); a task with no `## Notes` gains the section with the line; a vouch naming `@<id>` or carrying `origin: outsider` is refused; vouch is folded into the existing hostile tries (try count unchanged); the short line `YYYY-MM-DD: Vouched for by a writer: <why>`, earlier Notes untouched, no hint; docs scope includes `docs/reference/tasks.md` and `docs/security.md`.

## Plan

Approach, all following the `add` and `retire` pattern in `plugin/lib/apply.sh`:
- Add `vouch` to `PEAL_APPLY_KINDS` (apply.sh:63) and describe it in the header comment (apply.sh:13-45).
- `_pa_static`: `vouch) allowed="task origin" required="task"` in the case at apply.sh:325-342; `task` through `_pa_task_ref ... earlier` (apply.sh:393); refuse `@<id>` like `retire` (apply.sh:396) with "vouches for a task the batch files"; refuse `origin: outsider` with "a vouch is a writer's, not an outsider's" (`writer`, `""` or absent accepted).
- `_pa_item`: a `vouch)` branch next to `add` (apply.sh:596-605) on the compose copy: if `peal_fm_get origin` is `outsider`, `peal_fm_unset origin` and add the note as `_peal_files_rewrite_comment` does (store-files.sh:874-883), detail `task NNNN: vouched for, a writer's now`; otherwise change nothing, detail `task NNNN: already a writer's` (a batch of only that writes nothing through the existing return-4 path, apply.sh:1051, 1201). Set `res.$i.task` and `.last` as other task kinds do.
- The note: `$(date -u +%Y-%m-%d): Vouched for by a writer: <why>`, or `...: Vouched for by a writer.` with no `why`; newline, CR and tab in `why` become spaces (as apply.sh:1061).
- No `## Notes`: a helper next to `peal_text_add_note` in `plugin/lib/task-text.sh` inserts `## Notes` with the line before the `---` above `## Outcome`, or at the end.
- Order within a batch is the compose order; no special handling.
- Docs: a `vouch` row in cli.md's table (cli.md:323-334) and the sentence at cli.md:318-319; tasks.md:52's `origin` row names `vouch` as the one way the mark is removed; security.md's apply section (183-222) and origin paragraph (161-164) say a vouch drops the mark, Peal cannot verify a human sent it and relies on the caller offering it to the human only, and a vouch carrying `origin: outsider` is refused.

Verification: as in Done when. Hostile: the escaped-values try (hostile.test.sh:464-466) has the `add` on 0002 gain `"origin": "outsider"` followed by `{"id": "v", "kind": "vouch", "task": "0002", "why": <hostile>}`; the hostile `task` joins the escaped split try (476-477) and the raw split `each_input` (482) as an extra vouch proposal.

Ranges: tasks/doing/0153-peal-apply-takes-a-vouch.md:1-31; plugin/lib/apply.sh:1-63, 303-431, 506-553, 555-660, 1031-1076, 1148-1213; plugin/lib/store-files.sh:874-931; plugin/lib/task-text.sh:23-36, 64-79; plugin/lib/task-check.awk:53-57, 78-79; plugin/lib/apply.test.sh:20-110, 258-317, 556-629, 636-660; plugin/lib/hostile.test.sh:105-136, 276-362, 450-494; docs/reference/cli.md:300-360; docs/reference/tasks.md:40-56; docs/security.md:145-222; docs/design.md:171-178; tasks/done/0152-the-hostile-shards-run-in.md:51-56, 87-124.

---

## Outcome

`peal apply` now takes a `vouch` proposal (`task`, plus `why`). On an unclaimed backlog task marked `origin: outsider`, it removes the mark and adds `<date>: Vouched for by a writer: <why>` under `## Notes` (or `...: Vouched for by a writer.` without a why; newline, CR and tab in why become spaces), in the batch's one commit with the body line `- <id> (vouch NNNN): <why>`. A task without `## Notes` gains the section, through the new `peal_text_add_note_or_section` in `plugin/lib/task-text.sh`, placed above the `---` before `## Outcome` or at the end.

Decided with the human at planning: a vouch for a task that is already a writer's is answered done ("task NNNN: already a writer's") and writes nothing, so a retry or a double click is harmless; the line names a fixed "a writer" (the proposal has no `by` field; Belfry's #588 would have to add one to say more); a vouch naming `@<id>` or carrying `origin: outsider` is refused; earlier Notes lines are left as they are, with no hint that they came from outside.

Trust: Peal cannot tell that a human sent a vouch. `docs/security.md` says so and that it relies on the caller (Belfry's human-only action) offering it to the human only; `docs/reference/tasks.md`'s `origin` row and `docs/reference/cli.md` name `vouch` as the one way the mark is removed.

Tests: `apply.test.sh` has a `vouch` case covering the success, the flattened why, no why, the missing Notes section, the writer's task, `add` outsider then `vouch` in one batch, and six invalids (501 passed under every awk). `hostile.test.sh` folds vouch proposals into the existing escaped-values, escaped-split and raw-split tries: the try count stays 2441, serial and four shards green. The success case uses task 0007 rather than the 0005 the Done when named; nothing else rests on the number.

The reviewer found nothing to act on. The project keeps no decisions directory, so no entry was written.
