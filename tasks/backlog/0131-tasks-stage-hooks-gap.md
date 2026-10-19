---
plan: skipped
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

## Done when

## Raw

> Found walking /peal:setup, /peal:work and /peal:close live on a scratch repository
> (task 0129): after the tasks stage, `peal commit` answered "Peal's git hooks are not
> installed here, so nothing would gate the commit".

## Notes
