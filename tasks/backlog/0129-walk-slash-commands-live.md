---
milestone: m3
plan: skipped
depends: [0123]
---

# 0129 — Walk the slash commands live on a scratch repository

## Intent

Task 0118 walked the README to a first task with the CLI only. Walk `/peal:setup`, `/peal:work` and `/peal:close` in a live Claude Code session on a scratch repository, following the rewritten README and docs/getting-started.md alone, and record where a newcomer would stall.

## Scope

- The live walk and fixes to the two documents for what it finds.

## Done when

- The walk reached a closed task using only those two documents, or each stall is fixed or filed.

## Raw

> The slash-command half of 0118 walk was not done; walk it once the rewrite lands.
(task 0123 Notes)

## Notes

Deferred 2026-10-18 after a claim: the rewrite it walks (0123, PR #216) has not merged

- Queued by the implementer of 0123.
- Depends on 0123 (README and getting-started rewrite, PR #216): the walk follows the
  rewritten documents, and fixes to them would conflict with that pull request while it
  is open. Claimed once before 0123 merged and given back with nothing built.
