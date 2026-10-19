---
plan: required
touches: [plugin/lib/store-files.sh, plugin/lib/store-files.test.sh, plugin/lib/store-issues.sh, plugin/lib/store-issues.test.sh, plugin/lib/tasks.sh, docs/design.md, docs/reference/cli.md]
milestone: m3
size: S
---

# 0055 — set-milestone: refuse a depends cycle, like file, revise and defer

## Intent

In both storages' `peal_store_set_milestone`, run `peal_cycle_check` before anything is written or pushed. The changed row is the task's own row with only its milestone set to M, or cleared when M is not given. Its depends and part-of stay as they are. The verb is `set-milestone`, so a refusal reads `set-milestone: refused: depends cycle 0042 → 0043 → 0042` (`#42 → #43 → #42` on issues) and exits 1.

- Task files: build the row from the task text with the new milestone in place, for example by running `peal_cycle_check_text set-milestone` on a copy rewritten by `_peal_files_rewrite_milestone`. Do this before `peal_push_main`.
- Issues: reuse the records `_peal_issues_unclaimed` has already read (`PEAL_RECORDS`) and check before the PATCH.

As with the other verbs, a cycle that was already there and that the task was already on does not refuse the move. A task that depends on its own milestone is not a cycle.

Update the "A depends cycle is refused" paragraph in `docs/design.md` to name set-milestone next to filing, revising and deferring.

## Done when

- `peal set-milestone` refuses, with exit 1 and the cycle named, a move that puts the task on a depends cycle it was not on before, for task files and for issues
- Nothing is pushed on a refusal (task files), and the issue's milestone stays unchanged (issues)
- Tests in `plugin/lib/store-files.test.sh` and `plugin/lib/store-issues.test.sh`: two tasks with `depends: [milestone]` moved into one milestone are refused. A move that closes no cycle, and a move of a task already on a hand-made cycle, go through.
- `docs/design.md` names set-milestone among the verbs that refuse a cycle

## Raw

Filed as issue #55 (https://github.com/Maximilian-Walz/peal/issues/55) from an idea a session had; its text is carried over into the sections above.

## Notes

Deferred 2026-09-28 after a claim: stale claim: its session stopped; given back so auto mode picks it up again

#26 refuses a depends cycle wherever a task text is filed, revised or deferred (`docs/design.md`, "A depends cycle is refused"). The check is `peal_cycle_check` in `plugin/lib/tasks.sh`. `_peal_cycle_row` builds a changed row (id, milestone, depends, part-of) and `peal_cycle_check` swaps it into the store's list records. It refuses with exit 1 only when the changed task lies on a cycle it was not on before. The callers today:

- `peal_cycle_check_create`: file and split (`store-files.sh`, `store-issues.sh`)
- `peal_cycle_check_text`: revise and defer (`_peal_files_text_checks` in `store-files.sh`, `_peal_issues_rewrite` in `store-issues.sh`, `backlog.sh`)

`peal set-milestone ID [M]` (`plugin/bin/peal`) goes to `peal_store_set_milestone` and does not run this check in either storage:

- `plugin/lib/store-files.sh`: it checks that M exists and is not done, then rewrites the frontmatter through `_peal_files_rewrite` / `_peal_files_rewrite_milestone` and pushes.
- `plugin/lib/store-issues.sh`: it checks the same things, then PATCHes the issue's milestone.

A milestone change can still close a cycle, because the read model expands the `milestone` keyword in `depends` to every other task of that milestone. For example, take two tasks that both have `depends: [milestone]`, such as two review tasks. Moving one into the other's milestone makes each wait on the other. Every task on that cycle then stays blocked for ever. Only `list`/`board`/`peal check` show it afterwards, as a cycle made by hand. `/peal:milestone-review` tells the agent to use `peal set-milestone`, so this path is a normal one.

Proposed plan, not yet agreed (2026-09-26). The planning session's questions timed out twice, so the plan went to the human as a human task for review:

- `plugin/lib/tasks.sh`: new `peal_cycle_check_milestone VERB ID M [RECORDS]`. It takes the task's own list record with only the milestone replaced (M, or empty) and depends/part-of kept, then calls `peal_cycle_check`.
- `store-issues.sh` `peal_store_set_milestone`: run it with `PEAL_RECORDS` before the PATCH.
- `store-files.sh`: `_peal_files_rewrite` gets an optional CHECK argument, run after `_peal_files_unclaimed` and before `peal_push_main`. set-milestone passes `_peal_files_check_milestone`.
- Tests in `cycles()` of both test files:
  - two `depends: [milestone]` tasks moved into one milestone are refused, and nothing is pushed or changed;
  - a move that closes no cycle goes through;
  - a task already on the hand-made cycle goes through.
- `docs/design.md` "A depends cycle is refused" names set-milestone; add it to touches. `plugin/bin/peal` needs no change.
- Size S, model default, merge default.
- Open questions, each with its proposed default:
  - record-based row rather than text-based for files;
  - keep the per-task "already on a cycle" rule;
  - check even when clearing;
  - no re-check on a push retry;
  - refusal order: milestone, task state, cycle, "already";
  - no edit to milestone-review.md or store.sh (named in the Outcome as a follow-up);
  - the issue test count at line 596 goes from 4 to 6.

Answers from the human, 2026-10-19, when the plan was agreed:

- Keep `peal_cycle_check`'s per-task rule: a task already on a cycle may move even if the move closes another.
- Add one sentence about the refusal to `docs/reference/cli.md`'s set-milestone section.
- Check when clearing too, and re-check on each push retry (task files).
- Refusal order as listed in the Plan.
- The gap where `set-milestone ID` with no M on a task with `depends: [milestone]` goes through: file an idea at close and name it in the Outcome; no change here.
- Leave `plugin/lib/store.sh`'s interface comment and the milestone-review command text unchanged.
- Keep the shared hint line of `peal_cycle_check`.
- Size S, model default, merge default.

## Plan

Agreed 2026-10-19. `peal apply`'s move and split_milestone kinds need no change: `_pa_check` already checks every changed row's cycle, milestone-only changes included.

**Task files** (`plugin/lib/store-files.sh`):
- `_peal_files_rewrite_milestone` (only caller: set-milestone) runs `peal_cycle_check_text set-milestone "$id" "<new text>"` after writing the new milestone. The id comes from a global (e.g. `PEAL_MS_ID`) set beside `PEAL_NEW_MILESTONE` in `peal_store_set_milestone`, not from dynamic scoping.
- The check runs inside the `peal_push_main` build (`_peal_files_build_rewrite`), so it comes before `peal_write_tree`, the commit and any push, and runs again on each retry.
- `_peal_files_build_rewrite` must pass a status of 1 through (it maps every failure to 2 today), so the refusal exits 1. Comment's rewrite returns only 2 and is unaffected.
- Refusal order: milestone missing or done, task claimed or not in the backlog, cycle, "already reads so".

**Issues** (`plugin/lib/store-issues.sh`, `peal_store_set_milestone`):
- After the "already", unknown and done milestone checks and before the PATCH, build the row from `PEAL_RECORD`: field 1 (id), new M (or empty), field 7 (depends), field 8 (part-of).
- Check it against `PEAL_RECORDS` through a new helper in `plugin/lib/tasks.sh` beside `peal_cycle_check_text`, e.g. `peal_cycle_check_row VERB ROW RECORDS` (temp files, then `peal_cycle_check`). Return 1 on a refusal.

**Docs:**
- `docs/design.md` "A depends cycle is refused" names set-milestone next to filing, revising and deferring.
- `docs/reference/cli.md` set-milestone section: one sentence on the refusal.

**Verification:**
- `plugin/lib/store-files.test.sh` `cycles()`:
  - add `put "$work" backlog 0007 other-review "milestone: m1" "depends: [milestone]"` before `before=`;
  - `check_fails "cycle: set-milestone" 1 "set-milestone: refused: depends cycle 0007 → 0004 → 0007" peal set-milestone 0007 m2` before the "nothing pushed" check (confirm the cycle string's starting id);
  - `peal set-milestone 0003 m2` exits 0;
  - after 0001/0002 are made a hand-made cycle, `peal set-milestone 0002 m1` exits 0.
- `plugin/lib/store-issues.test.sh` `cycles()`:
  - issues 5 (m1) and 6 (m2), each with body "Depends on milestone";
  - `peal set-milestone 5 m2` refused with `#5 → #6 → #5`, and issue 5's milestone stays m1;
  - `peal set-milestone 4 m2` exits 0;
  - `peal set-milestone 1 m1` (on hand-made #1 ↔ #2) exits 0;
  - the `length` expectation goes from 4 to 6 (add the new issues after the "cycles: list" checks, or extend those).
- Run both test files and `shellcheck` on the changed scripts.

Ranges: tasks.sh:103-113, tasks.sh:199-294, task-state.awk:117-125, store-files.sh:463-479, store-files.sh:496-514, store-files.sh:803-874, store-issues.sh:549-573, store-issues.sh:604-619, store-issues.sh:810-830, main-write.sh:109-186, main-write.sh:382-384, apply.sh:710-794, apply.sh:912, bin/peal:412-418, bin/peal:511, store-files.test.sh:211, store-files.test.sh:477-488, store-files.test.sh:539-570, store-issues.test.sh:594-601, store-issues.test.sh:786-808, docs/design.md:244-246, docs/reference/cli.md:256-257, docs/reference/cli.md:291-293, docs/reference/cli.md:446 (paths under `plugin/lib/` and `plugin/` unless named).

---

## Outcome

