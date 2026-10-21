---
milestone: m3
plan: required
touches: [plugin/lib/close.sh]
---

# 0167 — Close's push and read-only commands print no raw git config-lock errors in a sandbox

## Intent

In a sandboxed session `.git/config` is not writable. `peal close finish` pushes with `git push -u`, so git prints its raw config-lock errors ("could not lock config file", "unable to write upstream branch configuration") and a hint naming a wrong ref (`origin/refs/heads/task/...`), and finish then adds its own NOTE that the upstream could not be recorded (0101). The pull request still opens, so the lines are noise, but they send sessions chasing them. Close's push should stay quiet about this: push without `-u` (verify and wait already fall back to `$PEAL_REMOTE/$branch`), or capture stderr under `LC_ALL=C` and turn a lock failure into one clear line, as 0121 did for the release.

Commands that should not write config at all hit the same lock: `peal brief planner` failed once on the main checkout's `.git/config.lock` (a bwrap error), and `peal check` in finish printed "could not lock config file .git/config: File exists", which looks like concurrent sessions racing over the shared `.git/config`. `peal brief` and `peal check` should write nothing there, or not fail on a lock.

Merged into this idea: /peal:close step 6 tells sessions to poll GitHub with `peal close wait`; under a harness that offers its own CI wait (such as Belfry's), sessions are told to use that instead, and polling also failed on a host the sandbox denies. Step 6 should say that a harness with its own CI-wait tool uses it, then runs `peal close verify` once.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
