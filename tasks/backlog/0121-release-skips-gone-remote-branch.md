---
plan: required
---

# 0121 — Release and the reaper do not warn about a remote branch already gone

## Intent

At a session start, the reaper printed `warning: could not delete origin/task/0058-...`
and the same for 0113, although GitHub had already deleted both branches on merge: the
local `refs/remotes/origin/...` refs were stale, so the remote delete failed on a branch
the remote no longer has. When the delete fails, tell "already gone" (prune the stale
tracking ref, no warning) apart from a real failure (warn as now).

## Scope

## Done when

## Raw

> peal: warning: could not delete origin/task/0058-setup-points-at-next (session-start
> output seen in the m2 review, 0046; a pruning fetch then showed both branches already
> deleted on origin)

## Notes

2026-10-19: Also seen (friction from a sandboxed session, 2026-10-18): in a sandbox, git config writes fail with "could not lock config file .../.git/config: File exists". At session start, the reap's stale-ref delete then fails and warns, and git's hint names a wrong ref (`origin/refs/heads/...`). Close's half of this, the upstream that could not be recorded, is done in 0101. When the delete fails, tell three cases apart: already gone (prune, no warning), a locked config (one clear line saying so), and a real failure (warn as now). Where possible, avoid config writes in the reap altogether.

- The code: `plugin/lib/store-files.sh` around the `could not delete` warning in the
  release path, and its twin in `plugin/lib/store-issues.sh`.
- Open: `git ls-remote` after a failed delete costs a network call; matching the error
  text ("remote ref does not exist") is cheaper but depends on git's wording.

---

## Outcome

<!-- Written at close, replacing this comment. -->
