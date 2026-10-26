---
plan: required
size: M
depends: []
touches: [plugin/lib/githooks.sh, plugin/lib/githooks.test.sh, plugin/lib/merge-gate.awk, plugin/lib/tasks.sh, plugin/lib/store-files.test.sh, plugin/commands/defer.md, docs/security.md]
milestone: m6
priority: high
model: opus
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


## Plan

Agreed 2026-10-26. Model: opus. Size M (about 70 tool calls). Merge: default.

Approach:
- `plugin/lib/githooks.sh`, `_peal_pre_push_direct`: after the shape awk passes, for the `add`, `modify` and `apply` shapes, every backlog task file the diff adds (A) or modifies (M) gets a content check. The `--raw` line already gives old and new blob SHAs (`m[3]`, `m[4]`); read each with `git cat-file blob` and parse with `yaml-lib.awk` plus `merge-gate.awk -v guard=1`, which additionally prints the raw `origin` records and `filled Plan` / `filled Outcome` lines using the filled rule of `peal_text_section_filled`. `merge-gate.sh` output unchanged.
- Refuse: frontmatter that does not parse (old or new); a `merge` key the old blob does not hold with the same raw value; `origin` removed or changed; Plan or Outcome from empty to filled. Added files: `merge` always refused, filled Plan/Outcome only with `origin: outsider`. `apply` only: `origin: outsider` may disappear from task NNNN when the commit body holds a line matching `^- [^ ]+ \(vouch NNNN\): `.
- Update the gate's comment block (githooks.sh 151-186).
- `plugin/lib/tasks.sh` `peal_edit_check`: refuse `origin` dropped or changed and Plan/Outcome newly filled (covers revise and defer; comment and set-milestone go through `_peal_files_build_rewrite`, which only adds `origin` and already guards `merge`).
- `plugin/commands/defer.md`: the agent empties an agreed Plan before deferring and says so in Notes.
- `docs/security.md`: the direct-push limit closed, with the tests; open limits: a filled Plan rewritten, a forged vouch line or subject (honest-mistake gate; branch protection is the real block).

Verification:
- `plugin/lib/githooks.test.sh` (`pre_push`, commits via `commit_ungated`), under every awk (`for_each_awk`). Refused: revise dropping `origin: outsider`; revise adding `merge: auto`; revise filling `## Plan`; `note on` dropping `origin`; defer filling Outcome; apply dropping `origin` with no vouch line; apply whose vouch line names another id; `file` of an outsider's task with filled Plan; a modified file whose new frontmatter does not parse. Allowed: the existing writes (test lines 131-149); apply with a real vouch via `peal apply`; revise adding `origin: outsider`; revise removing `merge`; a writer's `file` with a filled Plan.
- `plugin/lib/store-files.test.sh`: `peal revise` and `peal defer` refuse a dropped `origin` and a newly filled Plan.
- `tools/docs.test.sh`, `tools/lint.sh`.

Ranges:
- plugin/lib/githooks.sh:151-313
- plugin/lib/githooks.test.sh:121-224
- plugin/lib/merge-gate.awk:1-21
- plugin/lib/merge-gate.sh:45-50
- plugin/lib/tasks.sh:363-405
- plugin/lib/task-check.awk:78-86
- plugin/lib/task-text.sh:83-115
- plugin/lib/work.sh:55-83
- plugin/lib/store-files.sh:584-623, 680-751, 871-923, 1190-1197
- plugin/lib/apply.sh:1106-1151
- plugin/lib/hostile.test.sh:474-501
- plugin/commands/defer.md:39-64
- tasks/done/0161-gate-task-files-merge-auto.md:17-22, 46-68, 88-91
- docs/security.md:124-162, 164-201, 203-242, 263-269, 301-340, 469-513
- .belfry.yml:67-72

---

## Outcome

Built the direct-push half of the task; the issues-storage half (and 0122) was split into 0250 during planning.

- **Gate.** `_peal_pre_push_content` and `_peal_pre_push_guard` (`plugin/lib/githooks.sh`) run after the shape check for the `add`, `modify` and `apply` shapes. They read each added or modified backlog task file's old and new blob through `merge-gate.awk -v guard=1`, a new mode that also prints `origin` and whether Plan and Outcome are filled, by the same rule as `peal_text_section_filled`. The mode without `guard` prints what it printed before. Refused: frontmatter that does not parse; `merge` added or changed; `origin` dropped or changed; Plan or Outcome going from empty to filled. Added files mirror `peal create`: `merge` is always refused, and a filled Plan or Outcome is refused when the file carries `origin: outsider` (a writer's filing may hold a plan). An `apply` commit may drop `origin: outsider` from task NNNN only when its body holds a `- <id> (vouch NNNN): ` line. The match is `^- .+ \(vouch NNNN\): `, because proposal ids may contain spaces.
- **Storage.** `peal_edit_check` (`plugin/lib/tasks.sh`) refuses the same changes, so `peal revise` and `peal defer` fail before pushing rather than at the gate. On the issues storage it now refuses a newly filled Plan too; its origin check does nothing there. `plugin/commands/defer.md` tells the agent to empty an agreed Plan before deferring, say so in Notes, and keep `origin`.
- **Tests.** `plugin/lib/githooks.test.sh` (`pre_push`, under every awk) covers the refusals and the writes still allowed, including a real vouch through `peal apply`. Revise refusals are in `plugin/lib/store-files.test.sh`; defer refusals in `plugin/lib/backlog.test.sh`, where the defer harness lives (outside the touches; its fixture task now carries `origin: outsider`). Two existing gate tests had appended text after the Outcome and now write under Notes. The full suite (`tools/test-all.sh`, 38 harnesses, about an hour) passed, as did lint and the docs check.
- **Decisions taken with the human:** the split; defer and revise no longer carry or fill a Plan in the backlog; the store refuses what the gate refuses; added files mirror `create`; the vouch body line is proof enough; unparseable frontmatter is refused; `merge-gate.awk` is extended rather than duplicated. The Scope's "record" exemption was dropped: a record is a claim-branch commit or an issue edit and never reaches the pre-push gate.
- **Open limits (in `docs/security.md`):** a Plan that is already filled can still be rewritten by a revise push. The subject and the vouch line are strings the pusher chooses, so the gate guards against honest mistakes; branch protection is the real block.
- **Next:** 0250 handles the issues route. 0122 should be retired into it when 0250 is claimed.
