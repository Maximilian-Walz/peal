---
plan: required
touches: [plugin/commands/work.md, plugin/lib/board.awk, plugin/lib/task-scan.awk, plugin/lib/task-state.awk, plugin/lib/store-files.sh, plugin/lib/store-files.test.sh, plugin/lib/store-issues.sh]
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

Draft plan, NOT agreed (2026-09-26). The planning session could not reach the human: AskUserQuestion timed out twice and Belfry's idea tool once. The next session asks the human to agree this plan and does not re-plan unless they change the approach.

- Approach:
  - `_peal_files_claims` takes a COPIES dir. For each claim it keeps, it writes that ref's copy of the task file (the local branch, else the remote's) under the same path. `_peal_files_find` rules apply. It widens the existing `git ls-tree` call to reuse the listing, which adds about one `git show` per claim.
  - `peal_store_list` runs `task-scan.awk` once over COPIES. An awk step then overlays fields 9 (`size`), 10 (`plan`), 16 (`touches`) and 17 (`merge`) onto main's records, before `task-state.awk` runs unchanged.
  - State, title, milestone, depends, part-of and path stay main's.
  - `board.awk`, `task-scan.awk`, `task-state.awk` and `store-issues.sh` stay unchanged.
  - `model` is not on the board, so it is left out.
- Rejected:
  - Extra columns on the claims lines: this changes the shared read model and collides with `_peal_files_prs`.
  - `_peal_files_scan` per claim: it costs claims x tasks.
  - `peal record` writing onto main: this breaks the lock.
- Touches: `plugin/lib/store-files.sh`, `plugin/lib/store-files.test.sh`, `docs/design.md`.
- Verification, in a new case in `store-files.test.sh` under `for_each_awk`:
  - a local claim, where the branch's touches, size and merge show and title, milestone and path stay main's;
  - a branch-only `depends`, which does not change the state;
  - parked, remote-only (detail `remote:origin`) and awaiting-merge (the copy under done/) claims;
  - the fallbacks: an unclaimed task, and a branch tip without the task file;
  - `peal list` output unchanged.
- Size S. Model default. Merge default.
- Questions for the human (defaults first):
  1. Replace the listed touches with the three files above? Yes.
  2. Take size, plan, touches and merge from the branch? Yes. `plan` is overlaid raw, with no new "agreed" value.
  3. `peal record` does not push, so remote-only readers see the recorded fields after the next push: no change here; say it in design.md and file an idea for pushing.
  4. A branch copy with unparseable frontmatter: fall back to main's fields. The parse warning still shows.
  5. Duplicate scan warnings from the copies: drop them all except the parse one.
  6. Local wins over remote, as in `peal_store_read`. Match the copy by id, whatever its slug. No timing test.
- Ranges:
  - docs/design.md:90-95, 262-278, 304-315, 654-672, 721-726
  - plugin/lib/store-files.sh:49-70, 82-175, 212-256, 1027-1034
  - plugin/lib/task-scan.awk:1-22, 96-98
  - plugin/lib/task-state.awk:1-19, 142-160
  - plugin/lib/board.awk:1-29
  - plugin/lib/tasks.sh:287-306
  - plugin/commands/work.md:84-103
  - plugin/lib/store-files.test.sh:1-20, 354-428
  - plugin/lib/task-fixtures.sh:15-78

---

## Outcome

