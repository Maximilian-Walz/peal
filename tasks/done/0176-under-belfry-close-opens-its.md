---
plan: required
size: M
depends: []
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/lib/github.sh, plugin/lib/fake-gh, plugin/lib/store-files.sh, plugin/lib/tasks.test.sh, plugin/commands/close.md, plugin/commands/next.md, plugin/commands/commands.test.sh, docs/security.md, docs/design.md, docs/reference/cli.md, docs/reference/commands.md, docs/guides/belfry.md]
milestone: m6
priority: urgent
---

# 0176 — Under Belfry, close opens its pull request through pr_create and Peal's gh reads work without the worker's gh login

## Intent

Belfry is hiding the worker's gh login from its sessions' sandbox (Belfry's #671, in the pull request that also adds the `pr_create` tool, #701), and it opens sessions' pull requests itself through `pr_create` (#575). From then on every `gh` call Peal makes inside a Belfry session fails to authenticate: `close finish`'s `gh pr create` and the lookups after it, `close verify` and `gh run rerun`, `peal ship publish`, the issues storage's reads (the board's pull request states, the issues themselves) and `main-writes: auto`'s pull request route for `idea`, `comment`, `apply` and `milestone-state` on a protected main. When this is done a Peal project works in a Belfry session without that login, and the Belfry release that carries #701 can go out. This task absorbs 0146 (close opens its pull request through `pr_create`), which it widens from the one call to every `gh` call a session's Peal makes.

## Scope

- `close finish` in `plugin/lib/close.sh`, the draft step and by-hand fallback of `plugin/commands/close.md`, and `plugin/commands/next.md`: under Belfry (a session that has Belfry's `pr_create` tool) the pull request is opened through `pr_create` with the same title, body and draft state; everywhere else `gh pr create` stays. `close finish --pr-by-tool` stops after the push and hands the opening to the session; `peal close opened N URL` hands the number back.
- `peal_gh` recognises a missing login (gh's exit 4) and `close verify` reports `BLOCKED:no-gh-login`; `fake-gh` gets a no-login mode.
- `peal list` (task files) degrades quietly when gh has no login: `pr:unknown`, no warning.
- Close under Belfry: no early draft, the one CI rerun as an empty commit, queued ideas filed through `task_create` before finish.
- The docs say what close and list do under Belfry (security's gh boundary, design, cli, commands, the Belfry guide).
- The rest (the other `gh` callers, their inventory and its test, the refusals of main-write, ship and the issues storage) is split into 0203.

## Done when

- Under a session with no gh login (simulated by a `gh` that fails authentication), `close finish` ends with the pull request opened through the `pr_create` path and the same title, body and draft state as the `gh` path.
- `peal list` and `peal board` in the same session answer without a gh login, marking the pull request state as unknown rather than failing or warning on every call (task files; the issues storage is 0203's).
- A harness covers both paths (`gh` present, `pr_create` present).
- The Belfry release that carries #671 and #701 is noted as waiting for this task in the task's Outcome.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind
>
> Belfry will open its sessions' PRs as its app through a pr_create tool (belfry#575) and refuse gh pr create in its sessions. Peal's close (close.sh finish, close.md's draft step, the by-hand fallback) and next.md open PRs with gh pr create themselves; under Belfry they should go through pr_create, and stay on gh elsewhere. (0146's own Raw.)

## Notes

Revised 2026-10-22: split: 0203 holds the rest

- Replaces 0146, which this task absorbs: its Intent and Raw are carried here and 0146 is retired as a duplicate. 0146's `depends: [human]` hold waited for the tool's name and fields to be agreed on belfry#575; they are now fixed in Belfry's #701, so the hold is lifted with this task.
- The sequencing hazard is the reason for urgent: until this lands, a Belfry that has hidden the login makes `close` unusable for any Peal project under it.
- Open: `close finish` is a script and a script cannot call an MCP tool (0146's note); see Scope.
- Pairs with the task that makes the pull request host pluggable (it depends on this one).
- Security: touches the gh boundary (`docs/security.md`, "gh holds the token; Peal only calls it") and keeps it intact: the point is that sessions hold no token; update the gh boundary text in the same pull request.
- 2026-10-22, planning with the human: split; the rest is 0203 (`depends: [0176]`). Answers:
  - Keying: `pr_create` is used whenever the session has the tool, with no-login auto-detection as the fallback.
  - Hand-off: a new `peal close opened N URL` subcommand.
  - Re-run of finish: accepted that `pr_create` leaves an open pull request unchanged. Finish prints that the body was not updated, and the Outcome asks Belfry for a `pr_update` (a human step).
  - Early draft: under Belfry, step 2 opens no early pull request. The CI run is quoted after finish through `wait_ci`/`ci_log`.
  - Draft flag: finish always hands over `draft: false`.
  - CI rerun under Belfry: one empty commit per head, if the commit gate allows it; otherwise report.
  - Quiet list: fully silent on no-login; other gh failures still warn.
  - Idea flush: under Belfry, `close.md` files each queued idea through `task_create` before finish, then drops it from the queue.
  - Verdict: a new `BLOCKED:no-gh-login`.
  - Body size: over 64 KiB is refused with a clear message, with no truncation.
- 2026-10-22, building: the plan's "`peal board` already passes `--no-pr`" was wrong: `peal_board` asks gh for pull requests like `peal list`. It gets the same quiet no-login handling through `_peal_files_prs`, and its JSON then carries no `pr` key for the task; the test checks that instead of "no gh call". `close opened` also takes `--unchanged`, for `pr_create`'s "already open, unchanged" answer.

## Plan

`pr_create` (Belfry #701) takes `title` (at most 256 characters), `body` (at most 65536) and `draft`. It takes no base and no head: Belfry uses the job's branch into the default branch. It answers `opened #N from B: URL`, or `#N is already open from B, unchanged: URL`, and leaves an open pull request as it is. Belfry has no tool to update a pull request, mark it ready or rerun a workflow. Pushing still works in a session (it runs outside the sandbox).

1. **`plugin/lib/github.sh`.** `peal_gh` maps gh's exit 4 (not logged in) to status 4, one line `peal: gh has no login (...)`, and `PEAL_GH_NOAUTH=1`. `peal_gh_failed` then answers `BLOCKED:no-gh-login`.
2. **`plugin/lib/fake-gh`.** While `$FAKE_GH/no-auth` exists, every call exits 4 with gh's own message.
3. **`plugin/lib/close.sh`.**
   - `close finish --pr-by-tool`, which finish also takes by itself when its first `peal_gh` call reports no login. It does everything up to and including the push, then skips the gh lookup, the ready-marking and the create/update. It writes the body to `$gitdir/$PEAL_CLOSE_BODY` and prints `OPEN-PR title=<title>`, `body=<file>`, `draft=false`. It keeps the sentinel and exits with its own status (5).
   - A body over 65536 characters, or a title over 256, is refused with a clear message.
   - New `peal close opened N URL`: it checks a hand-off is pending, clears the sentinel and prints `closed NNNN: pull request #N URL`. With no hand-off it is refused. When the answer was "already open, unchanged", it notes that the body was not updated.
   - The by-hand fallback (`_peal_close_by_hand`) names `pr_create` under the tool path.
4. **`plugin/commands/close.md`.**
   - Step 2: no early draft when the session has `mcp__belfry__pr_create`.
   - Before finish: under Belfry, each queued idea is filed with `task_create`, then dropped from the queue.
   - Step 5: with the tool (listed, or deferred and loaded through ToolSearch), pass `--pr-by-tool`, call `pr_create` with the hand-off's title, the body file's text and `draft: false`, then run `peal close opened N URL`.
   - Step 6: `BLOCKED:no-gh-login` trusts `wait_ci` as `no-gh`/`gh-failed` do. The one rerun under Belfry is an empty commit.
5. **`plugin/commands/next.md`.** Both `gh pr create` lines get a "with `mcp__belfry__pr_create`: call it with the same title and body" branch.
6. **`plugin/lib/store-files.sh` `_peal_files_prs`.** When `gh pr list` exits 4, claims keep `pr:unknown` and nothing is printed; other failures still warn. `peal board` already passes `--no-pr`.
7. **Docs.**
   - `docs/security.md` gh boundary (`:351-365`): under Belfry the session holds no token, and `pr_create` acts as Belfry's identity.
   - `docs/design.md` Belfry bullet (`:106-117`): close also keys on `pr_create`.
   - `docs/reference/cli.md`: `close finish --pr-by-tool`, `close opened`, `BLOCKED:no-gh-login`.
   - `docs/reference/commands.md:40`.
   - `docs/guides/belfry.md`: what close and list do without a login.
8. **Outcome.** The Belfry release carrying #671 and #701 waits for this task. Belfry needs a `pr_update` to refresh an open pull request.

Verification:
- **`close.test.sh`, new `pr_tool_cases`:**
  - With `no-auth`, finish (with and without `--pr-by-tool`) commits, pushes and prints the hand-off. The title is `"<title> [ID]"`, the body file equals `peal close body`'s output, `draft=false`, and no pulls call is made.
  - `close opened 7 URL` then prints the closed line and clears the sentinel, and `verify` no longer says `close-unfinished`.
  - `close opened` with no hand-off is refused.
  - The gh path without `no-auth` still POSTs pulls.
  - `verify` under no-auth gives `BLOCKED:no-gh-login`.
- **`commands.test.sh`:** `close.md` names `mcp__belfry__pr_create`, `--pr-by-tool` and `peal close opened`, and `next.md` names `pr_create`.
- **`tasks.test.sh`:** with a gh that exits 4, `peal list` shows `pr:unknown` with empty stderr, and `peal board` makes no gh call.
- A real `pr_create` round trip is not provable here; Belfry's release check is the end-to-end proof.

Ranges: `docs/design.md:106-120`, `docs/security.md:351-365`, `docs/guides/belfry.md:38-57`, `docs/reference/cli.md:489-551`, `docs/reference/commands.md:40`, `plugin/lib/github.sh:46-133`, `plugin/lib/close.sh:499-652`, `plugin/lib/close.sh:760-823`, `plugin/commands/close.md:66-71`, `plugin/commands/close.md:113-215`, `plugin/commands/next.md:113-141`, `plugin/lib/store-files.sh:210-252`, `plugin/lib/tasks.sh:312-354`, `plugin/lib/fake-gh:1-60`, `plugin/lib/close.test.sh:97-111`, `plugin/lib/close.test.sh:234-350`, `plugin/lib/close.test.sh:525-545`, `plugin/lib/close.test.sh:694-760`, `plugin/commands/commands.test.sh:152-169`.

---

## Outcome

Built: under Belfry, `close` opens its pull request through Belfry's `pr_create` tool instead of gh, and Peal's task-file reads stop warning when gh has no login.

- `peal_gh` (`plugin/lib/github.sh`) maps gh's exit 4 (not logged in) to status 4 and sets `PEAL_GH_NOAUTH`; `close verify` then answers `BLOCKED:no-gh-login`. `fake-gh` exits 4 while `$FAKE_GH/no-auth` exists.
- `close finish --pr-by-tool` (also taken by itself when gh reports no login) does everything up to the push, writes the body to the git dir, prints the `OPEN-PR` hand-off (title, body file, `draft=false`) and exits 5 with the close still in progress. The session calls `pr_create` with it and hands the number back with `peal close opened N URL [--unchanged]`. A title over 256 or a body over 65536 characters is refused, not truncated.
- `close.md`: under Belfry, no early draft in step 2, queued ideas filed through `task_create` before finish, the `pr_create` hand-off in step 5, `BLOCKED:no-gh-login` trusted to `wait_ci`, and the one CI rerun as an empty commit. `next.md` names `pr_create` beside both of its gh pull request lines.
- `peal list` and `peal board` keep the pull request unknown, silently, on gh's exit 4 (`_peal_files_prs`); other gh failures still warn.
- Docs: the gh boundary of `docs/security.md`, the Belfry bullet of `docs/design.md`, `docs/reference/cli.md`, `docs/reference/commands.md`, `docs/guides/belfry.md`.

**The Belfry release that carries #671 (the worker's gh login hidden from sessions) and #701 (the `pr_create` tool) waits for this task**: until a Peal release with it is installed, `close` under such a Belfry cannot open its pull request.

Left for others:
- Belfry has no tool to update an open pull request. Re-running finish on an already-open one leaves its title and body as they were (`close opened --unchanged` says so). Belfry should add a `pr_update` tool.
- The other gh callers (`peal ship`, main-write's pull request route, the issues storage) are 0203.
- Verified by harness only (`close.test.sh`'s `pr_tool_cases` under fake-gh's no-auth mode, `tasks.test.sh`, `commands.test.sh`). A real `pr_create` round trip is Belfry's release check. The empty-commit rerun and the `task_create` idea flush are instructions in `close.md`, checked only for being named.
- This close itself ran on the installed plugin (from main), which predates the change.

### Reviewer findings not acted on

- `--pr-by-tool` with gh logged in is not exercised, and its no-auth run checks only status and title: it is the same code path as the auto-detected one, which is checked in full; a small gap, not worth a task.
- `plugin/bin/peal` is outside the touches list: only its usage text for the new flag and subcommand.
