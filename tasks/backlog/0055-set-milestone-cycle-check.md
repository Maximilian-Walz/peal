---
plan: required
touches: [plugin/bin/peal, plugin/lib/store-files.sh, plugin/lib/store-files.test.sh, plugin/lib/store-issues.sh, plugin/lib/store-issues.test.sh, plugin/lib/tasks.sh]
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

#26 refuses a depends cycle wherever a task text is filed, revised or deferred (`docs/design.md`, "A depends cycle is refused"). The check is `peal_cycle_check` in `plugin/lib/tasks.sh`. `_peal_cycle_row` builds a changed row (id, milestone, depends, part-of) and `peal_cycle_check` swaps it into the store's list records. It refuses with exit 1 only when the changed task lies on a cycle it was not on before. The callers today:

- `peal_cycle_check_create`: file and split (`store-files.sh`, `store-issues.sh`)
- `peal_cycle_check_text`: revise and defer (`_peal_files_text_checks` in `store-files.sh`, `_peal_issues_rewrite` in `store-issues.sh`, `backlog.sh`)

`peal set-milestone ID [M]` (`plugin/bin/peal`) goes to `peal_store_set_milestone` and does not run this check in either storage:

- `plugin/lib/store-files.sh`: it checks that M exists and is not done, then rewrites the frontmatter through `_peal_files_rewrite` / `_peal_files_rewrite_milestone` and pushes.
- `plugin/lib/store-issues.sh`: it checks the same things, then PATCHes the issue's milestone.

A milestone change can still close a cycle, because the read model expands the `milestone` keyword in `depends` to every other task of that milestone. For example, take two tasks that both have `depends: [milestone]`, such as two review tasks. Moving one into the other's milestone makes each wait on the other. Every task on that cycle then stays blocked for ever. Only `list`/`board`/`peal check` show it afterwards, as a cycle made by hand. `/peal:milestone-review` tells the agent to use `peal set-milestone`, so this path is a normal one.

---

## Outcome

