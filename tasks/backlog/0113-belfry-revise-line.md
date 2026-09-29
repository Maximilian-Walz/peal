---
milestone: m2
plan: skipped
size: S
depends: []
---

# 0113 — Peal's own .belfry.yml maps tasks.commands.revise to /peal:comment

## Intent

Once the release that ships `/peal:comment` (0103) is installed, add `revise: /peal:comment {task} {text}` to this repository's `.belfry.yml`, so triage "add" verdicts land in Notes. Then re-run triage on the items left waiting (0067, 0068) and check a dated line lands.

## Scope

- The one `revise:` line in `.belfry.yml`, matching what `peal init --stage belfry` writes.

## Done when

- A triage "add" verdict for a free task lands as a dated line in its Notes.

## Raw

Split from 0103 by the human, 2026-09-29: Peal's own line after the release that ships the command.

---

## Outcome

<!-- Written at close, replacing this comment. -->
