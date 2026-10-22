---
milestone: m9
plan: auto
size: S
depends: []
priority: normal
touches: [plugin/lib/apply.sh, plugin/lib/apply.awk, docs/reference/]
---

# 0230 — peal apply updates a milestone's goal and acceptance criteria

## Intent

`peal apply` creates a milestone with a goal but can update only its order, title, due
date and state. A plan that rewrites a milestone's goal or acceptance criteria (the
re-plan of 2026-10-22 did for five) has no route but a hand edit or a task of its own,
so a batch cannot carry a whole re-plan. When this is done, `milestone_update` (and
`milestone_create`) take `goal` and `acceptance` (a list of lines), written into the
milestone file the way the milestone template has them, with the same validation as
other text from a proposal.

## Scope

- `milestone_update` and `milestone_create` in `plugin/lib/apply.sh` / `apply.awk`:
  `goal` (one paragraph) and `acceptance` (a list of one-line criteria), replacing the
  file's sections; refused where a line would break the file's structure (a `---` or
  `## ` line), like `milestone_create`'s goal today.
- `docs/reference/` (apply's kinds and fields).
- Text from outside: these fields come from a proposal the human accepted; they are
  data, quoted as such where shown.

## Done when

- A batch with `milestone_update` carrying `goal` and `acceptance` rewrites both sections
  of the milestone file in one commit; a test asserts it, and one that a `## ` line in
  either is refused.
- `milestone_create` accepts `acceptance` too.
- The reference documents both fields.

## Raw

> both, file the text task and the apply extension

## Notes

Belfry's contract names `milestone_update` as "renames it or moves its due date"; if
Belfry's planning should propose goals and criteria too, that is a contract change on
Belfry's side (an issue there), not part of this task.
