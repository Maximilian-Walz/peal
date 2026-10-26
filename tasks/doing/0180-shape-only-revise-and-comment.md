---
plan: required
size: M
depends: []
touches: [plugin/lib/githooks.sh, plugin/lib/githooks.test.sh, plugin/lib/merge-gate.awk, plugin/lib/tasks.sh, plugin/lib/store-files.test.sh, plugin/commands/defer.md, docs/security.md]
milestone: m6
priority: high
---

# 0180 — Shape-only revise and comment pushes cannot drop origin: outsider, add merge or fill ## Plan; an outsider's labelled issue with ## Plan does not read as PLAN agreed

## Intent

Two routes let hostile text become an agreed plan or an unmarked task. First, the pre-push shapes `modify`, `apply` and `add` (`_peal_pre_push_direct` in `plugin/lib/githooks.sh`) check the path, mode and count of a `docs(tasks): revise 0180` push but never the frontmatter or sections of the new blob. A commit with that subject that modifies one backlog file passes with any text: `origin: outsider` gone, `merge: auto` added, or `## Plan` filled (which `plugin/lib/work.sh` reads as `PLAN agreed`). Only a `vouch` proposal should drop the mark. Second, on the issues storage `origin` is never set, so `plan` comes from labels and a filled `## Plan` in the body reads as `agreed`; the re-label check covers edits after labelling, not a plan that was already in the body when the maintainer labelled the issue. Under plain Claude Code `/peal:work` then starts the implementer on the stranger's plan. When this is done neither route turns text from outside into consent.

This task now holds the first route only, the direct push; the second (the issues storage, with 0122) is split into 0250.

## Scope

- The `modify`, `apply` and `add` shapes parse the old and new blobs (`yaml-lib.awk` with `merge-gate.awk` in a new `guard=1` mode) and refuse when the frontmatter does not parse, `merge` appears, `origin` disappears or changes, or `## Plan` or `## Outcome` goes from empty to filled. Added files mirror `peal create`: `merge` always refused, a filled Plan or Outcome only with `origin: outsider`. An `apply` commit may drop `origin: outsider` from task NNNN only when its body holds a `- <id> (vouch NNNN): ` line.
- The storage's own check (`peal_edit_check`, `plugin/lib/tasks.sh`) refuses the same: `peal revise` and `peal defer` cannot drop or change `origin` or fill a Plan or Outcome.
- Links 0161, which gates the pull request route (`peal merge-gate`, `plugin/lib/merge-gate.sh`).

## Done when

- Tests: a direct revise push that removes `origin: outsider`, one that adds `merge`, and one that fills `## Plan` are each refused by the gate; `peal revise` and `peal defer` refuse a dropped `origin` and a newly filled Plan.
- `docs/security.md` says the direct-push limit is closed, with the tests, and names the open limits (a filled Plan rewritten, a forged vouch line).

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

Revised 2026-10-26: split: 0250 holds the rest

- Security review findings 7 and 8 (MEDIUM, read). Check 0161 (a task-files pull request setting `merge: auto` on another task; it is moved into this milestone) and 0122 first and take what the plan finds they share rather than doing it twice.
- Security: touches the "nothing reaches main but..." and "hostile prose is read, never run" boundaries; update `docs/security.md` here.
- 2026-10-26, planning with the human:
  - Split: the issues route and 0122 went to 0250; this task keeps the direct-push gate.
  - DeferPlan: refuse a defer that carries a filled Plan back to the backlog; `defer.md` tells the agent to empty the Plan and say so in Notes.
  - RevisePlan: `peal revise` no longer fills a backlog task's Plan; a pre-written plan goes through `peal create` or the human's own pull request.
  - StoreChecks: `peal_edit_check` refuses the same changes as the gate (outside the original touches; agreed).
  - FileAdd: added files mirror `peal create`.
  - VouchProof: the apply commit's `(vouch NNNN)` body line is enough; documented under the gate's honest-mistake limit.
  - RecordExempt: the Scope's "record" exemption is dropped: a record never reaches the pre-push gate (claim branch or issue edit); say so in the Outcome.
  - FilledPlan: a filled Plan rewritten by a revise push is documented as an open limit.
  - BadYAML: an old or new blob whose frontmatter does not parse is refused.
  - AwkReuse: extend `merge-gate.awk` with `guard=1`; `merge-gate.sh` output unchanged.

---

## Outcome

<!-- Written at close, replacing this comment. -->
