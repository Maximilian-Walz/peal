---
plan: auto
size: M
depends: []
touches: [docs/security.md, plugin/lib/session.sh, plugin/lib/close.sh]
milestone: m4
---

# 0183 — The threat model covers Claude Code project configuration changed on a task branch

## Intent

Peal checks every task branch out into a worktree and starts sessions there. `.claude/settings.json` (hooks, `permissions.allow`, `enabledPlugins`), `.claude/commands/*`, `.claude/agents/*`, `.mcp.json` and `CLAUDE.md` are files of that tree, and a session that loads the worktree loads them. The threat model does not name this: a pull request sent to a session, or an earlier compromised session, can leave hooks on the branch that run in the next session started in that worktree. The commit checks even let `.claude/settings.json` and `.belfry.yml` through a `chore(peal)` fast path unchecked (`plugin/lib/githooks.sh`). A control plane binds those paths read-only and never auto-merges `.claude/`; plain Claude Code relies on its own trust prompt for project hooks, which this review did not test. When this is done the threat model names it as a limit, and Peal reports a diff of these files.

## Scope

- `docs/security.md`: the limit, with who is protected by what (a control plane, Claude Code's own trust prompt).
- The SessionStart hook, which already diffs the launcher, reports when the worktree's `.claude/**`, `.mcp.json` or `CLAUDE.md` differ from the main branch's copy; `close begin` adds a NOTE for such a diff, as it does for milestone files.

## Done when

- `docs/security.md` names the limit.
- A test: a worktree whose `.claude/settings.json` differs from main's gets the SessionStart report and the `close begin` NOTE.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Security review finding 9 (MEDIUM, plausible: Claude Code's trust prompt was not tested; do that in the plan).
- Security: touches "a repository's own files are never what runs"; `docs/security.md` is updated here.

---

## Outcome

<!-- Written at close, replacing this comment. -->
