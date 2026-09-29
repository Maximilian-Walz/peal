---
milestone: m2
priority: high
plan: required
size: M
model: opus
touches: [plugin/lib/store-files.sh, plugin/lib/store-issues.sh, plugin/lib/claim.sh, plugin/lib/backlog.sh, plugin/lib/*.test.sh, plugin/commands/defer.md, docs/reference/*.md, docs/design.md]
---

# 0114 — A deferred task reads as free although its claim's worktree is still there

## Intent

Under Belfry, a session starts inside the worktree of its task. When the session defers the task with `/peal:defer`, `peal defer` writes the task back into main's backlog, but the claim is left behind. The claim's branch still has a worktree, so `list`, `offer` and the board keep deriving `claimed-live`, and the control plane shows the task as in progress after the job has ended. The session cannot fix this itself. `peal release` fails in `git worktree remove` with "Device or resource busy", because that worktree is the session's own working directory. The only ways out today are a human running `peal release` from the main checkout, or the SessionStart reaper half an hour later.

What the human wants:

1. As soon as the defer is on main, the derived state of a deferred task is free, or blocked if its `depends` say so, no matter what is left of its worktree.
2. `peal release` run from inside the worktree it releases still gives the claim back. It deletes the claim branch locally and on the remote, leaves the worktree directory, and says the reaper will remove it.
3. The reaper removes that leftover worktree once no session holds it.

## Scope

- The state `list`, `offer` and `board` derive: a claim whose task has been deferred back onto main counts as released. The signal is a `Deferred YYYY-MM-DD after a claim:` line in main's copy of the task that the claim's fork point lacks. In the issues storage, `peal defer` takes the `in progress` label off, and a local worktree marked deferred no longer counts.
- `peal release`: a deferred claim is released in place from its own worktree. From elsewhere, release falls back to in place when `git worktree remove` fails on a clean worktree. In place, release keeps the tip, detaches HEAD, marks the worktree `peal-released`, deletes the local and remote claim branches, and says that the reaper removes the directory. Any other claim released from inside its own worktree is still refused.
- The reaper removes such a leftover worktree once its heartbeat is idle.
- `peal claim` of a free task whose deferred branch is still there takes that branch over.
- `/peal:defer` step 5, `peal defer`'s last line, and the docs (`docs/reference/{tasks,cli,storage}.md`, `docs/design.md`).

## Done when

- Harness: after a defer, while the claim's worktree still exists, `peal list` shows the task as free or blocked rather than claimed-live, both in the clone that holds the worktree and in a second clone that only sees the remote branch. The same holds for the issues storage.
- Harness: `peal release` run with its cwd inside the worktree drops the claim branch, both local and remote, keeps the tip under `refs/reaped/`, leaves the directory and exits 0.
- Harness: the reaper keeps a leftover while its heartbeat is fresh and removes it once the heartbeat is idle.
- Harness: claiming again after a defer reads `claimed-live`, even on the same day. `peal claim` takes over a leftover that is local and one that exists only on the remote.
- Harness: releasing a claim that was not deferred from inside its own worktree is still refused.

## Raw

> A deferred task reads as free although its claim's worktree is still there
>
> ## Intent
>
> A session under Belfry starts inside its task's worktree. When it defers the task with `/peal:defer`, `peal defer` puts the task back into main's backlog, but the claim stays. `peal list` and the board keep reporting `claimed-live`, so the control plane shows the task as in progress after the job has ended. `peal release` cannot help from inside the job: `git worktree remove` fails with "Device or resource busy", because the worktree is the session's own working directory. The only ways out are a human running `peal release` from the main checkout, or the SessionStart reaper half an hour later. When this is done, a deferred task reads as free (or blocked, if its depends say so) as soon as the defer is on main, whatever is left of its worktree. And `peal release` run from inside the worktree it releases gives the claim back anyway: it deletes the claim branch locally and on the remote, and leaves the worktree directory for the reaper.
>
> ## Scope
>
> - The state `list`, `offer` and `board` derive: a claim whose task has been deferred back onto main counts as released (for example, the claim is marked deferred, or main's copy has a `Deferred ... after a claim` Notes line newer than the claim).
> - `peal release`: when the worktree cannot be removed, still delete the local and remote claim branches, and say that the reaper will remove the directory.
> - The reaper removes such a leftover worktree once no session holds it.
>
> ## Done when
>
> - Harness: after a defer, while the claim's worktree still exists, `peal list` shows the task as free rather than claimed-live.
> - Harness: `peal release` run with its cwd inside the worktree drops the claim branch (both local and remote) and exits 0.
>
> ## Raw
>
> > Belfry friction, 2026-09-29 (job 25694d9b7f264762): deferring 0113 from a job started inside its worktree left `0113 claimed-live`; `peal release 0113` failed on `git worktree remove` (Device or resource busy). Workaround: the human ran `peal release 0113` from the main checkout. Proposed fix: read a deferred claim as free whatever the leftover worktree, and have release remove the branches even when the worktree cannot be deleted.
>
> ## Notes
>
> - Related: 0064 (`tasks.commands.defer`), which also changes how a Belfry session defers.
> - Milestone: m3, Smooth sessions.

## Notes

- Related: 0064 (`tasks.commands.defer`), which also changes how a Belfry session defers. It is not a prerequisite, so it stays out of `depends`. The planner should check that the two do not overlap.
- Milestone m2 with priority high (retriaged in c7ced6c; the idea had named m3).
- `docs/reference/tasks.md` (Claim states): today `claimed-live` means "the branch has a worktree, or exists only on the remote". The table needs a rule for a deferred claim.
- `docs/reference/cli.md` (`peal release`, `peal defer`): `peal defer` already marks the claim deferred and says "Then `peal release ID` from elsewhere". The reaper already lets a deferred claim go even though its task is not done and was touched lately, but it spares "the calling worktree".
- Open question: which signal marks a claim as deferred? The existing deferred mark on the claim, or a `Deferred ... after a claim` line in main's Notes that is newer than the claim? The derived state must still come from refs and the main branch on the remote, never from the calling worktree.
- Open question: how does the reaper tell that no session holds a worktree any more? Is the 30-minute touch window enough once the branches are gone?
- Open question: once `peal release` has deleted the branch, the leftover worktree has no branch behind it. What does `list` show for it, and what do `claim` and the reaper do with it?
- 2026-09-29, the human's answers to the plan's questions:
  - Scope: the Scope from Raw, plus claiming over a leftover and the doc updates. No split.
  - Signal: a `Deferred <date> after a claim:` line on main that the claim's fork point lacks.
  - Issues: `peal defer` takes the label off; a marked local worktree no longer counts.
  - Release in place: for deferred claims only. From elsewhere it is allowed only for a clean worktree.
  - Reaper: the heartbeat idle window plus the `peal-released` marker, with no process probing.
  - Claim: takes a leftover over.
  - Model: opus.
  - The other defaults are agreed:
    - `list` shows a leftover as plain free or blocked.
    - A deferred local branch with no worktree also reads as free.
    - No change to `peal doctor`.
    - Release prints one `released …` line with a suffix.
    - `/peal:defer` no longer asks for ExitWorktree.
    - Belfry's push policy and its cleanup are left unverified and noted in the Outcome.
    - 0064's note must not start with `Deferred <date> after a claim:`. This goes on 0064 as a queued idea or comment, not an edit in this task.

## Plan

Approach:

1. **Deferred signal, files storage.** In `_peal_files_claims`, a branch that would otherwise read `claimed-live` or `parked` is checked against its fork point (`git merge-base <claim ref> <main>`). If main's copy of the task has a line matching `^Deferred YYYY-MM-DD after a claim: ` that the fork point's copy lacks (compared as exact lines), the branch emits no claim line, and task-state.awk derives free or blocked.
2. **Issues storage.** `peal_store_defer` takes the `in progress` label off. In `_peal_issues_claims`, a local worktree whose admin dir holds `peal-deferred` does not count as `wt:`.
3. **Release in place.** `peal_release_verdict` gets a new verdict, `own-deferred`, checked before `own`, and `peal_release` allows it. Both `peal_store_release` implementations get an in-place path. It is used when the worktree is the calling one, or when `git worktree remove` fails on a clean worktree. The path:
   1. Keep the tip under `refs/reaped/`.
   2. `git -C WT checkout -q --detach`.
   3. Write `peal-released` (a timestamp) into the worktree's admin dir.
   4. Delete the local branch, then the remote branch under the existing ancestor check. For issues, also take the label off.
   5. Print `released ID BRANCH, tip kept as REF; the worktree stays at PATH, the SessionStart reaping removes it once idle` and exit 0.

   A dirty worktree reached from elsewhere is refused as today.
4. **Reaper.** `peal_reap` gets a second pass over `git worktree list --porcelain`. It takes detached worktrees under `peal_worktrees_dir` that carry `peal-released`, skipping the calling worktree. Once the heartbeat is older than `PEAL_IDLE_MINUTES`, it removes device files, runs a non-forced `git worktree remove` and prints `reaped leftover PATH`. If git refuses, it prints `kept PATH: …`.
5. **Claiming over a leftover.** In `_peal_claim_one`, a free task whose branch the signal marks deferred is handled before the claim:
   - a local leftover is released, in place if need be;
   - a leftover that exists only on the remote has its tip kept under `refs/reaped/` and is deleted with `--force-with-lease=<branch>:<tip>`.

   Then the task is claimed afresh.
6. **Wording.** `peal defer`'s last line drops "from outside this worktree". In `/peal:defer`, step 5 becomes: run `peal release <id>` where you are, with no ExitWorktree.
7. **Docs.** `docs/reference/tasks.md` (Claim states): a rule for a deferred claim. `docs/reference/cli.md`: `peal release`, `peal defer`, `peal claim`. `docs/reference/storage.md`: the issues claimed-live line. `docs/design.md`: the release and SessionStart bullets.

Files: `plugin/lib/store-files.sh`, `plugin/lib/store-issues.sh`, `plugin/lib/claim.sh`, `plugin/lib/backlog.sh`, `plugin/commands/defer.md`, `plugin/lib/backlog.test.sh`, `plugin/lib/claim.test.sh`, `plugin/lib/store-issues.test.sh`, `docs/reference/tasks.md`, `docs/reference/cli.md`, `docs/reference/storage.md`, `docs/design.md`.

Verification, in `plugin/lib/backlog.test.sh`:

- `files()`:
  - Replace line 104: after the defer, with the worktree still there, `peal list --no-pr 0001` shows `blocked … needs:0002`, and so does a second clone that only sees the remote branch.
  - Replace line 107: `in_wt release 0001` exits 0. The local and remote branches are gone, `refs/reaped/0001-*` exists, the directory stays with a detached HEAD, and the output names the reaper.
  - Reaper: with a fresh heartbeat the leftover is kept; with an aged one (`touch -d`) it prints `reaped leftover`.
  - Fallback: with the worktrees dir made non-writable, release from main exits 0 and deletes the branches.
  - Claiming again the same day after a defer reads `claimed-live`.
  - Claiming over a local leftover and over a remote-only leftover both work.
  - Releasing a claim that was not deferred from inside its worktree is still refused.
- `issues()`: after the defer, `blocked` and the label is off. Replace line 214: `in_wt release 1` exits 0 and `issue/1` is gone locally and on the remote.

Regressions: `claim.test.sh`, `session.test.sh`, `tasks.test.sh`, `store-issues.test.sh` and the doctor harness.

Ranges: plugin/lib/backlog.sh:1-58; plugin/lib/claim.sh:1-72, 163-259, 323-438; plugin/lib/store-files.sh:1-47, 102-175, 575-646, 840-925, 958-1000, 1024-1039; plugin/lib/store-issues.sh:10-27, 109-147, 681-736, 901-946, 968-977; plugin/lib/session.sh:95-144; plugin/lib/doctor.sh:230-270; plugin/lib/backlog.test.sh:1-130, 169-221; plugin/commands/defer.md:51-92; docs/reference/tasks.md:94-105; docs/reference/cli.md:137-147, 336-355; docs/reference/storage.md:49-49; docs/design.md:240-270; tasks/backlog/0064-commands-defer-for-belfry.md:1-77.

---

## Outcome

<!-- Written at close, replacing this comment. -->
