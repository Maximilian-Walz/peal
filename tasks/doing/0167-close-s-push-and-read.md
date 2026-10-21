---
milestone: m3
plan: required
touches: [plugin/lib/common.sh, plugin/lib/close.sh, plugin/lib/store-files.sh, plugin/lib/session.sh, plugin/lib/close.test.sh, plugin/lib/claim.test.sh, plugin/lib/session.test.sh, plugin/lib/decisions.test.sh, plugin/commands/close.md]
size: M
---

# 0167 — Close's push and read-only commands print no raw git config-lock errors in a sandbox

## Intent

In a sandboxed session `.git/config` is not writable. `peal close finish` pushes with `git push -u`, so git prints its raw config-lock errors ("could not lock config file", "unable to write upstream branch configuration") and a hint naming a wrong ref (`origin/refs/heads/task/...`), and finish then adds its own NOTE that the upstream could not be recorded (0101). The pull request still opens, so the lines are noise, but they send sessions chasing them. Close's push should stay quiet about this: push without `-u` (verify and wait already fall back to `$PEAL_REMOTE/$branch`), or capture stderr under `LC_ALL=C` and turn a lock failure into one clear line, as 0121 did for the release.

Commands that should not write config at all hit the same lock: `peal brief planner` failed once on the main checkout's `.git/config.lock` (a bwrap error), and `peal check` in finish printed "could not lock config file .git/config: File exists", which looks like concurrent sessions racing over the shared `.git/config`. `peal brief` and `peal check` should write nothing there, or not fail on a lock.

Merged into this idea: /peal:close step 6 tells sessions to poll GitHub with `peal close wait`; under a harness that offers its own CI wait (such as Belfry's), sessions are told to use that instead, and polling also failed on a host the sandbox denies. Step 6 should say that a harness with its own CI-wait tool uses it, then runs `peal close verify` once.

## Scope

Every push Peal makes from a task branch (claim, resumed claim, session-end autosave, close finish) stops writing the branch's upstream to `.git/config`; readers fall back to `refs/remotes/<remote>/<branch>`. `peal brief` and `peal check` get a harness case only (they write no config). The explicit push command is named where the Stop hook and `/peal:close` say "push". Step 6's CI-wait wording and `docs/design.md` stay as they are.

## Done when

- Claim, resumed claim, the session-end autosave and close finish push without `-u` and print no raw git config-lock lines under a locked `config.lock`; finish's 0101 NOTE is gone.
- `peal brief` and `peal check` exit 0 with no lock line under a locked `config.lock`.
- Verify, the Stop hook, release and the autosave find a push through the tracking ref when no upstream is set.
- A harness case per push site with a locked `config.lock` shows a clean run, the remote updated and no `branch.<b>.merge` written.
- The Stop hook message and `close.md`'s push mentions name `git push <remote> <branch>`.
- Step 6 of `/peal:close` already uses a harness's CI-wait tool on main: no change.

## Raw

> Close's push and the read-only commands print no raw git config-lock errors in a sandbox
>
> ## Intent
>
> In a sandboxed session `.git/config` cannot be written. `peal close finish` pushes with `git push -u`, and git then prints "error: could not lock config file", "unable to write upstream branch configuration" and a hint naming a wrong ref (`origin/refs/heads/task/...`). Then finish adds its own NOTE that the upstream could not be recorded (0101). The PR still opens fine, so the raw lines are only noise, but they send sessions off chasing them (task 0121's Notes could not trace that hint; it comes from this push, not from the release).
>
> Two other sessions saw the same lock from commands that should not write config at all: `peal brief planner` failed once with a bwrap error on the main checkout's `.git/config.lock`, and `peal check` in finish printed "could not lock config file .git/config: File exists". That looks like concurrent sessions racing over the shared `.git/config`.
>
> ## Done when
>
> - Close's push no longer prints git's raw config-lock lines. Either it pushes without `-u` (verify and wait already fall back to `$PEAL_REMOTE/$branch`), or it captures stderr under `LC_ALL=C` and turns a lock failure into one clear line, as 0121 did for the release.
> - `peal brief` and `peal check` write nothing to `.git/config`, or a lock there does not fail them.
> - A harness case with a read-only `.git/config` shows a clean finish.
>
> ## Notes
>
> - Code: `plugin/lib/close.sh`, the `git push -q -u` in finish and the NOTE after it.
> - Reported by sessions of 0121 and two other close runs.
>
> ### Merged: /peal:close step 6 tells the session to poll GitHub with `peal close wait`, but Belfry jobs must wait for CI with…
>
> Friction 2 sessions reported, in peal: the tooling around their work got in their way.
>
> ### Job 2a8a4654e905cd95 (peal)
>
> - **Tried:** Run `peal close wait` in a Belfry sandboxed session, as /peal:close step 6 says.
> - **What happened:** /peal:close tells headless Belfry sessions to poll GitHub with `peal close wait`. The run polled gh, gh tried to reach cafe.github.com (denied by the sandbox), and it returned WAIT:checks-pending. Polling also goes against Belfry's rule to wait with wait_ci. Separately, `peal brief planner` failed once with a bwrap error on the main checkout's .git/config.lock, and peal check in finish printed "could not lock config file .git/config: File exists". Both look like races between concurrent sessions over the shared .git/config.
> - **Workaround:** Used belfry wait_ci on the PR; retried peal brief.
> - **Proposed fix:** Have /peal:close step 6 say: under a harness that offers a CI-wait tool (e.g. Belfry's wait_ci), use it instead of `peal close wait`. Also, avoid writing .git/config from read-only commands like brief/check.
>
> ### Job d6f08ff78f918614 (peal)
>
> - **Tried:** Ran `peal close wait`, as /peal:close step 6 says, in a sandboxed Belfry job.
> - **What happened:** /peal:close step 6 tells the session to poll GitHub with `peal close wait`, but Belfry jobs must wait for CI with wait_ci. On top of that, the poll touched cafe.github.com, which the sandbox denies, and it came back WAIT:checks-pending.
> - **Workaround:** Waited with Belfry's wait_ci. All 12 checks passed.
> - **Proposed fix:** In close.md step 6, say that a harness with its own CI wait (such as Belfry's wait_ci) should use it, and run `peal close verify` once afterwards. Without that, the command steers sessions into polling GitHub.

## Notes

- Milestone m3 is the human's choice.
- Open: which of `peal brief` / `peal check` actually writes `.git/config` (perhaps `peal_hooks_ensure` setting `core.hooksPath`, task 0059, or another `git config` write on every run)? The planner should trace it before choosing between "write nothing" and "tolerate the lock".
- Open: the close.md step-6 wording must stay generic. Peal never knows Belfry (`docs/design.md`), so the command can say "a harness with its own CI-wait tool" but not name Belfry's tool.
- Open: should the step-6 change ride in this task or split off? It touches `plugin/commands/close.md`, not the push.
- Context: `docs/design.md` (Peal and Belfry independence); `docs/reference/cli.md` (close finish/wait/verify, brief, check).
- Planner trace: neither `peal brief` nor `peal check` writes `.git/config`. The lock lines came from finish's `push -u` (printed right after `checks.close`, whose last step is `peal check`) and from the sandbox's own `config.lock` handling.
- Human, 2026-10-21: step 6 and design.md stay as they are (already on main); brief/check get a harness case only; drop `-u` at every push site here (claim, resume, autosave, finish), not only finish; name the explicit `git push <remote> <branch>` in the Stop hook message and close.md's push mentions; 0167 lands first and 0168 merges main in (a note on 0168, no depends); merge default (a human looks).
- Defaults agreed: release's inline fallback (`claim.sh:510-511`) left alone; the tracking ref is assumed to exist, as Peal already does; `peal_hooks_ensure`'s first `core.hooksPath` write under a lock is queued as an idea; the setup/next docs' human-run `git push -u` left alone.

## Plan

Approach:
1. Move `_peal_close_remote_ref` from `close.sh` to `plugin/lib/common.sh` as `peal_remote_ref BRANCH REMOTE`: the upstream when one exists, else `refs/remotes/REMOTE/BRANCH`, else status 1. Close's callers pass `$PEAL_REMOTE`; session-end passes its remote.
2. `close.sh` finish: `git push -q "$PEAL_REMOTE" "$branch"` (no `-u`); delete the NOTE block; update the comments at 487-501, 573-576 and the helper's. Real push failures still print git's stderr.
3. `store-files.sh`: claim (1019) and resume (1058) push without `-u`; claim keeps its `LC_ALL=C` captured-stderr race handling; update the "tracks" comments.
4. `session.sh` autosave (320-324): `ref=$(peal_remote_ref "$branch" "$remote")`; nothing to do when the ref exists and `ref..branch` counts 0, else `git push -q "$remote" "$branch"`; update the comment at 290-294.
5. The Stop hook message (`close.sh` ~705-709) and `close.md`'s push mentions (67, 158, 165, 192) name `git push <remote> <branch>`; step 6's CI-wait logic is untouched.
6. Harnesses, each with `config.lock` in the common git dir and hooks already installed:
   - `claim.test.sh`: new claim and resumed claim under the lock: exit 0, no `could not lock`/`error:`/`hint:`, remote tip and tracking ref at HEAD, `branch.<b>.merge` empty; line 143 flips to "no upstream recorded".
   - `session.test.sh` autosave: under the lock an unpushed commit is pushed with no lock line in `peal-session-end.log`; a second run pushes nothing; 155-160 flip to "no upstream, pushed by the tracking ref".
   - `close.test.sh` `no_upstream_cases`: finish under the lock with and without a pre-set upstream: no lock/`error:`/`hint:` lines, no NOTE; `peal check` and `peal brief planner` under the lock exit 0 with clean stderr.
   - Existing `@{upstream}` / bare-push assertions rewritten to push `origin HEAD` explicitly or to count against `refs/remotes/origin/$b`: `claim.test.sh:143,173,358`, `session.test.sh:155-160`, `close.test.sh:77,322,431,519,628,630,727,910,920`, `decisions.test.sh:459`.

Files: `plugin/lib/common.sh`, `plugin/lib/close.sh`, `plugin/lib/store-files.sh`, `plugin/lib/session.sh`, `plugin/lib/close.test.sh`, `plugin/lib/claim.test.sh`, `plugin/lib/session.test.sh`, `plugin/lib/decisions.test.sh`, `plugin/commands/close.md`.

Verification: `bash plugin/lib/close.test.sh`, `claim.test.sh`, `session.test.sh`, `decisions.test.sh`, `backlog.test.sh`, `tools/lint.sh`; `tools/test-all.sh` before close.

Ranges: `plugin/lib/close.sh:487-628`, `close.sh:662-674`, `close.sh:700-712`, `close.sh:755-762`, `close.sh:809-829`, `plugin/lib/store-files.sh:967-1063`, `plugin/lib/session.sh:290-327`, `plugin/lib/claim.sh:495-517`, `plugin/lib/common.sh:151-166`, `plugin/lib/git-guard.sh:195-219`, `plugin/lib/work.sh:83-133`, `plugin/lib/tasks.sh:118-197`, `plugin/bin/peal:358-368`, `plugin/lib/close.test.sh:28-105`, `close.test.sh:380-415`, `close.test.sh:804-819`, `plugin/lib/claim.test.sh:136-180`, `claim.test.sh:231-254`, `claim.test.sh:345-360`, `plugin/lib/session.test.sh:122-166`, `plugin/lib/decisions.test.sh:435-459`, `plugin/commands/close.md:60-70`, `close.md:147-211`, `tools/lint.sh:31-38`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
