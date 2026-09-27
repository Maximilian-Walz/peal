---
milestone: m1
priority: high
plan: required
depends: []
---

# 0074 — Filing from a Belfry session: Peal answers `tasks.commands.create`

## Intent

A session under Belfry cannot file a task: `peal idea` fetches, pushes and opens a pull
request from inside its own script, and in the session's sandbox it has neither SSH keys
nor gh's login, so it hangs with no output (eight sessions this week; nothing got filed).
Belfry now runs a contract command, `tasks.commands.create`, itself, outside the
sandbox, with the task's text on standard input and the id expected as `filed: <id>` on
its last line (Belfry #250). When this is done, Peal provides that command, and
`/peal:idea` under Belfry hands its text to Belfry's `task_create` instead of running
`peal idea` in the shell.

## Scope

- A CLI entry for the contract (`peal create --stdin --owner {owner} {title}` or similar)
  that reads the whole task text from standard input, files it the way `peal create`
  does (through a pull request on a protected main, 0061), and ends with `filed: NNNN`.
- `peal init --stage belfry` writes `create:` into the `.belfry.yml` it generates, and
  Peal's own `.belfry.yml` gets it.
- `/peal:idea`: when `BELFRY_SESSION` is set, write the text and call Belfry's
  `task_create`; never run `peal idea` there.
- The text is untrusted data: it only ever reaches the task file, never a shell word.

## Done when

- Harnesses: the command files from stdin and prints the id; hostile text lands in the
  file byte for byte; the `belfry` stage writes the key.

## Raw

From Belfry's friction reports (2026-09-25 to 27): `peal idea` hanging in sandboxed
sessions on main; `idea` with `wait: true` returning no id.

## Notes


---

## Outcome
