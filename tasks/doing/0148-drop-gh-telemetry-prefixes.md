---
milestone: m3
plan: required
depends: [0145]
touches: [plugin/commands/close.md, plugin/commands/next.md, plugin/commands/setup.md, plugin/lib/close.sh]
---

# 0148 — Check the env-file line live, then drop the gh telemetry prefixes

## Intent

0145 turned gh's telemetry off for agent-run gh calls in two ways. Peal's SessionStart hook writes `export GH_TELEMETRY="${GH_TELEMETRY:-0}"` to Claude Code's `CLAUDE_ENV_FILE`. As a fallback, because the env file could not be shown to reach Bash in headless sessions, the gh calls in the command markdown and the printed fallback got `GH_TELEMETRY=0` prefixes. Once 0145 is merged, check live whether the env-file line reaches Bash in interactive, headless and subagent sessions. If it does, remove the prefixes: they override a user's own `GH_TELEMETRY` and may stop matching users' allow rules such as `Bash(gh pr create:*)`, which would cause permission prompts.

## Scope

## Done when

## Raw

> After 0145 merges, check live that the SessionStart hook's CLAUDE_ENV_FILE line reaches Bash in interactive, headless and subagent sessions (echo $GH_TELEMETRY prints 0; a sandboxed gh pr checks logs no deny for cafe.github.com). If it does, drop the GH_TELEMETRY=0 prefixes 0145 added as a fallback to close.md, next.md, setup.md and the fallback printed by plugin/lib/close.sh: they override a user's own GH_TELEMETRY and may stop matching allow rules like Bash(gh pr create:*), causing permission prompts. Found in 0145.

## Notes

- Split off 0145 (m3); its Outcome and Notes record the fallback and why.
- Open question: if the line reaches interactive sessions but not headless or subagent ones, should the prefixes stay, or should they move to the `${GH_TELEMETRY:-0}` form?
- Context: `docs/security.md` §"`gh` holds the token".

---

## Outcome

<!-- Written at close, replacing this comment. -->
