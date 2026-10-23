---
plan: required
size: M
depends: []
touches: [plugin/lib/store-files*.sh, plugin/lib/work*.sh, plugin/lib/tasks.sh, plugin/lib/close*.sh, plugin/lib/store-issues.test.sh, plugin/lib/backlog.sh, plugin/bin/peal, plugin/commands/*.md, plugin/commands/commands.test.sh, plugin/agents/reviewer.md, plugin/templates/task.md, docs/security.md, docs/design.md, docs/reference/*.md, docs/guides/*.md]
milestone: m6
priority: high
model: opus
---

# 0177 — merge: auto is the human's consent: it is recorded outside the task's branch and never read back from a claim copy

## Intent

`merge: auto` is what lets a control plane's "agreed tasks" rule merge a pull request once its checks are green, so it stands for the human's consent to a merge. Today the session writes it itself, on its own branch, and the board reads it back from that branch: `_peal_files_overlay` in `plugin/lib/store-files.sh` takes a claimed task's `size`, `plan`, `touches` and `merge` from the claim branch's copy (the overlay's columns 9, 10, 16 and 17), and `store-files.test.sh` asserts that a branch copy with `merge: auto` makes the board print it. Neither `peal record` (`plugin/lib/work.sh`) nor `peal_edit_check` (`plugin/lib/tasks.sh`) refuses a text that adds `merge`; `task-check.awk` only checks the value is `auto`. Only `peal create --owner` and `apply`'s `file` refuse it. `plugin/commands/work.md` step 5 asks the model to set it "only when the human agreed", which is a prompt, not a gate. A session steered by unmarked content, or a model mistake in an unattended job, can run `peal frontmatter set tasks/doing/0177-x.md merge auto`, record the plan, and the control plane merges the pull request with no human in the loop. When this is done the agreement is a record the session cannot write.

## Scope

- Where the agreement lives: either main's copy of the task (written by a narrow write the human or the control plane performs after the human's answer, for example a new `apply` proposal kind sent only by the control plane) or the control plane's own record of the answer, with the board's `merge` ignored. The plan chooses; the board never overlays `merge` from a claim copy either way.
- `peal record`, `peal revise`, `peal comment` and `peal frontmatter set` on a task text refuse to add `merge`; the reviewer's `merge-auto: withdraw` keeps working (it removes).
- `plugin/commands/work.md` step 5 and `docs/security.md` follow.

## Done when

- A test asserts that a claim copy carrying `merge: auto` does not make the board print `merge`.
- A test asserts that `peal record`, `peal revise` and `peal comment` refuse a text that adds `merge`.
- The way the human's agreement is recorded is written in `docs/security.md` and `docs/reference/tasks.md`, with the test that holds it.
- `plugin/commands/work.md` step 5 records the agreement through that route.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

2026-10-22: Re-plan 2026-10-22: the route this plan picks is a control-plane change either way (its belfry#729: a new apply kind sent only by the control plane after the human's answer, or its own record of the plan answer with the board's merge ignored). Whichever it is, the record names who answered; the control plane keeps that already.

- Security review finding 1 (HIGH, verified by reading and by the existing test). Related: 0161 (a task-files pull request writing `merge: auto` on another task) and the revise-shape task of this milestone; this task closes the board's side, those the writes' side.
- Needs a decision with the control plane: Belfry's contract says Peal writes `merge: auto` when the human agrees the plan and trusts the board's field; a change of route is a contract change on its side too (file it there if the plan picks the control-plane record).
- Security: touches the auto-merge tiers boundary and "the merge is the human's" (`docs/security.md`); update it in the same pull request.

Human's answers at planning (2026-10-23):
- Route: left to the session ("whatever is cleanest"); chosen: the control plane's own record of the plan answer. The board grants `merge` only from main's copy or the issue's label, never from a claim copy. Contract change on the control plane's side (belfry#729); until it ships, plan-agreed pull requests wait for the human.
- `peal create` and the ideas filed at close refuse a text that sets `merge` (yes, after the reason: a session's own filing is the remaining forge path).
- Close asks the reviewer for its `merge-auto` verdict when the Notes agreement line is present, not only the field: included here.
- Plan agreed as shown: size M, model opus, merge default, touches widened.

## Plan

**Outcome.** Nothing a session writes grants `merge: auto`. The board takes `merge` only from main's copy (files) or the issue's label (issues); a claim copy can only take it away (the reviewer's withdraw). The human's plan-time yes lives in the control plane's own record of the answer; Peal keeps a Notes trace line that grants nothing. Without a control plane the human writes `merge: auto` on main themselves (own PR, which 0161 gates, or the label).

**Approach.**
- a. Board overlay (`_peal_files_overlay`, `plugin/lib/store-files.sh:260-277`): column 17 (`merge`) becomes main's AND the copy's: a claim copy with an empty `merge` empties it; a copy's `auto` over an empty main stays empty. Columns 9, 10, 16 unchanged; header comment (lines 6-7) follows.
- b. One shared check `peal_merge_added OLD NEW VERB` in `plugin/lib/tasks.sh`: status 2 when NEW's `merge` is non-empty and differs from OLD's; removing is always allowed. Called from `peal_edit_check` (revise on main and on the claim, issue edits, apply edits), `peal_record` (`work.sh:178-183`), and `_peal_files_build_rewrite` as a backstop. `peal comment` already cannot reach the frontmatter. Error: "<verb>: the text adds merge; only the human sets merge: auto, on the main branch or the issue's label (docs/security.md)".
- c. `peal frontmatter set` / `set-list` (`plugin/bin/peal:340-353`) refuse the key `merge`; `unset` keeps working.
- d. Plain `peal create` and the queued ideas filed at close refuse a text that sets `merge` (`plugin/lib/backlog.sh`, `plugin/commands/idea.md`; adjust `store-issues.test.sh:1055-1057`).
- e. `plugin/commands/work.md` step 5 stops writing the field; it writes `merge: auto agreed by the human (<date>)` under `## Notes` and says the control plane keeps its own record of the answer.
- f. Close and reviewer: `close begin`, `_peal_close_merge_check` and the PR body (`close.sh:167-169, 328-344, 382-384`) treat the field or that Notes line as the trigger for the reviewer's `merge-auto` verdict; `withdraw` with no field leaves nothing to unset and puts the "merge: auto withdrawn" body line. A forged Notes line only adds a review question. `close.md` and `reviewer.md` follow.
- g. Docs: `docs/security.md` new subsection "merge: auto is the human's" (guard and harness) and "Auto-merge tiers" (395-408) reworded; known gap: a session with a `gh` login can label an issue. Also `docs/reference/tasks.md:53`, `docs/design.md:164-173, 264-271`, `docs/guides/working-a-task.md:33`, `docs/guides/belfry.md:43-46`, `plugin/templates/task.md:22`, `docs/reference/cli.md` (record, frontmatter, create), `docs/reference/commands.md:23`. Keep `docs/security.md` changes to the new subsection and the tiers sentence (0161 edits it too).

Rejected: a new `apply` kind writing `merge: auto` on main (main writes on a claimed task are refused on purpose, squash-merge conflict, and a session can run apply too); dropping `merge` from the board (removes the human's own route and the issue label).

**Verification.**
- `store-files.test.sh claim_copies` (~596-618): the existing "claim copy: merge" check inverted (copy auto over main without: no merge); main auto + copy auto: auto; main auto + copy without: empty.
- `work.test.sh record` (150-180, both storages): a text adding `merge: auto` refused naming merge, nothing recorded; a text removing it accepted.
- `store-files.test.sh` revise (~412): unclaimed backlog and claim-path revise refused. `store-issues.test.sh merge` (1046-1061): revise adding the label refused; dropping works; create with merge refused.
- Comment: `peal comment 0001 'merge: auto'` lands as a note and the board's merge stays empty (next to the `---` refusal, 496-497).
- `peal frontmatter set F merge auto` and `set-list F merge auto` refused; `unset` works.
- `commands.test.sh` 83-90: `work.md` writes the Notes agreement line and never `frontmatter set … merge`.
- `close.test.sh merge_cases` (513-572) unchanged passes; new case: Notes line only → begin notes it, finish needs the verdict, withdraw puts the body line without a record commit.
- `hostile.test.sh`, the full harness and shellcheck green.

**Ranges.** tasks/backlog/0161-gate-task-files-merge-auto.md:1-28; plugin/lib/store-files.sh:1-8, 260-302, 311-325, 526-535, 545-618, 866-952, 1184-1191; plugin/lib/store-files.test.sh:125-126, 412, 494-497, 586-618; plugin/lib/work.sh:143-194; plugin/lib/work.test.sh:150-180; plugin/lib/tasks.sh:363-391; plugin/lib/backlog.sh:62-101, 103-123, 177-186; plugin/lib/close.sh:160-169, 325-366, 368-384; plugin/lib/close.test.sh:50-60, 513-572; plugin/lib/store-issues.sh:405-415, 460-468, 680-686; plugin/lib/store-issues.test.sh:1027-1061; plugin/lib/apply.sh:625-632; plugin/bin/peal:340-353; plugin/commands/work.md:86-135; plugin/commands/close.md:58-62, 141-146; plugin/agents/reviewer.md:58-65; plugin/commands/commands.test.sh:83-90; plugin/templates/task.md:22; docs/security.md:124-130, 162-198, 219-225, 395-408; docs/design.md:164-173, 264-271, 345; docs/reference/tasks.md:53; docs/reference/commands.md:23; docs/guides/working-a-task.md:33; docs/guides/belfry.md:43-46.

---

## Outcome

**Built.** Nothing a session writes grants `merge: auto` any more.

- **Board.** It takes `merge` only from main's copy (task files) or the issue's label (issues). A claim copy can only take the field away (`_peal_files_overlay`: main AND copy), which is how the reviewer's withdraw still reaches the board.
- **Refusals.**
  - `peal_merge_added` (`plugin/lib/tasks.sh`) refuses a text that adds or changes `merge`. It is called from `peal_edit_check` (revise on main and on a claim, issue edits) and `peal record`, with a backstop in the files rewrite.
  - `peal frontmatter set`/`set-list` refuse the key; `unset` works.
  - Every filing (`peal create`, `peal idea`, ideas filed at close, split pieces) refuses `merge` in `task-check.awk`, as the human answered.
- **Where the agreement lives.** The human's plan-time agreement is recorded by the control plane, as its own record of the answer. `/peal:work` step 5 now writes only a trace line under Notes, `merge: auto agreed by the human (<date>)`. Close treats the field or that line as the trigger for the reviewer's `merge-auto` verdict. A withdraw with no field leaves nothing to unset: the PR body carries the "merge: auto withdrawn" line. A forged Notes line only adds a review question.
- **Docs.** `docs/security.md` has a new subsection, "`merge: auto` is the human's", that names the tests holding it. `docs/reference/tasks.md`, `docs/design.md`, the guides, cli/commands and the prompts follow.

**Decided.**
- **Route.** The control plane's record, left to the session by the human. A new `apply` kind on main was rejected for three reasons: main writes on a claimed task are refused on purpose, a squash merge would conflict, and a session can run apply too.
- **Filing refusal.** It sits in `task-check.awk`, not `backlog.sh` as the plan said, so one place covers both storages and queue time. `task-text.sh` (`peal_text_merge_agreed`) and `plugin/agents/planner.md` changed beyond the agreed touches for the same reason.
- **`peal comment`.** It refuses nothing new: it can only add a dated note and never reaches the frontmatter. The test shows a `merge: auto` comment lands as a note and the board's `merge` stays empty. That is how Done-when 2 holds for comment.

**Known gaps (for the next session).**
- **The control plane.** It must stop trusting a session-written `merge` and act on its own record of the plan answer, leaving the merge to the human when the PR body carries "merge: auto withdrawn" (belfry#729). Until then the "agreed tasks" tier has no working grant for a claimed files task, and plan-agreed pull requests wait for the human. The human accepted this at planning.
- **The issues label.** A session holding a `gh` login that may label issues can add the `merge: auto` label itself. This is documented in `docs/security.md`; under Belfry there is no such login.
- **Files storage without a control plane.** The human's field on main holds only when it is there before the claim, because the overlay cannot tell a later grant from a withdrawal. The issues label works at any time. The docs say so (reviewer finding).
- **Tests run locally.** The sandbox lacks jq and shellcheck, so both were fetched from their GitHub releases into the job's temp directory to run the dependent harnesses: close 1527, store-issues 750, work 384, store-files 645, all with 0 failures, and `tools/lint.sh` is clean. That run caught a test bug in the new Notes-only close case (it ran `begin` in a subshell, losing its Outcome path), fixed in adbce41. `doctor.test.sh` was not run to the end.

**Review.** The reviewer found the following; all were fixed on the branch by the implementer:
- a `store-issues.test.sh` fixture without `## Raw`, which would have failed the revise that drops the label;
- docs that overstated the human-on-main route for claimed files tasks;
- the refusal message worded five ways;
- a garbled test comment.

A second review confirmed those fixes. It found `docs/guides/belfry.md` still claiming that plan-agreed auto-merge works today, and an awkward frontmatter refusal message; both were fixed here.

### Reviewer findings not acted on

- **Files outside touches** (`task-check.awk`, `task-text.sh`, `planner.md`, and wording-only changes in `apply.sh` and `store-issues.sh`): kept, and explained above.
- **`apply`'s `file` kind refuses `merge` twice** (its inline check and `peal_task_check plain`): kept, because the inline check gives a clearer per-proposal error.
