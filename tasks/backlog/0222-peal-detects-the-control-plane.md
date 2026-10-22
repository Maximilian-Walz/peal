---
milestone: m9
plan: auto
size: S
depends: []
touches: [plugin/commands/idea.md, plugin/commands/defer.md, plugin/commands/comment.md, docs/design.md, docs/guides/belfry.md]
---

# 0222 — Peal detects the control plane by the tools it is offered, not by BELFRY_SESSION

## Intent

`/peal:idea` decides between filing directly and calling the control plane's `task_create` or `idea` tool by testing the environment variable `BELFRY_SESSION` (`plugin/commands/idea.md`), which the control plane's contract never names; `close.md` already keys on the presence of the `wait_ci` tool, which it does. The control plane's #703 states one rule: a project's tooling detects it by the tools offered (`task_create`, `idea`, `wait_ci`, `pr_create`), or names the variable in the contract. When this is done Peal's commands follow that rule the same way everywhere.

## Scope

- `plugin/commands/idea.md`, `defer.md`, `comment.md` and any other command that reads `BELFRY_SESSION`: the control-plane branch is taken when the tool it needs is listed; `docs/design.md`'s "deliberate exception" paragraph and `docs/guides/belfry.md` follow.
- If #703 keeps the variable in the contract instead, this task becomes a docs line and closes.

## Done when

- `commands.test.sh` asserts no command text tests `BELFRY_SESSION` (or, if the contract names it, that the docs say so).
- `docs/guides/belfry.md` states how Peal tells it is under the control plane.

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Waits for the control plane's #703 (Belfry on Peal milestone); note its decision here before planning.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
