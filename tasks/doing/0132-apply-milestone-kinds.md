---
milestone: m3
plan: required
depends: [0112]
part-of: 0112
size: M
model: opus
touches: [plugin/lib/apply*, plugin/lib/githooks*.sh, plugin/lib/store-files.sh, plugin/lib/milestones.sh, plugin/lib/hostile.test.sh, docs/design.md, docs/security.md, docs/reference/*.md]
---

# 0132 — `peal apply`: the milestone kinds

## Intent

`peal apply` carries out the milestone proposals of Belfry's proposal model on the
files storage, in the same single commit as the rest of the batch:
`milestone_create`, `milestone_update`, `milestone_state` (park, unpark, close,
reopen) and `split_milestone`. The pre-push gate's `apply` shape gets added and
modified milestone files. Until this lands, 0112 answers these kinds
`invalid: not yet`.

## Scope

- `milestone_create`, `milestone_update` and `milestone_state` on the files storage, in
  0112's input and answer format plus a `"milestone"` answer key.
- New milestone ids assigned by Peal and referable as `@<proposal id>` by later
  proposals of the batch (`file`, `move`, `milestone_update`, `milestone_state`).
- Checks against the milestones and tasks as the whole batch leaves them.
- The pre-push gate's `apply` shape widened to adding and modifying milestone files.
- Docs updated. `split_milestone` stays `invalid: not yet`; it is a follow-up task
  (string arrays in `apply.awk`), filed from this one.

## Done when

- A mixed batch of task and milestone proposals is one commit (one pull request on a
  protected main, with the fake gh).
- An invalid milestone proposal leaves main unchanged and names that proposal.
- The gate passes an apply commit adding or modifying `<milestones>/<name>.md` and
  refuses the other shapes (subdirectories, deletions, renames, non-task files).
- `docs/reference/cli.md` documents the three kinds.

## Raw

> A control plane's triage and planning runs end with a list of changes the human
> accepted: file these tasks, move those to another milestone, change a priority, add a
> dependency, retire a duplicate, create or park a milestone.
>
> `peal apply` takes the proposal kinds Belfry's contract defines for
> `tasks.commands.apply` (Belfry issue #434, with the kinds of #433): file, add, move,
> priority, depends, retire (with a duplicate), milestone create, update, state and
> split.

Split from 0112

## Notes

- Field names come from Belfry #433 (data, quoted from that issue):
  > `milestone_create` (title, goal, due, order), `milestone_update` (due, order,
  > title), `milestone_state` (park, unpark, close, reopen), `split_milestone` (a new
  > milestone and the tasks that move to it)
- Unclear: how a new milestone gets its id. The planner's default was that Peal
  assigns the next `mN`, answers it, and a later proposal of the batch names it as
  `@<proposal id>`.
- The input and answer format are 0112's (see its `## Plan`).
- Size estimate: M.
- 2026-10-19, the human's answers to the plan's questions:
  - A1: `milestone_state` keys `milestone`, `state`, `reason`; `state` only Belfry's
    verbs park, unpark, close, reopen (park→parked, unpark/reopen→open, close→done);
    `reason` only with park.
  - A2: id is `m` + (highest numeric N + 1), zero-padded to the width only when every
    existing numeric id is padded; the caller cannot choose it; nothing is reserved
    across rival pull requests (a clash surfaces as a conflict).
  - A3: `split_milestone` takes its tasks as a JSON array of strings, which needs
    `apply.awk` to learn arrays on whitelisted keys: that is a follow-up task, filed
    from this one (depends on 0132). This task leaves the kind `invalid: not yet`.
  - A4 (for the follow-up): `from` required, every listed task must be in it, the new
    order is the given one or `from`'s + 1, nothing renumbered.
  - A5: a new milestone uses init's template: `# <title>`, `## Goal` (goal or init's
    placeholder), `## Acceptance criteria` (init's placeholder); state `open`; order
    given or highest + 1.
  - A6: milestone kinds answer their id in a new `"milestone"` key.
  - A7: `milestone_create` does not file the milestone's review task.
  - A8: a `close` is invalid while a task neither done nor retired (the milestone's
    review task aside) names the milestone after the batch.
  - A9: the parked rule holds: no task ends moved into a milestone the batch leaves
    parked; no task moves out of a milestone parked at the start unless the batch
    unparks it.
  - A10: `@<id>` names only an earlier proposal; moves are checked against the end
    state regardless of order.
  - A11: a title goes into frontmatter `title:` if the file has one, else the `# `
    heading; never both.
  - A12: in `milestone_update`, `due: null`/`order: null` remove the field; an update
    with no fields is invalid ("nothing to update").
  - A13: the "none current → first open by order" rule runs only when the batch has a
    `milestone_state` proposal.
  - A14: no `review` text on close.
  - A15: the "next current" rule moves out of `_peal_files_build_ms_state` into a
    helper shared with `peal milestone-state`.
  - A16: Peal proposes the contract; Belfry adopts it.

## Plan

Agreed 2026-10-19. Build on `plugin/lib/apply.sh`'s pipeline (static, compose on
copies, check the end state, one tree):

- **Static (`_pa_static`)**: the three kinds and their fields: `milestone_create`
  (`title` required, `goal`, `due`, `order`), `milestone_update` (`milestone`, `title`,
  `due`, `order`; at least one besides `milestone`), `milestone_state` (`milestone`,
  `state`, `reason`). `title`/`reason` one line, no tab (review.sh's rule); `due`
  YYYY-MM-DD or null (update only); `order` integer or null (update only); `goal` with
  no `---` or `## ` line (the `add` rule); verbs as A1. `milestone` is an id or
  `@<proposal id>` of an earlier `milestone_create`, resolved by a new `_pa_ms_index`;
  `file` and `move`'s `milestone` accept `@<id>` too. `split_milestone` keeps
  `invalid: not yet`.
- **Compose**: extract main's milestones directory once into `$PA_S/ms/` (as
  `_peal_files_build_ms_state` does); assign new ids before the item loop (A2); write
  the new file from init's template shape (A5; read it in place or move the text into
  milestones.sh rather than sharing from init.sh); updates via
  `peal_fm_set`/`peal_fm_unset` (A11, A12); state changes in order, then the shared
  "next current" helper once when a `milestone_state` is in the batch (A13, A15). A
  state the milestone already has is answered `done` with "already", no file change.
- **Check (`_pa_check`)**: `peal_ms_load` on the composed milestones; task-check.awk's
  context fed the composed `ms` lines, not main's; the parked rule (A9) and the close
  rule (A8).
- **Build (`_pa_build`)**: `add`/`modify` entries for changed milestone files; the
  commit body names each milestone proposal's id. **Answer**: `"milestone"` key (A6).
- **Gate**: githooks.sh's apply branch accepts `A` mode 100644 and `M` 100644→100644
  for `<milestones>/<name>.md`; same rule in its header comment and in
  `docs/security.md`'s Limit paragraph.
- **Docs**: cli.md's `peal apply` table (the "not taken yet" sentence narrowed to
  `split_milestone`), design.md (96-102, 448-449), security.md (132-135).
- **Follow-up**: file the `split_milestone` task (A3, A4) with `/peal:idea`, depends
  0132, milestone m3.

Files: plugin/lib/apply.sh, apply.test.sh, githooks.sh, githooks.test.sh,
store-files.sh, milestones.sh (maybe), hostile.test.sh, docs/reference/cli.md,
docs/design.md, docs/security.md.

Verification: apply.test.sh on a bare remote: a mixed batch (create p1; file with
`milestone: "@p1"`; move 0001 → @p1; update m1 title/due/order null; park m2 with a
reason) is one commit `docs(tasks): apply 5 proposals` with the expected tree and
answers, exit 0; closing the current milestone makes the next open one current in the
same commit; reopen/unpark → open; already-in-state → done "already"; the same batch
with `main-writes: pr` against the fake gh is one pull request. Invalid batches (main
unchanged, no pull request, the bad one `invalid`, the rest `not_applied`, exit 2):
unknown milestone, dangling `@`, bad due, non-integer order, reason without park,
multi-line title, goal with `## `, move into a milestone the batch parks or closes,
close with an open task, empty update. githooks.test.sh: apply commit adding and
modifying `docs/milestones/*.md` passes; `docs/milestones/sub/x.md`, delete, rename,
non-task file refused. hostile.test.sh: `$(...)`, backticks, `---`, newlines in title,
goal, reason stored byte for byte or refused, never run. `tools/docs.test.sh` passes.

Ranges: tasks/done/0112-apply-a-batch-of-proposals.md:94-201, 244-300;
plugin/lib/apply.sh:1-38, 79-211, 213-348, 350-461, 477-617; plugin/lib/apply.awk:1-15,
148-198; plugin/lib/apply.test.sh:1-35, 113-165; plugin/lib/milestones.sh:6-75;
plugin/lib/milestone-read.awk:1-76; plugin/lib/store-files.sh:284-299, 1193-1271;
plugin/lib/review.sh:7-55; plugin/lib/init.sh:341-359; plugin/lib/githooks.sh:144-178,
235-320; plugin/lib/task-check.awk:15-20, 55-70; plugin/lib/frontmatter.sh:29-54;
docs/reference/cli.md:303-343, 594-601; docs/reference/tasks.md:116-159;
docs/design.md:85-119, 354-361, 444-451; docs/security.md:109-135, 181-206;
docs/milestones/m3.md:1-27.

---

## Outcome

<!-- Written at close, replacing this comment. -->
