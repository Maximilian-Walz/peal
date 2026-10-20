---
milestone: m3
plan: required
priority: high
size: M
touches: [plugin/lib/apply.sh, plugin/lib/apply.test.sh, plugin/lib/hostile.test.sh, docs/reference/cli.md, docs/security.md]
---

# 0154 — `peal apply` reads and answers what Belfry's contract sends

## Intent

`peal apply` (0112, 0132, 0139) and Belfry's `tasks.commands.apply` disagree on the format, so once 0133 adds `apply:` to a project's `.belfry.yml`, Belfry's batches are refused or misread. Belfry's docs/contract.md ("Carrying out proposals", "Proposals") is the reference, and `internal/api/apply.go` and `internal/api/proposal.go` are what Belfry actually sends and reads:

- **`origin`:** Belfry puts it on every proposal (`writer` or `outsider`). Peal accepts it only on `file` and `add`, and answers "field origin is not one priority takes" for the rest. An invalid proposal stops the whole batch, so every batch fails.
- **`ref`:** a plan run's proposals carry Belfry's `ref` (the session's own name for the card). Peal refuses unknown fields.
- **`depends`:** Belfry sends `task`, `on` and `remove: true` to remove a dependency, or no `remove` to add one. Peal requires `op` (`add`, `remove`).
- **`split_milestone`:** Belfry names the milestone to split `milestone`. Peal reads `from`.
- **The answer:** Belfry reads one JSON line per proposal with `id`, `done` (true or false), `outcome` (one line), and `task` for a `file` or `milestone` for a new milestone. Peal answers `status` ("done", "invalid"), `detail` and `change`, so Belfry would read every proposal as not carried out.
- **Fields Belfry leaves out** (it omits empty values): check that a `move` without `milestone` means "no milestone", and that omitted optional fields are read as absent, not as invalid.

Make `peal apply` take and answer exactly that. `origin` is accepted on every kind, and only `file` and `add` act on it. Unknown Belfry-only fields such as `ref` and `item` are ignored. Peal's own `status` and `detail` can stay alongside if anything in Peal reads them.

## Scope

- `plugin/lib/apply.sh`: input and answer follow Belfry's contract (`origin` on every kind; `ref`, `item`, `into` ignored; `move` without `milestone` = none; `depends` `remove` replaces `op`; `split_milestone` `milestone` replaces `from` and takes tasks from any milestone or none; answers `id`, `done`, `outcome`, `task`, `milestone`, `change`).
- `plugin/lib/apply.test.sh`, `plugin/lib/hostile.test.sh`: converted, plus a Belfry-shaped case.
- `docs/reference/cli.md` ("peal apply"), `docs/security.md` (the apply guard).

## Done when

- `bash plugin/lib/apply.test.sh` passes with a new `belfry_shapes` case: a batch hand-written in `ApplyProposal`'s marshal order (`id`, `kind`, `ref`, non-empty fields, `why`, `origin` last; empties omitted) covering `milestone_create` (with `ref`, `origin: writer`), `split_milestone` (`milestone`, `tasks`, `title`), `file` (`origin: outsider`, `ref`), `move` without `milestone` (task ends with none), `move` into a milestone, `priority`, `depends` without `remove` (adds) and with `"remove": true` (removes), `retire` with a reason, `milestone_update`, `milestone_state` with `ref`, and a proposal carrying `item` and `into`. Each answer line is checked byte for byte against `ApplyResult` (`"done": true`, `outcome`, `task` on the file, `milestone` on create and split), and the commit on main: each touched frontmatter, `origin: outsider` only on the filed task, the depends list.
- An invalid Belfry-shaped batch answers `"done": false` with an `outcome` on every line, exits 2, main unchanged.
- Existing cases converted and passing; new invalids: `remove: "yes"`, `op` (now unknown), `from` (now unknown), `origin: "x"` on a `priority`, `size` (still unknown).
- `bash plugin/lib/hostile.test.sh` passes; shellcheck clean on changed scripts; `tools/docs.test.sh` passes if it covers cli.md.

## Raw

> Found while applying a batch by hand: peal apply refuses origin on priority and move, though Belfry's contract puts origin on every proposal; depends wants op where Belfry sends remove, split_milestone wants from where Belfry sends milestone, and the answer lines say status/detail where Belfry reads done/outcome. Fix before 0133 adds apply to the contract.

## Notes

- 0133 depends on this: until it is done, `apply:` in a project's `.belfry.yml` makes Belfry's batches fail.
- A test feeds `peal apply` batches shaped exactly as Belfry's `ApplyBatch` marshals them (every kind, with `origin` and a plan's `ref`, and a removing `depends`), and checks the answer lines against Belfry's `ApplyResult`.
- `docs/reference/cli.md` ("peal apply") and the kind list at the top of `plugin/lib/apply.sh` follow the change. 0153's `vouch` kind uses the same shapes.
- Plan agreed 2026-10-20. The human's answers:
  - Scope and Done when are the plan's.
  - Ignored fields are the fixed list `ref`, `item`, `into`, whatever their scalar value; every other unknown field is still refused.
  - `split_milestone` takes tasks from any milestone or none, as the contract says (the parked-milestone check stays).
  - The answer drops `status` and `detail`; `change` stays, and so do `task` and `milestone` on the kinds beyond those Belfry documents.
  - `"origin": ""` reads as absent (writer) on every kind; any other value outside `outsider`/`writer` is invalid on every kind.
  - A `move` with `"milestone": ""` is still refused: only absent or `null` mean none.
  - `retire` with both `reason` and `duplicate` stays refused.
  - The Desk's Dismiss is assumed to arrive as `retire`; `dismiss` stays invalid. Confirm on Belfry's side under 0133.
  - 0153 should get `depends: [0154]`: a revise outside this branch.

## Plan

Belfry's docs/contract.md ("Proposals", "Carrying out proposals"), internal/api/apply.go (`ApplyProposal`, `ApplyResult`) and internal/api/proposal.go are the reference; fixtures are hand-written, nothing vendored. All code changes are in `plugin/lib/apply.sh` (`_pa_static`, `_pa_static_ms`, `_pa_item`, `_pa_ms_item`, `_pa_check`, `_pa_answer`, `_pa_finish`); `apply.awk` stays.

1. `origin` in every kind's allowed list; value checked (`outsider`/`writer`, `""` = absent) everywhere; only `file` and `add` act on it.
2. Skip `ref item into` before the unknown-field check, untyped; everything else unknown still refused.
3. `move`: absent `milestone` and `null` both unset it; `file` keeps absent = the text's own.
4. `depends`: delete `op`; allowed `task on remove`, `remove` true/false/null, absent/false/null = add; the type check and the cycle attribution in `_pa_check` follow.
5. `split_milestone`: rename `from` to `milestone` (allowed, required, `_pa_ms_item`, the order default, messages; `@<id>` through `_pa_ms_ref`); drop the "task not in the milestone" refusal, keep the parked-milestone check.
6. Answer `{"id", "done", "outcome", "task", "milestone", "change"}`: `done` true only for done; `outcome` takes what `detail` held; r/*.status stay internal; the no-JSON-document line becomes `{"id": "", "done": false, "outcome": ...}`.
7. The header comment of `apply.sh`, `docs/reference/cli.md` "peal apply" and `docs/security.md`'s apply guard follow.

Verification: as in Done when.

Ranges: tasks/backlog/0153-peal-apply-takes-a-vouch.md:1-32; plugin/lib/apply.sh:1-58, 181-300, 376-469, 542-582, 772-793, 883-955; plugin/lib/apply.awk:1-19, 185-245; plugin/lib/apply.test.sh:34-70, 125-140, 197-254, 258-375, 377-431, 453-515; plugin/lib/hostile.test.sh:420-459; docs/reference/cli.md:307-356; docs/security.md:183-217; docs/design.md:96-104; Belfry docs/contract.md:1042-1073, 1084-1140, internal/api/apply.go:17-43, 90-121, internal/api/proposal.go:89-126, 133-219, 376-406.


---

## Outcome

<!-- Written at close, replacing this comment. -->
