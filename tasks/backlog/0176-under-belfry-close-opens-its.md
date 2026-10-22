---
plan: required
size: L
depends: []
touches: [plugin/lib/close.sh, plugin/commands/close.md, plugin/commands/next.md, plugin/lib/main-write.sh, plugin/lib/store-issues.sh, plugin/lib/github.sh]
milestone: m6
priority: urgent
---

# 0176 — Under Belfry, close opens its pull request through pr_create and Peal's gh reads work without the worker's gh login

## Intent

Belfry is hiding the worker's gh login from its sessions' sandbox (Belfry's #671, in the pull request that also adds the `pr_create` tool, #701), and it opens sessions' pull requests itself through `pr_create` (#575). From then on every `gh` call Peal makes inside a Belfry session fails to authenticate: `close finish`'s `gh pr create` and the lookups after it, `close verify` and `gh run rerun`, `peal ship publish`, the issues storage's reads (the board's pull request states, the issues themselves) and `main-writes: auto`'s pull request route for `idea`, `comment`, `apply` and `milestone-state` on a protected main. When this is done a Peal project works in a Belfry session without that login, and the Belfry release that carries #701 can go out. This task absorbs 0146 (close opens its pull request through `pr_create`), which it widens from the one call to every `gh` call a session's Peal makes.

## Scope

- `close finish` in `plugin/lib/close.sh`, the draft step and by-hand fallback of `plugin/commands/close.md`, and `plugin/commands/next.md`: under Belfry (a session that has Belfry's tools) the pull request is opened through `pr_create` with the same title, body and draft state; everywhere else `gh pr create` stays. `close finish` is a shell script and cannot call an MCP tool: either `close.md` has the session call `pr_create` and hand the number back to `close finish`, or finish stops before opening and says what to open (the plan decides).
- The reads that need a token: what the board and `peal list` ask GitHub for (a claim's pull request state, the issues storage's issues, labels and milestones) must degrade or go through a Belfry tool when the session has no login; `peal close verify`/`wait` already have `wait_ci` under Belfry.
- `main-writes: auto` and `peal ship`: say what they do without a login (refuse with the reason, or leave the write to the control plane's host commands).
- The docs say what a Belfry session can and cannot rely on.

## Done when

- Under a session with no gh login (simulated by a `gh` that fails authentication), `close finish` ends with the pull request opened through the `pr_create` path and the same title, body and draft state as the `gh` path.
- `peal list` and `peal board` in the same session answer without a gh login, marking the pull request state as unknown rather than failing or warning on every call.
- Every other `gh` call Peal makes is either listed in the docs as unavailable under Belfry with what to do instead, or has a Belfry-side path; a test asserts the list is complete (a new `peal_gh` caller fails it until listed).
- A harness covers both paths (`gh` present, `pr_create` present).
- The Belfry release that carries #671 and #701 is noted as waiting for this task in the task's Outcome.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind
>
> Belfry will open its sessions' PRs as its app through a pr_create tool (belfry#575) and refuse gh pr create in its sessions. Peal's close (close.sh finish, close.md's draft step, the by-hand fallback) and next.md open PRs with gh pr create themselves; under Belfry they should go through pr_create, and stay on gh elsewhere. (0146's own Raw.)

## Notes

- Replaces 0146, which this task absorbs: its Intent and Raw are carried here and 0146 is retired as a duplicate. 0146's `depends: [human]` hold waited for the tool's name and fields to be agreed on belfry#575; they are now fixed in Belfry's #701, so the hold is lifted with this task.
- The sequencing hazard is the reason for urgent: until this lands, a Belfry that has hidden the login makes `close` unusable for any Peal project under it.
- Open: `close finish` is a script and a script cannot call an MCP tool (0146's note); see Scope.
- Pairs with the task that makes the pull request host pluggable (it depends on this one).
- Security: touches the gh boundary (`docs/security.md`, "gh holds the token; Peal only calls it") and keeps it intact: the point is that sessions hold no token; update the gh boundary text in the same pull request.

---

## Outcome

<!-- Written at close, replacing this comment. -->
