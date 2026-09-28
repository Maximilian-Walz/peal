---
milestone: m2
plan: required
---

# 0014 — Migration from an existing task-file process

## Intent

A project with its own task-file process adopts Peal by migrating, not rewriting: tasks
keep their numbers, history stays, the project's own tooling keeps working through the
extension points. See `docs/design.md`, "Migrating an existing project".

## Scope

- `peal migrate headers`: rewrites `key: value` task headers (trailing comments, space-
  or comma-separated lists) into frontmatter; maps the pools to milestones (numbered
  milestone to its id, unassigned to none, a never-offered pool to a `parked` milestone,
  a by-name-only pool to an `open` one); reports what it cannot convert; changes nothing
  else in the file.
- `peal migrate milestones`: frontmatter for existing milestone docs (newest `current`,
  earlier `done`) plus the milestones the pools need.
- `docs/migrating.md`: the whole procedure, including which pieces a project keeps and
  how its checks, context documents, PR sections and reviewer rules move into `.peal/`.

## Done when

- Both converters run clean over a copy of the reference project's `tasks/` and
  milestone docs (read from its main branch, never edited), and `peal list` and `peal
  board` there agree with the reference's own task-state and board output, state for
  state.

## Raw

Filed as issue #14 (https://github.com/Maximilian-Walz/peal/issues/14); its text is carried over into the sections above and below.

## Notes

The migration of the reference project itself is a task of its own, in that project.

---

## Outcome

