---
milestone: m3
plan: required
---

# 0114 — A deferred task reads as free although its claim's worktree is still there

## Intent

Under Belfry, a session starts inside the worktree of its task. When the session defers the task with `/peal:defer`, `peal defer` writes the task back into main's backlog, but the claim is left behind. The claim's branch still has a worktree, so `list`, `offer` and the board keep deriving `claimed-live`, and the control plane shows the task as in progress after the job has ended. The session cannot fix this itself. `peal release` fails in `git worktree remove` with "Device or resource busy", because that worktree is the session's own working directory. The only ways out today are a human running `peal release` from the main checkout, or the SessionStart reaper half an hour later.

What the human wants:

1. As soon as the defer is on main, the derived state of a deferred task is free, or blocked if its `depends` say so, no matter what is left of its worktree.
2. `peal release` run from inside the worktree it releases still gives the claim back. It deletes the claim branch locally and on the remote, leaves the worktree directory, and says the reaper will remove it.
3. The reaper removes that leftover worktree once no session holds it.

## Scope

## Done when

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
- Milestone m3 because the idea names it.
- `docs/reference/tasks.md` (Claim states): today `claimed-live` means "the branch has a worktree, or exists only on the remote". The table needs a rule for a deferred claim.
- `docs/reference/cli.md` (`peal release`, `peal defer`): `peal defer` already marks the claim deferred and says "Then `peal release ID` from elsewhere". The reaper already lets a deferred claim go even though its task is not done and was touched lately, but it spares "the calling worktree".
- Open question: which signal marks a claim as deferred? The existing deferred mark on the claim, or a `Deferred ... after a claim` line in main's Notes that is newer than the claim? The derived state must still come from refs and the main branch on the remote, never from the calling worktree.
- Open question: how does the reaper tell that no session holds a worktree any more? Is the 30-minute touch window enough once the branches are gone?
- Open question: once `peal release` has deleted the branch, the leftover worktree has no branch behind it. What does `list` show for it, and what do `claim` and the reaper do with it?

---

## Outcome

<!-- Written at close, replacing this comment. -->
