---
plan: skipped
priority: low
touches: [.claude/settings.json]
---

# 0246 — Allow mcp__belfry__task_create in this repository's .claude/settings.json

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

- 0138 was retired, not done: its Outcome says the remaining edit was "a one-line human edit of .claude/settings.json that a sandboxed session cannot make; not a task". The sandbox keeps `.claude/settings.json` unwritable here too, and `place_config` only places skills and commands, so a session may not be able to make this edit at all. Open question: should this be a human task instead?
- `.claude/settings.json` today holds no `permissions` block at all (only the marketplace and the enabled plugin); the rule would be its first.
- Open question: which close-under-Belfry task the idea means ("filed in the same triage") is not named; check it before working this one, since if close stops calling `task_create` the rule may be moot.
