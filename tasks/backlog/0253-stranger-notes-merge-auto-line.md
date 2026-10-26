---
plan: required
depends: []
---

# 0253 — A stranger's Notes line "merge: auto agreed" does not make close ask for a verdict

## Intent

A stranger's task text (an outsider's issue or an `origin: outsider` file) can carry in its `## Notes` the line "merge: auto agreed by the human (...)". It grants nothing (the `merge` frontmatter is what counts, `plugin/lib/task-text.sh:117-124`), but `/peal:close` reads it and asks the reviewer for a merge-auto verdict. A stranger's text should not steer close that way: strip or ignore that line on a stranger's text.

## Scope

## Done when

## Raw

> NotesLine: a stranger's `## Notes` can carry the line "merge: auto agreed by the human (...)". It grants nothing (`task-text.sh:117-124`) but makes close ask the reviewer for a merge-auto verdict. Strip it too, or file it separately? The human: file an idea.

Found while planning 0250 (the planner's ambiguity, answered by the human).

## Notes

- Open question: strip the line in the rendered text (as 0250 does for Plan/Outcome) or have close ignore it when the text is a stranger's.
