---
plan: required
touches: [plugin/commands/close.md]
---

# 0067 — Close waits for CI with Belfry's wait_ci when that tool exists

## Intent

`/peal:close` waits for the pull request's checks with `peal close wait`, which polls GitHub in rounds of up to ten minutes and answers `WAIT:checks-pending` (exit 3) until they settle. Under Belfry, the session has a `wait_ci` tool that waits on Belfry's own view of the pull request and spends none of the human's GitHub budget. When this is done, close uses `wait_ci` when the tool exists and keeps `peal close wait` otherwise, the way Peal already treats Belfry's gallery tool: used when present, never required.

## Scope

- `plugin/commands/close.md`'s wait step, and the same in any other command that waits for checks.
- `peal close wait` stays for sessions without Belfry.

## Done when

- The close command's prompt harness covers both branches (with and without the tool).
- Peal's docs mention the rule where they describe close.

## Raw

From Belfry's Friction page: `peal close wait` answering `WAIT:checks-pending` seven times in two sessions.

## Notes


---

## Outcome

