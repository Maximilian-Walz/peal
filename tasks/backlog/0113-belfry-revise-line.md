---
milestone: m2
plan: skipped
size: S
depends: [human]
---

# 0113 — Peal's own .belfry.yml maps tasks.commands.revise to /peal:comment

## Intent

Once the release that ships `/peal:comment` (0103) is installed, add `revise: /peal:comment {task} {text}` to this repository's `.belfry.yml`, so triage "add" verdicts land in Notes. Then re-run triage on the items left waiting (0067, 0068) and check a dated line lands.

## Scope

- The one `revise:` line in `.belfry.yml`, matching what `peal init --stage belfry` writes.

## Done when

- A triage "add" verdict for a free task lands as a dated line in its Notes.

## Notes

Deferred 2026-09-29 after a claim: waits on an installed Peal release that ships /peal:comment (0103); the newest installed, 0.2.0, predates it

- 2026-09-29, first claim: blocked. The newest release, v0.2.0, and the installed plugin (0.2.0) both predate 0103, so the installed plugin has no `commands/comment.md`. Adding the line before that would make triage "add" verdicts call a command that doesn't exist. The human chose to defer. `depends: human` stands for "cut a release (`/peal:release`) and update the installed plugin". Once `/peal:comment` shows up in the installed plugin, drop `human` from depends and claim again.
- The line to add, under `tasks.commands` (as `plugin/lib/setup.test.sh` and `plugin/lib/init.test.sh` expect): `    revise: /peal:comment {task} {text}`.

## Raw

Split from 0103 by the human, 2026-09-29: Peal's own line after the release that ships the command.

---

## Outcome

<!-- Written at close, replacing this comment. -->
