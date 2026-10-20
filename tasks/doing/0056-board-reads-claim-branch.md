---
plan: required
touches: [plugin/lib/store-files.sh, plugin/lib/store-files.test.sh, plugin/lib/work.test.sh, docs/design.md]
milestone: m3
size: S
---

# 0056 — Files storage: the board reads a claimed task's touches from its claim branch, not main

## Intent

In the files storage, for a task with a claim (claimed-live, parked, awaiting-merge), take the frontmatter fields the plan records (`touches`, and likely `size`, `plan`, `model`, `merge`) from the claim branch's copy of the task file (the local branch, else the one on the remote), falling back to main's when the branch has no copy. Keep everything else (state, title, milestone, depends) from main as now, so the read model's rules and every worktree's answer stay the same. Do it in one pass over the claims already listed in `_peal_files_claims`, so `peal board` does not get noticeably slower with many branches. Update `docs/design.md` (the files-storage read model and the `touches` field) to say where a claimed task's fields come from.

## Scope

- `plugin/lib/store-files.sh`: `_peal_files_claims` saves each claim's copy of the task file from the ref the claim was read from; `peal_store_list` overlays the copies' non-empty size, plan, touches and merge onto main's records before `task-state.awk`.
- Tests in `plugin/lib/store-files.test.sh`; `plugin/lib/work.test.sh`'s files branch shows `record` then `board`.
- `docs/design.md`: the `touches` paragraph and the Storage table's `list` row.
- Out: `peal record` pushing (a follow-up idea), `peal_store_read`, the issues storage, `board.awk`, `task-scan.awk`, `task-state.awk`.

## Done when

- `peal board` (and `peal list`) with the files storage shows, for a claimed task, the `touches` recorded on its claim branch with `peal record ID plan`, before the task merges
- It does so for a claim only on the remote (no local branch) too, reading the remote branch's copy
- The same holds for whichever other recorded fields are chosen (at least `size`), or the issue says why not
- An unclaimed task, or a claim branch without the task file, reads as today (from main)
- Tests in `plugin/lib/store-files.test.sh` cover a local claim, a remote-only claim, a parked and an awaiting-merge claim, a deferred local branch with a newer remote claim, and the fallbacks (unclaimed, no copy on the branch, broken frontmatter)
- The fields taken from the branch are size, plan, touches and merge; only non-empty values override main's
- `docs/design.md` describes where a claimed task's fields come from in the files storage

## Raw

Filed as issue #56 (https://github.com/Maximilian-Walz/peal/issues/56) from an idea a session had; its text is carried over into the sections above.

## Notes

Deferred 2026-09-28 after a claim: stale claim: its session stopped; given back so auto mode picks it up again

`touches` (#34) is on the board so a scheduler like Belfry does not start two tasks on the same files side by side. With the files storage, the board is built from the main branch only:

- `peal_store_list` in `plugin/lib/store-files.sh` scans the task files of `_peal_files_base` (the remote's main) with `_peal_files_scan` → `plugin/lib/task-scan.awk`, and `_peal_files_claims` adds only each branch's state and detail (`wt:<path>`, `remote:<remote>`, `pr:#N`), never its frontmatter. `plugin/lib/task-state.awk` then joins the two, and `plugin/lib/board.awk` prints `touches` from the main-branch record.
- When the human agrees the plan, `/peal:work` (`plugin/commands/work.md`) writes the planner's `touches` (and size, a non-default `model:`, `merge: auto`) into the task file and `peal record ID plan` commits it. In the files storage, `peal_store_record` commits that onto the task's claim branch (the copy under `doing/`), so main sees it only once the task merges.

So while a task is claimed, the board shows only the `touches` it was filed with (from `/peal:idea`, often none), and Belfry has only that plus the files the worker reports. The issues storage has no such gap: its `peal_store_record` (`plugin/lib/store-issues.sh`) rewrites the issue's labels at record time, `touches: <path>` among them, so the board sees the planner's `touches` at once.

`peal_store_read` in the files storage already prefers a branch's copy of the task over main's; `peal_store_list` does not.

Draft plan of 2026-09-26 superseded by the agreed `## Plan` below (re-checked against the code 2026-10-20: the draft's "local wins over remote" and "fall back on a parse failure" did not hold as written).

Human's answers, 2026-10-20:
1. Touches: store-files.sh, store-files.test.sh, work.test.sh, docs/design.md; work.md, board.awk, task-scan.awk, task-state.awk and store-issues.sh stay untouched.
2. Fields from the branch: size, plan, touches, merge (`plan` raw; `model` left out, it is not on the board).
3. `peal record` keeps not pushing: design.md says remote-only readers see recorded fields after the next push; an idea is filed for pushing at record.
4. Overlay only non-empty values from the copy: a parse failure falls back to main's naturally; a value removed on the branch shows main's until merge. `task-scan.awk` unchanged.
5. Discard every warning from the copies' scan except the yaml parse failure, left as is (no branch name).
6. The copy comes from the ref the claim was read from (local for wt, parked and local awaiting-merge; remote for the deferred-local case, the not-ahead-of-main case and remote-only claims), matched by id whatever its slug. `peal_store_read` is left alone. No timing test.
7. work.test.sh: fix the stale comment and extend the files branch so `record` then `board` shows the touches.
8. Tests in store-files.test.sh (header adjusted); docs in design.md only, not docs/reference/tasks.md.

## Plan

Approach:
1. `_peal_files_claims` takes a third argument COPIES (a temp dir). For each claim line it emits, it picks the ref that claim came from (local ref for wt, parked and local awaiting-merge claims; the remote ref at the deferred-local case, the not-ahead-of-main case and remote-only claims) and writes that ref's copy of the task to `COPIES/<path>` with `git show "$ref:$path"`.
2. `$path` comes from `_peal_files_find`'s ranking (done/ over doing/ over backlog/), its awk factored into a helper reading a listing on stdin. The existing per-claim `git ls-tree` (done/ only today) widens to `-r` over `$PEAL_TASKS/`, so one listing answers both the done/ check and the path; a claim read from another ref than `$ref` lists that ref separately. Bad-slug warnings from this lookup are silenced.
3. `peal_store_list` runs `task-scan.awk` once over COPIES (same find/awk invocation as `_peal_files_scan`), drops its warnings except the yaml parse failure, then a small awk step joins those records onto main's by id, replacing fields 9 (size), 10 (plan), 16 (touches) and 17 (merge) only where the copy's value is non-empty, before `task-state.awk` runs unchanged. State, title, milestone, depends, part-of and path stay main's.
4. `board.awk`, `task-scan.awk`, `task-state.awk`, `store-issues.sh`, `work.md` unchanged.
5. Docs: store-files.sh header; `docs/design.md` `touches` paragraph and the Storage table's `list` row: a claimed task's recorded fields come from its claim's copy, and reach other clones only once the branch is pushed.

Rejected: extra columns on the claim lines (changes the shared format `task-state.awk` and `_peal_files_prs` read); `_peal_files_scan` per claim (claims x tasks); `peal record` writing onto main (breaks the lock); one `git cat-file --batch` (not worth it at a few claims).

Files: plugin/lib/store-files.sh, plugin/lib/store-files.test.sh, plugin/lib/work.test.sh, docs/design.md.

Verification: a new case `claim_copies` in `store-files.test.sh` under `for_each_awk`, building claims as tasks.test.sh does, checking `peal board` JSON and `peal list --no-pr`:
- local claim with a worktree: the branch's touches, size and `merge: auto` show; title, milestone, path main's; claimed-live, detail `wt:`;
- remote-only claim (local branch deleted after push): remote's copy, detail `remote:origin`;
- parked claim: copy from the local branch, renamed copy matched by id;
- awaiting-merge claim: copy under done/ on the branch, state awaiting-merge, fields the branch's;
- deferred local branch with a new claim on the remote: the remote's copy, not the stale local one;
- a depends added only on the branch: state and depends stay main's;
- fallbacks: unclaimed task, branch tip without the file, branch copy with broken frontmatter (main's fields, parse warning shown once);
- `peal list` lines unchanged in form.
`tasks.test.sh` and the extended `work.test.sh` (files: record then board shows the touches) pass.

Ranges:
- plugin/lib/store-files.sh:1-5, 49-70, 82-100, 102-116, 118-134, 147-199, 238-259, 268-282, 1185-1192
- plugin/lib/task-scan.awk:1-27, 29-48, 106-108
- plugin/lib/yaml-lib.awk:17-20, 132-134
- plugin/lib/task-state.awk:1-16, 145-163
- plugin/lib/board.awk:1-33
- plugin/lib/work.sh:135-186
- plugin/commands/work.md:99-110
- plugin/lib/store-files.test.sh:1-21, 510-537, 577-595
- plugin/lib/task-fixtures.sh:12-78
- plugin/lib/tasks.test.sh:37-101
- plugin/lib/work.test.sh:172-199
- docs/design.md:252-254, 263-268, 497-511
- docs/reference/tasks.md:40-54

---

## Outcome

