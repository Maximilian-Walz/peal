---
milestone: m3
plan: required
depends: [0145]
touches: [plugin/commands/close.md, plugin/commands/next.md, plugin/commands/setup.md, plugin/lib/close.sh, plugin/lib/close.test.sh, docs/security.md]
size: S
---

# 0148 — Check the env-file line live, then drop the gh telemetry prefixes

## Intent

0145 turned gh's telemetry off for agent-run gh calls in two ways. Peal's SessionStart hook writes `export GH_TELEMETRY="${GH_TELEMETRY:-0}"` to Claude Code's `CLAUDE_ENV_FILE`. As a fallback, because the env file could not be shown to reach Bash in headless sessions, the gh calls in the command markdown and the printed fallback got `GH_TELEMETRY=0` prefixes. Once 0145 is merged, check live whether the env-file line reaches Bash in interactive, headless and subagent sessions. If it does, remove the prefixes: they override a user's own `GH_TELEMETRY` and may stop matching users' allow rules such as `Bash(gh pr create:*)`, which would cause permission prompts.

## Scope

Drop the `GH_TELEMETRY=0` prefixes 0145 added to the gh calls in `plugin/commands/close.md`,
`next.md`, `setup.md` and to the by-hand line `plugin/lib/close.sh` prints; drop the fallback
clause from `docs/security.md`; tighten `plugin/lib/close.test.sh` against the prefix
returning. The SessionStart hook's env-file line stays the only mechanism.

## Done when

- No `GH_TELEMETRY=0` prefix remains in `plugin/commands/*.md` or in `close.sh`'s printed fallback.
- `docs/security.md` no longer mentions a fallback prefix.
- `plugin/commands/commands.test.sh`, `plugin/lib/close.test.sh` and `plugin/bin/peal.test.sh` pass.
- The Outcome states what was observed live for headless, interactive and subagent sessions.

## Raw

> After 0145 merges, check live that the SessionStart hook's CLAUDE_ENV_FILE line reaches Bash in interactive, headless and subagent sessions (echo $GH_TELEMETRY prints 0; a sandboxed gh pr checks logs no deny for cafe.github.com). If it does, drop the GH_TELEMETRY=0 prefixes 0145 added as a fallback to close.md, next.md, setup.md and the fallback printed by plugin/lib/close.sh: they override a user's own GH_TELEMETRY and may stop matching allow rules like Bash(gh pr create:*), causing permission prompts. Found in 0145.

## Notes

- Split off 0145 (m3); its Outcome and Notes record the fallback and why.
- Open question: if the line reaches interactive sessions but not headless or subagent ones, should the prefixes stay, or should they move to the `${GH_TELEMETRY:-0}` form?
- Context: `docs/security.md` §"`gh` holds the token".
- 2026-10-21, live evidence gathered before planning: this machine's installed plugin
  (0.2.0) predates 0145, so this session could not probe itself. 43 recent sessions of
  another project running a Peal build with 0145 have the line in their env file: 42
  headless sandboxed Belfry jobs (entrypoint `sdk-cli`) ran bare `gh pr create`, `gh pr
  view`, `gh api` with no `cafe.github.com` deny, while sessions on the old plugin logged
  that deny. Interactive (1 session, no gh call) and subagents (no gh call): not observed.
- Every prefixed call sits in a slash command, which runs in the main session; no agent in
  `plugin/agents/` runs gh. So subagent coverage does not bear on the prefixes.
- Human, 2026-10-21: the headless proof is enough (Outcome says "interactive not observed;
  same mechanism"); drop the prefixes outright, no `${GH_TELEMETRY:-0}` form; drop the
  prefix from close.sh's printed line too; subagent case irrelevant; tighten
  close.test.sh; leave `CHANGELOG.md` alone. Plan agreed: S, default model, default merge.

## Plan

Agreed 2026-10-21.

Edits:
- `plugin/commands/close.md:67-68`: `GH_TELEMETRY=0 gh pr create` and `GH_TELEMETRY=0 gh pr
  checks` lose the prefix; re-wrap.
- `plugin/commands/next.md:117`, `:138`: drop the prefix.
- `plugin/commands/setup.md:66`, `:206`: drop the prefix; re-wrap.
- `plugin/lib/close.sh:633`: the printf becomes `'  gh pr create --base %s ...'`.
- `docs/security.md:313-317`: delete the belt-and-braces fallback clause; the paragraph says
  the SessionStart hook writes the export to `CLAUDE_ENV_FILE` and every Bash command of the
  session inherits it. No specific claim about subagents.
- `plugin/lib/close.test.sh:518`: expect `"  gh pr create --base main"` (two leading spaces)
  so a returning prefix fails, if `check_fails` matches a substring of stderr; skip otherwise.
- No change: `docs/design.md:311`, `docs/reference/cli.md:144`, `close.md:204-207`,
  `CHANGELOG.md:63`.

Verification:
- `git grep -n 'GH_TELEMETRY=0 gh' -- plugin docs` and `git grep -n GH_TELEMETRY --
  plugin/commands` return nothing.
- `bash plugin/commands/commands.test.sh`, `plugin/lib/close.test.sh` (incl. the `:518`
  case and `telemetry_cases`), `plugin/bin/peal.test.sh` (env-file cases `:97-101`) pass.
- The Outcome records: headless proven (counts, no deny lines); interactive not observed,
  same mechanism; subagent: no markdown gh call runs there.

Ranges:
- tasks/done/0145-agent-gh-telemetry-off.md:16-19,37,45,57-68
- plugin/commands/close.md:66-71, 204-207
- plugin/commands/next.md:113-139
- plugin/commands/setup.md:63-71, 201-209
- plugin/lib/close.sh:630-634
- plugin/lib/close.test.sh:517-518, 688-698
- plugin/lib/session.sh:100-113
- plugin/bin/peal.test.sh:97-101
- docs/security.md:308-324
- docs/design.md:311-312
- docs/reference/cli.md:138-146
- CHANGELOG.md:63

---

## Outcome

<!-- Written at close, replacing this comment. -->
