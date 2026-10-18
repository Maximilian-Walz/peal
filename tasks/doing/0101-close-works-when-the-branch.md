---
plan: required
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/commands/close.md]
milestone: m3
size: S
---

# 0101 — Close works when the branch's upstream could not be recorded

## Intent

In some sandboxes a device node is mounted over the main checkout's `.git/config.lock`, which stops git from writing config there. `close finish` pushes with `git push -q -u` (`plugin/lib/close.sh`). The push itself goes through, but recording the branch's upstream fails with "could not lock config file ... File exists". The pull request still opens. From then on, `close verify` and `close wait` answer `BLOCKED:no-upstream`, and finish's own already-pushed check (HEAD compared with `$branch@{upstream}`) stops working too.

When this task is done, close finds the branch's remote state even with no upstream configured. It falls back to the remote-tracking ref `refs/remotes/$PEAL_REMOTE/$branch`, which the push updates without writing config. A push whose only failure is the upstream write counts as a successful push.

## Scope

- `close finish`, `close verify`, `close wait` and the Stop hook: when `$branch@{upstream}` does not resolve, fall back to `refs/remotes/$PEAL_REMOTE/$branch`.
- A push whose only failure is the upstream config write counts as a successful push.
- Look at the SessionStart reap's "could not delete origin/task/..." warnings (in `plugin/lib/store-files.sh` and `plugin/lib/store-issues.sh`). If they have the same cause, fix them the same way; if not, file them separately.

## Done when

- close.test.sh: a branch pushed with no upstream configured is verified as pushed, and finish skips the push when the remote-tracking ref equals HEAD.
- The verdict for a branch with nothing on the remote reads `BLOCKED:not-pushed`.
- The reap warnings' cause is reproduced and filed as its own idea.

## Raw

> Belfry friction, 2026-09-27/28 (jobs c9d400842a081576, f65af4fa8efc4ebc, f95455300fd56365, a5cb48225a067537): "peal close wait reports BLOCKED:no-upstream after a successful push in a sandbox." Workaround every time: `git push -u origin <branch>` run as a command of its own, outside the sandbox. One report proposed pushing without `-u` in finish and printing that push as a next step; another, falling back to `origin/<branch>` in verify.
>
> Job a5cb48225a067537 (peal)
>
> - **Tried:** peal close finish in a sandboxed worktree session, which pushes the task branch with `git push -u`
> - **What happened:** peal close finish cannot set the branch's upstream in a sandboxed session. The push ran inside finish's own process, so it stayed in the sandbox. There, the main checkout's .git/config.lock is a device node, and git failed with "could not lock config file ... unable to write upstream branch configuration". The PR still opened, but the branch had no upstream, which peal close verify reports as no-upstream.
> - **Workaround:** Ran `git push -u origin <branch>` as its own command, which runs outside the sandbox and set the upstream.
> - **Proposed fix:** In finish, push without -u and let the sandbox-exempt top-level `git push -u origin <branch>` be a printed next step. Or have verify compare against origin/<branch> directly when no upstream is configured.

## Notes

- Open question: how can close tell "only the upstream config write failed" apart from a real push failure? The exit status alone is not enough. Two options: compare the remote-tracking ref with HEAD after the push, or push without `-u` and set the upstream afterwards as a separate best-effort step.
- Open question: does the reap's failure come from the same config lock, or from something else in the sandbox?
- The upstream is read in `plugin/lib/close.sh` at the already-pushed check in finish (~l.508), in wait (~l.614) and in verify (~l.655).
- `docs/design.md` covers close's gates in general, but not this case.
- 2026-10-18, the human's answers at planning: the Stop hook gets the same fallback; finish prints one stdout NOTE after a push that could not record the upstream; the verdict for a branch with nothing on the remote is renamed `no-upstream` -> `not-pushed` (left to the session as "whatever is cleanest long-term"; no users yet); the reap warnings are reproduced and filed as their own idea, not fixed here.
- Planner's finding: git's `set_upstreams()` (transport.c) is void and runs after the push's exit code is computed, so a push with `-u` already exits 0 when only the upstream write fails. The exit status is enough; this task keeps it so with a test.
- The note above calls ~l.614 "wait"; it is the Stop hook (`peal_close_stop`, close.sh:625-632). `wait` only calls verify.

## Plan

Approach:
- `plugin/lib/close.sh`: add `_peal_close_remote_ref BRANCH`: prints `BRANCH@{upstream}` when it resolves, else `refs/remotes/$PEAL_REMOTE/BRANCH` when it exists, else nothing with status 1 (the same fallback `peal_release_verdict` has inline, claim.sh:467-468).
  - finish (close.sh:508-519): ref resolves and equals HEAD -> no push. Otherwise push with `-q -u "$PEAL_REMOTE" "$branch"` (remote and branch always spelled out; keep `-u`). After a successful push, if `@{upstream}` still does not resolve, print one stdout line: `NOTE: pushed; the upstream could not be recorded (above), so verify and wait compare with $PEAL_REMOTE/<branch>`.
  - verify (close.sh:667-669): set `PEAL_REMOTE` from config; use the helper for the nothing-on-the-remote check and the `ahead` count. Verdict `BLOCKED:no-upstream` becomes `BLOCKED:not-pushed`; update the verdict list comment (close.sh:652).
  - Stop hook (close.sh:625-631): the same helper, so a finish failing after a sandboxed push does not say "was never pushed".
  - wait: unchanged (it calls verify).
- `plugin/commands/close.md:151`: the renamed verdict.
- Reap warnings (store-files.sh:1075, store-issues.sh:996): not changed. Reproduce in a scratch repo (delete the branch in the bare remote, keep the stale tracking ref, release, see the warning) and file it with `peal idea`, the reproduction quoted. If the reproduction points to the config lock instead, stop and ask.
- Rejected: pushing without `-u` and printing a manual push step; deciding push success from the tracking ref; a separate `--set-upstream-to` step.

Files: plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/commands/close.md.

Verification: new `no_upstream_cases` in close.test.sh, added to `cases()`, run for both storages:
1. `new_repo; ready 1 first-task; build; begin; outcome`; `git branch --unset-upstream`; a regular file at `$(git rev-parse --git-common-dir)/config.lock`.
2. `close_finish` exits 0, no "the push failed", prints the NOTE, one pull request, `branch.<b>.merge` empty, `refs/remotes/origin/<b>` == HEAD.
3. `verdict` gives `WAIT:no-checks-yet 3`, not `BLOCKED:not-pushed`.
4. `rearm_sentinel`, remote URL pointed at a missing repo: `close_finish` exits 0, does not push, still one PR (like push_skip_cases).
5. Stop hook with the sentinel armed: no "was never pushed".
6. A commit beyond the tracking ref: `BLOCKED:unpushed 1`.
7. Remove config.lock at the end.
8. Existing cases still pass; close.test.sh:647 expects `BLOCKED:not-pushed 1`. Run `bash plugin/lib/close.test.sh` and the project's lint.

Ranges: tasks/doing/0101-close-works-when-the-branch.md:1-47, docs/milestones/m3.md:8-27, docs/design.md:312-323, plugin/lib/close.sh:21-33, plugin/lib/close.sh:500-563, plugin/lib/close.sh:598-714, plugin/lib/close.test.sh:28-120, plugin/lib/close.test.sh:343-362, plugin/lib/close.test.sh:449-471, plugin/lib/close.test.sh:543-585, plugin/lib/close.test.sh:596-704, plugin/lib/close.test.sh:723-773, plugin/lib/claim.sh:451-474, plugin/lib/claim.sh:515-542, plugin/lib/store-files.sh:1050-1080, plugin/lib/store-issues.sh:990-1001, plugin/lib/session.sh:100-118, plugin/lib/session.sh:211-243, plugin/lib/common.sh:132-147, plugin/commands/close.md:144-151, docs/reference/cli.md:441-481.

---

## Outcome

<!-- Written at close, replacing this comment. -->
