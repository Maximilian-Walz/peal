---
plan: required
---

# 0263 — In-tree attributes shape the work-tree copies of task files Peal checks

## Intent

Task 0239 made Peal read main's task, milestone and decision files as committed blobs, so an in-tree `.gitattributes` no longer changes what Peal reads from main. A checkout still applies in-tree attributes to work-tree copies, though: `text`/`eol`, `ident` and `working-tree-encoding`. `peal check` and the git hooks read those work-tree files. So a `.gitattributes` merged under the auto-merging `tasks/**` or `docs/**` tier might make the work-tree text differ from the blob a reviewer saw. Find out whether that can change what the checks and hooks decide, and close the route if it can, for example by reading the index or blobs, or by refusing such attributes.

## Scope

## Done when

## Raw

> Checkout also applies in-tree attributes (`text`/`eol`, `ident`, `working-tree-encoding`) to work-tree task files, which `peal check` and the hooks read. It is outside this task, which is about reads from main.

(The planner of task 0239 raised this. At planning, the human agreed to file it as an idea.)

## Notes

- Context: `docs/security.md` (the auto-merge tiers, and the "Closed by 0239" limit); task 0239's Outcome.
- Open question: which readers in `peal check` and the hooks read work-tree files instead of the index, and whether `ident` or `working-tree-encoding` can introduce a frontmatter key.
