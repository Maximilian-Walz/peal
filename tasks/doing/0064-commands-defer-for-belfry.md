---
plan: required
---

# 0064 — A defer command for Belfry: `tasks.commands.defer`

## Intent

Belfry's `task_defer` tool, on a `commands` project, can now run a contract command that makes one task depend on another (Belfry #155, `tasks.commands.defer`, with `{task}` and `{on}` as one shell word each, run on a worker in a synced clone). Peal provides that command, so a session under Belfry that finds its task blocked on another records the dependency in Peal's storage the same way `/peal:defer` would.

## Scope

- A CLI entry (for example `peal depend {task} {on}`) that adds `{on}` to `{task}`'s `depends`, straight into the storage like `/peal:revise`, refusing a cycle (#26's check) and a task that has a claim other than the caller's.
- `peal init --stage belfry` writes `defer:` into the `.belfry.yml` it generates, and Peal's own `.belfry.yml` gets it.
- The `filed: <id>` line Belfry reads from a filing job is task 0044's; this task only checks the two fit together.

## Done when

- Harnesses cover the new command on both storages, its refusal of a cycle, and the `belfry` stage writing `defer:`.

## Raw

From an idea a Belfry session filed while building Belfry #155 (PR #171).

## Notes


---

## Outcome

