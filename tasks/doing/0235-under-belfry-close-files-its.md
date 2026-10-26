---
milestone: m6
plan: required
size: M
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/lib/ideas.sh, plugin/bin/peal, plugin/commands/close.md, plugin/commands/idea.md, plugin/commands/commands.test.sh, docs/reference/cli.md, docs/reference/commands.md, docs/guides/belfry.md, docs/design.md]
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

- `peal close finish --ideas-by-tool` (like `--pr-by-tool`): finish skips its own flush,
  records each queued idea as handed, keeps the removed texts in the git dir
  (`peal-ideas-handed`), empties the queue and says why; no network for them.
- `peal ideas --export N`: one queued idea by position.
- `plugin/commands/close.md` step 5: with `mcp__belfry__idea` in the session (listed, or
  deferred and loaded through ToolSearch), file each queued idea through it, its whole
  text, `wait` false, then run finish with `--ideas-by-tool`. The `task_create` route
  leaves close.md.
- The PR body's "## Ideas filed" lists handed ideas by title, marked as handed to the
  control plane's idea tool.
- Finish's refusal for unfiled ideas names `--ideas-by-tool`.
- `/peal:idea` keeps `task_create` first and `idea` as fallback (at most one sentence on
  why); docs follow (cli, commands, guides/belfry, design).

## Done when

- `close.test.sh` `ideas_by_tool_cases`, both storage kinds, two ideas queued and a
  remote refusing pushes to main: plain finish still refuses (and names the flag);
  `--ideas-by-tool` succeeds, prints the why line, origin/main does not move, no task is
  filed, the queue is empty, the PR body lists both titles as handed; a second finish is
  idempotent.
- `commands.test.sh`: close.md names `mcp__belfry__idea` and `--ideas-by-tool`, not
  `task_create`; idea.md's checks still pass.
- The live check (ideas in Belfry's idea box) follows the next release; the Outcome says so.

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

Deferred 2026-10-26 after a claim: Claimed on a worker machine that went offline before any work; given back from another machine

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
- Plan agreed 2026-10-26. Answers: Route flag; Credit by title; Wait false; IdeaText
  whole text; ExportOne add; IdeaRoute keep order; Detection the idea tool; ForgotFlag
  yes; HandedLost keep; LiveCheck Outcome note; BranchPush file an idea at close (finish's
  own push of the task branch, close.sh:627-633, fails in the sandbox too).

## Plan

Approach: add `close finish --ideas-by-tool`, parsed in the same loop as `--pr-by-tool`
(close.sh:546-549). In place of the flush (close.sh:588-594), after every up-front
refusal: write a `handed - — "Title"` line per queued idea into `peal-ideas-filed`, copy
the texts into `peal-ideas-handed` in the git dir, remove the queue, print `ideas: N
queued idea(s) taken as filed through the session's idea tool (--ideas-by-tool); nothing
filed on main`. Re-runs find the queue empty. `peal close body` (close.sh:442-451) prints
handed lines as `- Title (handed to the control plane's idea tool)`. The flush refusal
names `--ideas-by-tool`. `peal ideas --export N` in ideas.sh. close.md step 5 rewritten
around the `idea` tool (whole text, owner ai or human, wait false) then finish with the
flag; step 1 note and finish's description follow. Wording generic: Peal reads no Belfry
variable. Rejected: command text only (no skipped flush to test, PR body loses ideas);
detection from gh login; a hand-off after the flush.

Files: plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/lib/ideas.sh,
plugin/bin/peal (usage 260-267), plugin/commands/close.md, plugin/commands/idea.md,
plugin/commands/commands.test.sh (185-186), docs/reference/cli.md,
docs/reference/commands.md, docs/guides/belfry.md, docs/design.md (127: "through
`task_create` first" changes).

Verification: as Done when; plus the docs checks and gh-callers.test.sh unaffected.

Ranges:
- plugin/commands/close.md:36-46
- plugin/commands/close.md:120-169
- plugin/commands/idea.md:114-163
- plugin/lib/close.sh:442-451
- plugin/lib/close.sh:527-594
- plugin/lib/close.sh:626-672
- plugin/lib/close.sh:693-715
- plugin/lib/ideas.sh:56-143
- plugin/lib/close.test.sh:355-404
- plugin/lib/close.test.sh:624-655
- plugin/commands/commands.test.sh:73-85
- plugin/commands/commands.test.sh:180-187
- plugin/bin/peal:207-210
- plugin/bin/peal:260-267
- docs/design.md:113-133
- docs/guides/belfry.md:58-74
- docs/guides/belfry.md:97-102
- docs/reference/commands.md:40-62
- docs/reference/cli.md:339-343
- docs/reference/cli.md:551-588

---

## Outcome

<!-- Written at close, replacing this comment. -->
