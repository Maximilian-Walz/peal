---
milestone: m6
plan: required
depends: [0176]
part-of: 0176
---

# 0203 — Every gh call Peal makes is listed for Belfry, and the writes that need a login refuse with the reason

## Intent

Under Belfry a session has no gh login. Close's pull request and the quiet list are handled by the origin. This piece covers every other `gh` call Peal makes. Each one either has a Belfry-side path or is listed as unavailable under Belfry, with what to do instead. A test keeps that list complete. The writes that need a login (main-write's pull request route, `peal ship publish`, the issues storage) refuse up front with the reason, rather than failing halfway.

## Scope

## Done when

## Raw

> - `main-writes: auto` and `peal ship`: say what they do without a login (refuse with the reason, or leave the write to the control plane's host commands).
> - The docs say what a Belfry session can and cannot rely on.
>
> Every other `gh` call Peal makes is either listed in the docs as unavailable under Belfry with what to do instead, or has a Belfry-side path; a test asserts the list is complete (a new `peal_gh` caller fails it until listed).

Split from 0176

## Notes

2026-10-22: Re-plan 2026-10-22: the issues storage's refusal is the stopgap; the path through the control plane's `task_record` is its belfry#727 and Peal's 0227 (Contract kept), which closes the "file an idea" default of this piece's planner.

- From the origin's plan, as agreed with the human: no Belfry tool can stand in for these writes. `pr_create` only opens from the job's own branch, so main-write's `peal/main-write-*` pull requests have no Belfry path. The plan's proposal is that `_peal_mw_pr` refuses before it pushes a branch, and `peal ship publish` and the issues storage refuse the same way. Use the origin's no-login status (`peal_gh` exit 4, `BLOCKED:no-gh-login`) and `fake-gh`'s no-auth mode.
- Inventory, as proposed: one row per shell function under `plugin/lib/*.sh` that calls `peal_gh` or `gh`, in a table in `docs/guides/belfry.md` grouped under command headings. A new `plugin/lib/gh-callers.test.sh` compares the functions it extracts with awk against the table, failing on both missing and stale rows.
- Open for this piece's planner (the planner's defaults, not yet decided by the human):
  - Issues storage: refuse with one line pointing to Belfry's `tasks`/`task` tools, and file an idea for a path through Belfry's tools.
  - Ship: refuse, and mark the `release` action in `init.sh`'s Belfry template as needing a login.
  - Doctor's "gh is not logged in" under Belfry: leave it.
- Size estimate: M, about 90 tool calls.
