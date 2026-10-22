---
plan: required
size: M
depends: []
touches: [plugin/lib/store-files.sh, plugin/lib/work.sh, plugin/lib/tasks.sh, plugin/lib/task-check.awk, plugin/commands/work.md, docs/security.md]
milestone: m6
priority: high
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

- Security review finding 1 (HIGH, verified by reading and by the existing test). Related: 0161 (a task-files pull request writing `merge: auto` on another task) and the revise-shape task of this milestone; this task closes the board's side, those the writes' side.
- Needs a decision with the control plane: Belfry's contract says Peal writes `merge: auto` when the human agrees the plan and trusts the board's field; a change of route is a contract change on its side too (file it there if the plan picks the control-plane record).
- Security: touches the auto-merge tiers boundary and "the merge is the human's" (`docs/security.md`); update it in the same pull request.

---

## Outcome

<!-- Written at close, replacing this comment. -->
