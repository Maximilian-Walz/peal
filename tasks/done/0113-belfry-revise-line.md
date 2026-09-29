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

## Notes

Deferred 2026-09-29 after a claim: waits on an installed Peal release that ships /peal:comment (0103); the newest installed, 0.2.0, predates it

- 2026-09-29, first claim: blocked. The newest release, v0.2.0, and the installed plugin (0.2.0) both predate 0103, so the installed plugin has no `commands/comment.md`. Adding the line before that would make triage "add" verdicts call a command that doesn't exist. The human chose to defer. `depends: human` stands for "cut a release (`/peal:release`) and update the installed plugin". Once `/peal:comment` shows up in the installed plugin, drop `human` from depends and claim again.
- The line to add, under `tasks.commands` (as `plugin/lib/setup.test.sh` and `plugin/lib/init.test.sh` expect): `    revise: /peal:comment {task} {text}`.
- Revised 2026-09-29: `human` dropped from depends. The installed plugin now ships `/peal:comment` (its `commands/comment.md` matches main's), so the wait is over and a claim is no longer refused as blocked.

## Raw

Split from 0103 by the human, 2026-09-29: Peal's own line after the release that ships the command.

---

## Outcome

Built: `.belfry.yml` now maps `tasks.commands.revise` to `/peal:comment {task} {text}`, under `tasks.commands` right after `retire:`. It is the exact line `peal init --stage belfry` writes (`plugin/lib/init.sh`, asserted by `plugin/lib/init.test.sh` and `plugin/lib/setup.test.sh`). The installed plugin (0.2.0 in the plugin cache) ships `commands/comment.md`, byte-identical to main's. The line no longer points at a missing command, which was why the first claim was deferred.

Nothing else changed; no decision was made beyond the mapping 0103 already documents. The reviewer found the change correct and in scope.

Next session: Belfry reads `.belfry.yml` from the default branch, so the one `## Done when` line can only be observed after this merges. Re-run triage on the items left waiting (0067, 0068). Then check that an "add" verdict lands as a dated line in the task's Notes. If it does not, the fault is in the Belfry contract or in `/peal:comment`, not in this line.

### Escalations

- The `## Done when` line ("a triage add verdict for a free task lands as a dated line in its Notes") cannot be met before merge: Belfry reads the contract from the merged default branch. It is left to the human as a post-merge check: re-run triage on 0067 and 0068 and look for the dated line.
