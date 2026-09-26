---
plan: required
touches: [plugin/commands/close.md]
---

# 0067 — Close waits for CI with Belfry's wait_ci when that tool exists

## Intent

`/peal:close` waits for the pull request's checks with `peal close wait`, which polls GitHub in rounds of up to ten minutes and answers `WAIT:checks-pending` (exit 3) until they settle. Under Belfry, the session has a `wait_ci` tool that waits on Belfry's own view of the pull request and spends none of the human's GitHub budget. When this is done, close uses `wait_ci` when the tool exists and keeps `peal close wait` otherwise, the way Peal already treats Belfry's gallery tool: used when present, never required.

## Scope

- `plugin/commands/close.md`'s wait step, and the same in any other command that waits for checks.
- `peal close wait` stays for sessions without Belfry.

## Done when

- The close command's prompt harness covers both branches (with and without the tool).
- Peal's docs mention the rule where they describe close.

## Raw

From Belfry's Friction page: `peal close wait` answering `WAIT:checks-pending` seven times in two sessions.

## Notes

Proposed plan, not agreed yet (the human did not answer on 2026-09-26; ask again):

- `plugin/commands/close.md` step 6: when the session has `mcp__belfry__wait_ci` (deferred included, loaded through ToolSearch), wait with it, passing the pull request number `peal close finish` printed. On `done: false`, call it again; on `conflict: true`, merge main in, push, and call it again. Once done, run `peal close verify` once and act on its verdict as today. Without the tool, or when it errors, run `peal close wait` as today.
- `plugin/commands/commands.test.sh`: checks on the step-6 section for both branches, the one verify after `wait_ci`, and the fallback on error.
- `docs/design.md`: the rule in the Peal-and-Belfry section (around lines 96-101) and in the close section (around 401-408).
- Release stays on `peal ship wait`: it waits on a tag's runs, and `wait_ci` takes only a pull request.
- Size S, model default, merge default. Touches: close.md, commands.test.sh, design.md.

Open questions, the proposed default first:
1. Peal has no gallery-tool handling to mirror (the Intent's claim is wrong): mirror the "when that tool exists, deferred included" wording for `wait_ci` only, or add a general Belfry-tools rule?
2. `plugin/lib/close.sh:545` prints `Next: peal close wait`: leave it and file an idea, or make it tool-neutral here?
3. After a done `wait_ci`: verify once (falling back to `peal close wait` on WAIT), or trust `wait_ci`'s answer?
4. Other defaults: the full tool name, an explicit PR number, Belfry's 60-minute default with a retry, release.md and README unchanged.


---

## Outcome

