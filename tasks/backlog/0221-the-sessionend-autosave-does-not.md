---
milestone: m7
plan: auto
size: S
depends: []
touches: [plugin/lib/session.sh, plugin/lib/session.test.sh]
---

# 0221 — The SessionEnd autosave does not re-push a branch whose task is done or whose pull request merged

## Intent

Peal's remote keeps `task/00xx-*` branches of done tasks (0046, 0055, 0056, 0067, 0068, 0088, 0090 and more) although the ruleset deletes merged branches: the SessionEnd autosave (`peal_session_end`, `plugin/lib/session.sh:307-339`) pushes the branch again after the merge, recreating it; 0168 fixed the rewrite, not the recreation. A stale `peal/main-write-*` branch is on the remote too. Stale branches make a fabricated-ref confusion (0178) likelier and clutter every `git fetch`. When this is done the autosave pushes only a branch whose task is still open.

## Scope

- `peal_session_end`: skip the push when the task is `done` on main or the branch's pull request is merged or closed (one read of the remote ref or the board; no gh needed: a merged branch is gone from the remote after the ruleset deletes it, and a done task is in `tasks/done/`).
- `session.test.sh` covers it.

## Done when

- A harness case: a worktree whose task is done sees no push at session end; an open task's worktree pushes as before.
- The Outcome lists the stale branches found on this repository's remote and deletes them (a human step if the token lacks it).

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Reliability review finding 9, Peal side; the control plane's worktree pruning is its belfry#734.
- Security: none; fewer pushes, none new.

---

## Outcome

<!-- Written at close, replacing this comment. -->
