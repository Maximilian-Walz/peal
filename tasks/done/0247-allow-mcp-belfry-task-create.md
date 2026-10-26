---
plan: skipped
priority: low
touches: [.claude/settings.json]
---

# 0247 — Allow mcp__belfry__task_create in this repository's .claude/settings.json

## Intent

Belfry sessions on this repository keep asking for permission to call `mcp__belfry__task_create`, and the human has approved it every time. Add an allow rule for it to the repository's `.claude/settings.json`, the way 0138 meant to for WebFetch, so those sessions stop asking.

## Scope

## Done when

## Raw

> Allow mcp__belfry__task_create in this repository's .claude/settings.json
>
> ## Intent
>
> Belfry sessions on this repository ask for `mcp__belfry__task_create` and the human allowed it every time (4×, jobs 912e96d8f557b252 and f7c546cf5fe30df2). Allow it in `.claude/settings.json`, as 0138 did for WebFetch, so sessions stop asking.
>
> ## Done when
>
> - `.claude/settings.json` allows `mcp__belfry__task_create`.
>
> ## Notes
>
> - A `.claude` change: a human merges it.
> - Check with the close-under-Belfry task filed in the same triage: if close stops using `task_create`, this may be moot.

## Notes

- The close-under-Belfry task is most likely 0235 (close files its queued ideas through the belfry `idea` tool, not `task_create`). If it lands, task sessions stop calling `task_create`, and only the idea-filing jobs still use it. Check whether those jobs ask for it before you add the rule.
- 0138 was retired, not done. Its Outcome calls the remaining edit "a one-line human edit of .claude/settings.json that a sandboxed session cannot make; not a task". The sandbox still keeps `.claude/settings.json` unwritable, and `place_config` only places skills and commands. Open question: should this be a human task instead?
- `.claude/settings.json` has no `permissions` block today (only the marketplace and the enabled plugin), so this rule would be its first.

## Outcome

Retired 2026-10-26 without being claimed: Duplicate of 0246, which adds the allow rule.
