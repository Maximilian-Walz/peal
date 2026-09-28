---
plan: required
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh]
---

# 0101 — Close works when the branch's upstream could not be recorded

## Intent

In some sandboxes a device node is mounted over the main checkout's `.git/config.lock`, which stops git from writing config there. `close finish` pushes with `git push -q -u` (`plugin/lib/close.sh`). The push itself goes through, but recording the branch's upstream fails with "could not lock config file ... File exists". The pull request still opens. From then on, `close verify` and `close wait` answer `BLOCKED:no-upstream`, and finish's own already-pushed check (HEAD compared with `$branch@{upstream}`) stops working too.

When this task is done, close finds the branch's remote state even with no upstream configured. It falls back to the remote-tracking ref `refs/remotes/$PEAL_REMOTE/$branch`, which the push updates without writing config. A push whose only failure is the upstream write counts as a successful push.

## Scope

- `close finish`, `close verify` and `close wait`: when `$branch@{upstream}` does not resolve, fall back to `refs/remotes/$PEAL_REMOTE/$branch`.
- A push whose only failure is the upstream config write counts as a successful push.
- Look at the SessionStart reap's "could not delete origin/task/..." warnings (in `plugin/lib/store-files.sh` and `plugin/lib/store-issues.sh`). If they have the same cause, fix them the same way; if not, file them separately.

## Done when

- close.test.sh: a branch pushed with no upstream configured is verified as pushed, and finish skips the push when the remote-tracking ref equals HEAD.

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
