---
plan: required
touches: [.belfry.yml, plugin/commands/setup.md]
milestone: m2
---

# 0103 — Belfry can add to a Peal task: `tasks.commands.revise` in .belfry.yml and the belfry stage

## Intent

Belfry's triage can propose adding text to an open task, but it carries that out only through `tasks.commands.revise`, which Peal's `.belfry.yml` does not set. Such verdicts stay in the idea box ("the project has no tasks.commands.revise to add to a task file with"), and every triage has to fall back to filing or dismissing. The CLI already has `peal comment ID TEXT`, which adds a dated line to an unclaimed task's Notes. When this is done, Peal's own `.belfry.yml` maps `tasks.commands.revise` to it, and `/peal:setup belfry` writes the same key for other projects.

## Scope

- `.belfry.yml`: `revise:` mapped to `.peal/peal comment` with the placeholders Belfry's contract uses for the task and the text.
- `/peal:setup`'s belfry stage writes the key too.
- What happens when the task is claimed (comment refuses on the files storage): the answer Belfry gets, and whether that is enough.

## Done when

- A triage "add" verdict for a free task lands as a dated line in its Notes.
- The setup harness checks that the belfry stage writes `revise:`.

## Raw

Belfry friction, 2026-09-28 (job ed32ea91d6438608): two "add" verdicts for 0067 and 0068 were left waiting because `.belfry.yml` has no `tasks.commands.revise`. Proposed fix: map it to `.peal/peal comment {task} {text}` and add it to the belfry stage of /peal:setup.

## Notes

- Open question: the exact placeholder names Belfry passes to `revise` (read Belfry's contract docs), and whether text from outside needs `--origin` as `create` does (compare 0083, 0095).

---

## Outcome

<!-- Written at close, replacing this comment. -->
