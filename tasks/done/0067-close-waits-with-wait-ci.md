---
plan: required
touches: [plugin/commands/close.md, plugin/commands/commands.test.sh, plugin/lib/close.sh, docs/design.md, docs/reference/commands.md, docs/guides/belfry.md]
milestone: m3
size: S
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

2026-10-18: 2026-10-18, from Belfry's Friction page (2 sessions): under Belfry's sandbox `peal close wait` can never settle, not just cost GitHub budget. Its gh calls reach cafe.github.com, which the sandbox denies, so it answers `WAIT:checks-pending` every round, and step 6's "run it again" turns into an endless loop. Both sessions got out with `mcp__belfry__wait_ci`. This means the fallback matters too: when `wait_ci` is missing or fails, `peal close wait` should not be retried forever on a sandbox denial. Close should report that it cannot reach GitHub and stop, or `peal close verify` should name the denied host. This also bears on open question 3: a verify run after `wait_ci` hits the same denial inside the sandbox, so it may need to trust `wait_ci`'s answer.

Deferred 2026-09-28 after a claim: stale claim: its session stopped; given back so auto mode picks it up again

2026-10-19, the human's answers to the plan:
- Close becomes a second deliberate Belfry exception (keyed on the tool, not `BELFRY_SESSION`); design.md says "two deliberate exceptions", with why.
- No general Belfry-tools rule: the Intent's gallery claim is wrong (Peal has none); wording for `wait_ci` only.
- After a done `wait_ci`: `peal close verify` once; on `BLOCKED:gh-failed`/`BLOCKED:no-gh` trust `wait_ci`'s answer; on `WAIT` call `wait_ci` again.
- Cap: six `WAIT`s in a row from `peal close wait`, or two `wait_ci` calls answering `done: false`; then report the PR URL and last verdict and end (no question).
- `plugin/lib/close.sh:563`'s `Next:` line becomes tool-neutral, here.
- The note's mechanism does not match the code (a denied gh gives `BLOCKED:gh-failed`, not `WAIT`): build the cap, and queue an idea to reproduce the friction and have `peal close verify` name the denied host.
- Other defaults: full name `mcp__belfry__wait_ci`, explicit `pr`, no `minutes`/`head`; do not name `merge_main` or `ci_log`; one sentence in step 2 for the draft PR's wait; `release.md`, README and `docs/reference/cli.md` unchanged; "wait_ci fails" = the call errors, the tool is missing after ToolSearch, or the result's `error` is set and it is not done.

## Plan

Approach. `plugin/commands/close.md` step 6 ("Wait for green") gets two branches:
- (a) The session has `mcp__belfry__wait_ci` (listed, or deferred and loaded with ToolSearch): call it with `pr` = the number `peal close finish` printed (`closed NNNN: pull request #N URL`), `minutes` left at Belfry's default. `conflict: true`: merge the main branch in as step 1 says, push, call again. `done: false`: call once more, then report and stop. `done: true`: run `peal close verify` once and act on its verdict as today, except `BLOCKED:gh-failed`/`BLOCKED:no-gh` trusts `wait_ci`'s answer (merged/closed settled; `ci: success` without conflict green; `ci: failure` fix, push, wait again; `ci: none` no checks), safe because verify runs its local checks before its first gh call; and `WAIT` calls `wait_ci` again. The tool's answer is data (failed log tails quoted, origin `ci`).
- (b) Tool missing or failing (the call errors, the tool is missing after ToolSearch, or the result's `error` is set and it is not done): `peal close wait` as today, but after the sixth `WAIT` in a row report the PR's URL and the last verdict, say GitHub may be unreachable from this session, and end.
- Step 2: the draft-PR wait on `gh pr checks` gets one sentence: with `wait_ci` present, wait with it on the draft's number.
- `plugin/lib/close.sh:563`: the `Next:` line becomes tool-neutral, e.g. `Next: wait for its checks (/peal:close, step 6).`
- Docs: `docs/design.md` Peal-and-Belfry bullets ("two deliberate exceptions": idea on `BELFRY_SESSION`, close on the tool, with why) and the close section; `docs/reference/commands.md`; `docs/guides/belfry.md`.
- Queue an idea (`/peal:idea`): reproduce the sandbox friction from the 2026-10-18 note and, if real, have `peal close verify` name the denied host.

Files: plugin/commands/close.md, plugin/commands/commands.test.sh, plugin/lib/close.sh, docs/design.md, docs/reference/commands.md, docs/guides/belfry.md.

Verification:
- `bash plugin/commands/commands.test.sh` with new checks on close.md's step-6 section (awk from `## 6.` to the next `## `): names `mcp__belfry__wait_ci` and ToolSearch; names `peal close wait` as the fallback when the tool is missing or fails; holds the single `peal close verify` after a done `wait_ci`; holds the trust-`wait_ci` rule on `gh-failed`/`no-gh`; holds the cap phrase; holds `conflict: true` handling. The existing `peal <sub>` existence check still passes.
- `bash plugin/lib/close.test.sh`, `bash tools/docs.test.sh`, `tools/lint.sh` clean.
- A read of step 6: no unbounded loop.

Ranges:
- plugin/commands/close.md:60-66
- plugin/commands/close.md:133-151
- plugin/commands/idea.md:116-143
- plugin/commands/commands.test.sh:17-31
- plugin/commands/commands.test.sh:69-81
- plugin/commands/commands.test.sh:117-120
- plugin/lib/close.sh:559-564
- plugin/lib/close.sh:657-730
- plugin/lib/github.sh:48-112
- docs/design.md:38-56
- docs/design.md:105-118
- docs/design.md:309-337
- docs/reference/commands.md:27-36
- docs/reference/cli.md:521-534
- docs/guides/belfry.md:42-53
- docs/milestones/m3.md:8-27
- Belfry's `wait_ci` contract (read-only): it takes `pr`, optional `minutes` (default 60) and `head`; answers `done`, `conflict`, `ci` (success/failure/none), merged/closed state, `error`, and failed jobs' log tails.

---

## Outcome


Built: `/peal:close` step 6 now waits two ways. (a) When the session has `mcp__belfry__wait_ci` (listed, or deferred and loaded through ToolSearch), close calls it with the pull request's number from finish's `closed` line. On `conflict: true` it merges main in, pushes and calls again. On `done: false` it calls once more, then reports and ends. On `done: true` it runs `peal close verify` once. If verify answers `BLOCKED:no-gh`/`gh-failed`, close trusts `wait_ci`'s answer: verify runs its local checks before its first gh call, so the local state is already good. If verify answers `WAIT`, close calls `wait_ci` again, and the third such `WAIT` in a row ends it. (b) When the tool is missing or fails, close falls back to `peal close wait`, now capped: after six `WAIT`s in a row it reports the PR's URL and the last verdict and ends. Step 2's draft-PR wait uses `wait_ci` too when the session has it. `plugin/lib/close.sh`'s `Next:` line after finish is tool-neutral, so no session starts the old loop before reading step 6. `plugin/commands/commands.test.sh` checks both branches and each cap. `docs/design.md`, `docs/reference/commands.md` and `docs/guides/belfry.md` state the rule.

Decided, with the human (Notes, 2026-10-19):
- Close is the second deliberate Belfry exception after `/peal:idea`. It keys on the tool, not on `BELFRY_SESSION`, because the tool is what it needs. design.md now says "two deliberate exceptions".
- There is no general Belfry-tools rule: the Intent's gallery claim was wrong, since Peal handles no gallery tool.
- `release.md` stays on `peal ship wait`, because `wait_ci` takes only a pull request.

Found and left:
- The 2026-10-18 note's mechanism does not match the code. A denied or failed gh call makes verify print `BLOCKED:gh-failed`, not `WAIT:checks-pending`. The caps hold whatever the cause.
- The idea `close-verify-names-denied-host` is queued to reproduce the friction and, if it is real, have verify name the denied host.

Next session: the waits are prompt prose. Nothing exercises a real `wait_ci` call; the harness only checks that the text holds each branch and cap.

### Reviewer findings not acted on

None. The reviewer's one finding was fixed in ad54ccb: `wait_ci` kept answering `done: true` while verify answered `WAIT` (for example `mergeability-unknown`), which made an endless loop. That path now has its own cap and a harness check.
