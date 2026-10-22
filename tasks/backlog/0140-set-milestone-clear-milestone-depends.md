---
plan: required
touches: [plugin/lib/store-files.sh, plugin/lib/store-issues.sh]
milestone: m8
---

# 0140 — set-milestone: refuse clearing the milestone of a task whose depends holds `milestone`

## Intent

`peal set-milestone ID` with no M takes a task out of its milestone. If the task's depends holds the `milestone` keyword, the move leaves a task that waits on "its milestone" without having one. `peal create` refuses that frontmatter ("depends: milestone needs a milestone"). Task-state only warns about it and ignores the dependency. set-milestone should refuse such a clearing too, in both storages (task files and issues), so the frontmatter create forbids cannot be reached by a move.

## Scope

## Done when

## Raw

> set-milestone ID with no M (clearing the milestone) on a task whose depends holds `milestone` goes through, though create refuses that frontmatter ("depends: milestone needs a milestone"); task-state then only warns and ignores it. set-milestone should refuse clearing the milestone of such a task, in both storages. Found in 0055.

## Notes

Found in 0055, which added the depends-cycle check to `peal_store_set_milestone` in both storages. The create refusal is tested in `plugin/lib/store-files.test.sh` (the "depends: milestone needs a milestone" case).

Open questions:
- Should revise and defer also refuse a text that keeps `milestone` in depends and drops the milestone, if they do not already?
- Should the refusal suggest dropping `milestone` from depends first?

Context: `docs/design.md` (depends and the `milestone` keyword), `docs/reference/cli.md` (`peal set-milestone`).

---

## Outcome

<!-- Written at close, replacing this comment. -->
