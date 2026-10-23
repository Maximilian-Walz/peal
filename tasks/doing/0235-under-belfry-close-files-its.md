---
milestone: m6
plan: required
---

# 0235 — Under Belfry, close files its queued ideas through the belfry idea tool

## Intent

In a Belfry session, `peal close finish` cannot file the ideas queued on the task's
branch: its flush fetches and pushes origin/main from inside the sandbox, which holds no
SSH key, so finish fails with "the queued ideas were not all filed". Step 5 of
`plugin/commands/close.md` tells the session to file them with `mcp__belfry__task_create`
first, but that tool only works in Belfry's idea-filing jobs, so the route the command
names does not work in a task session either. Under Belfry, close should file its queued
ideas through the belfry `idea` tool (or have finish skip its own flush and say why), so
the close finishes with the ideas in Belfry's idea box and nothing left queued, with no
manual workaround. `/peal:idea` gets the same check where it uses `task_create` the same
way.

## Scope

## Done when

## Raw

> Under Belfry, close files its queued ideas through the belfry idea tool, not task_create or a push to main
>
> ## Intent
>
> In a Belfry session `peal close finish` cannot file the ideas queued on the task branch: it fetches and pushes origin/main from inside the sandbox, which has no SSH key, and fails with "the queued ideas were not all filed". `plugin/commands/close.md` says to file them with `mcp__belfry__task_create` first, but that tool only works in Belfry's idea-filing jobs. Once this is done a close under Belfry files its queued ideas without a manual workaround.
>
> ## Scope
>
> - `plugin/commands/close.md` step 5: with the belfry `idea` tool in the session, file each queued idea through it (`peal ideas --export`), then `peal ideas --drop --all`; drop the `task_create` route, or keep it only where it works.
> - Or `close finish --ideas-by-tool`, so finish skips its own flush and says why.
> - The same check for `/peal:idea` under Belfry if it uses `task_create` the same way.
>
> ## Done when
>
> - A close in a Belfry session with queued ideas finishes with the ideas in Belfry's idea box and none left queued; a test covers the skipped flush.
>
> ## Notes
>
> - Friction from job bf5c7018ba710895 (worker v0.34.0, peal 0.7.0). Its shellcheck half is added to 0189.
> - Related: 0224 (/peal:idea and a filed idea's milestone under the control plane), 0222 (detect the control plane by its tools).

## Notes

- Milestone m6 is the human's decision at filing.
- Open: the command-text route (file via the `idea` tool, then `peal ideas --drop --all`)
  or a `close finish --ideas-by-tool` flag; the latter touches `plugin/lib/ship.sh`
  (plan required) and is what a "test covers the skipped flush" most naturally tests.
- Open: the `idea` tool's text loses the queued idea's milestone/plan frontmatter as
  fields unless Belfry's filing job reads them back; see 0224.
- `/peal:idea` already falls back to the `idea` tool when `task_create` refuses off a
  task branch; check whether that fallback should become the first route there too.
- Related, not prerequisites: 0222 (detect the control plane by its tools), 0224, 0189
  (the shellcheck half of the same friction).
- `docs/design.md` (Peal never needs Belfry; Belfry never knows Peal) bears on how the
  session detects the tool.

---

## Outcome

<!-- Written at close, replacing this comment. -->
