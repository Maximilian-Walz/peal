---
plan: skipped
milestone: m3
priority: high
---

# 0131 — A tasks-only project cannot commit or close until hooks are installed by hand

## Intent

`peal commit` and `peal close begin` refuse while Peal's git hooks are not installed
(plugin/lib/commit.sh, plugin/lib/close.sh), but only the `guardrails` stage installs them
(`peal_hooks_ensure`, plugin/lib/githooks.sh, a no-op without that stage). A project that
set up only the `tasks` stage, the one stage getting-started asks for, hits the refusal at
the implementer's first commit and at the close. Decide: install the hooks at the `tasks`
stage or at claim, or let `peal commit` and the close run without them when `guardrails`
is not set up. Task 0129 documented the manual `.peal/peal hooks install` as a stopgap in
docs/getting-started.md; remove that line when this lands.

## Scope

Let `peal commit`, `peal close begin` and `peal close finish` run without Peal's git hooks
where `guardrails` is not in the project's `stages`; keep the refusals where it is. Remove
the manual `.peal/peal hooks install` stopgap from docs/getting-started.md and describe the
rule in docs/design.md, docs/reference/cli.md and plugin/commands/close.md.

## Done when

- [x] A `tasks`-only project can `peal commit` and close without installing hooks
  (commit.test.sh case).
- [x] A `guardrails` project is still refused without hooks (commit.test.sh,
  close.test.sh).
- [x] The stopgap line is gone from docs/getting-started.md; the docs state the condition.

## Raw

> Found walking /peal:setup, /peal:work and /peal:close live on a scratch repository
> (task 0129): after the tasks stage, `peal commit` answered "Peal's git hooks are not
> installed here, so nothing would gate the commit".

## Notes
