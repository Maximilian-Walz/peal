---
plan: required
---

# 0056 — Files storage: the board reads a claimed task's touches from its claim branch, not main

## Intent

In the files storage, for a task with a claim (claimed-live, parked, awaiting-merge), take the frontmatter fields the plan records (`touches`, and likely `size`, `plan`, `model`, `merge`) from the claim branch's copy of the task file (the local branch, else the one on the remote), falling back to main's when the branch has no copy. Keep everything else (state, title, milestone, depends) from main as now, so the read model's rules and every worktree's answer stay the same. Do it in one pass over the claims already listed in `_peal_files_claims`, so `peal board` does not get noticeably slower with many branches. Update `docs/design.md` (the files-storage read model and the `touches` field) to say where a claimed task's fields come from.

## Done when

- `peal board` (and `peal list`) with the files storage shows, for a claimed task, the `touches` recorded on its claim branch with `peal record ID plan`, before the task merges
- It does so for a claim only on the remote (no local branch) too, reading the remote branch's copy
- The same holds for whichever other recorded fields are chosen (at least `size`), or the issue says why not
- An unclaimed task, or a claim branch without the task file, reads as today (from main)
- Tests in `plugin/lib/store-files.test.sh` cover a local claim, a remote-only claim and the fallback
- `docs/design.md` describes where a claimed task's fields come from in the files storage

## Raw

Filed as issue #56 (https://github.com/Maximilian-Walz/peal/issues/56) from an idea a session had; its text is carried over into the sections above.

## Notes

`touches` (#34) is on the board so a scheduler like Belfry does not start two tasks on the same files side by side. With the files storage, the board is built from the main branch only:

- `peal_store_list` in `plugin/lib/store-files.sh` scans the task files of `_peal_files_base` (the remote's main) with `_peal_files_scan` → `plugin/lib/task-scan.awk`, and `_peal_files_claims` adds only each branch's state and detail (`wt:<path>`, `remote:<remote>`, `pr:#N`), never its frontmatter. `plugin/lib/task-state.awk` then joins the two, and `plugin/lib/board.awk` prints `touches` from the main-branch record.
- When the human agrees the plan, `/peal:work` (`plugin/commands/work.md`) writes the planner's `touches` (and size, a non-default `model:`, `merge: auto`) into the task file and `peal record ID plan` commits it. In the files storage, `peal_store_record` commits that onto the task's claim branch (the copy under `doing/`), so main sees it only once the task merges.

So while a task is claimed, the board shows only the `touches` it was filed with (from `/peal:idea`, often none), and Belfry has only that plus the files the worker reports. The issues storage has no such gap: its `peal_store_record` (`plugin/lib/store-issues.sh`) rewrites the issue's labels at record time, `touches: <path>` among them, so the board sees the planner's `touches` at once.

`peal_store_read` in the files storage already prefers a branch's copy of the task over main's; `peal_store_list` does not.

---

## Outcome

