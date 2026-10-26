---
plan: skipped
priority: low
touches: [.claude/settings.json]
---

# 0246 — Allow mcp__belfry__task_create in this repository's .claude/settings.json

## Intent

Belfry sessions on this repository keep asking for permission to call `mcp__belfry__task_create`, and the human has approved it every time. Add an allow rule for it to the repository's `.claude/settings.json`, the way 0138 meant to for WebFetch, so those sessions stop asking.

## Scope

- One allow rule, `mcp__belfry__task_create`, in a new `permissions` block of `.claude/settings.json`.

## Done when

- `.claude/settings.json` allows `mcp__belfry__task_create`.

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
- 2026-10-26, the human: they make the edit in the worktree and the session commits it (the sandbox cannot write the file), and 0247, a duplicate of this task, is retired. 0235 makes the rule less needed but not moot: `/peal:idea` and Belfry's idea-filing jobs still call `task_create`.

---

## Outcome

`.claude/settings.json` now holds `"permissions": {"allow": ["mcp__belfry__task_create"]}`, its first `permissions` block, so Belfry sessions on this repository stop asking for that tool.

The sandbox keeps `.claude/settings.json` unwritable, which is why 0138 was retired. The human made the one-line edit in this worktree, and the session committed it. That route works for any future `.claude/settings.json` change: the human edits, the session commits.

0247 was a duplicate of this task and is retired through its own pull request (#388). 0235 (close files its queued ideas through the belfry `idea` tool) will take `task_create` out of close, but it does not make this rule moot: `/peal:idea` and Belfry's idea-filing jobs still call `task_create`.

`docs/security.md` lists `.claude/settings.json` among the paths that always wait for the human's merge, so this pull request does.

The review found nothing.
