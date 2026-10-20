---
plan: required
depends: [human]
---

# 0146 — Under Belfry, close opens its pull request through Belfry's pr_create tool

## Intent

Belfry is to open its sessions' pull requests as its GitHub App, through a `pr_create` tool, so the human is not their author and GitHub stops mailing them for every comment Belfry makes (Maximilian-Walz/belfry#575). Belfry's sandbox hook will then refuse `gh pr create` in a session it runs. Peal opens pull requests itself: `close finish` in `plugin/lib/close.sh`, the draft step in `plugin/commands/close.md` (`gh pr create --draft`), the by-hand fallback `_peal_close_by_hand`, and `next.md` for its config changes. Under Belfry (a session that has Belfry's tools), these should open the pull request through `pr_create`, with the same title, body and draft state. Everywhere else they keep using `gh pr create`.

## Scope

## Done when

## Raw

> Belfry will open its sessions' PRs as its app through a pr_create tool (belfry#575) and refuse gh pr create in its sessions. Peal's close (close.sh finish, close.md's draft step, the by-hand fallback) and next.md open PRs with gh pr create themselves; under Belfry they should go through pr_create, and stay on gh elsewhere.

## Notes

- Waits for belfry#575 (the `depends: [human]` hold): agree the tool's name and fields there before building, then lift the hold.
- Open question: `close finish` is a shell script, and a script cannot call an MCP tool. Either close.md has the session call `pr_create` and hand the number back to `close finish`, or finish stops before opening and says what to open.

---

## Outcome

<!-- Written at close, replacing this comment. -->
