---
plan: auto
size: S
depends: []
touches: [plugin/lib/main-write.sh, plugin/lib/session.sh, plugin/lib/doctor.sh, docs/getting-started.md]
milestone: m8
priority: high
---

# 0196 — After a write to main, a clean checked-out main is fast-forwarded, else one line says it is behind

## Intent

Every Peal write onto main (`idea`, `create`, `retire`, `revise`, `comment`, `set-milestone`, `milestone-state`, `apply`, `ship bump`) is built on a temporary index from the fetched main and pushed (`plugin/lib/main-write.sh`). That is correct and robust, but the primary checkout's `main` is never moved. After `/peal:idea` a newcomer's `ls tasks/backlog` shows nothing and `git status` says `behind 2`; getting-started mentions `git pull` in one clause. Then ordinary git collides: in the usability review's walk the human's own `/peal:setup milestones` commit on main was rejected as a non-fast-forward, and `peal set-milestone 0002 m1` answered "milestone m1 does not exist" because Peal reads main from the remote and the milestone was only local. It was the most confusing state the reviewer hit, three times in one hour. When this is done the checkout follows main or says it does not.

## Scope

- After a successful main write from the primary checkout, when `main` is checked out there, clean, and its tip equals the remote tip the write was built on, fast-forward it (`git merge --ff-only`); a worktree on another branch is left alone. Otherwise print one line: `your checkout's main is 2 behind origin/main: git pull`.
- The same line in the SessionStart orientation and a `main` check in `peal doctor`.
- `main-writes: pr` is untouched (nothing to fast-forward to).
- This is the first-hour trap for a newcomer; the control plane's newcomer test would hit it first.

## Done when

- A test: a main write leaves a clean primary checkout of main at the new tip; a dirty one or one on another branch is left alone and the line is printed.
- `peal doctor` reports a checkout behind origin/main.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Usability review F1 (and F12, P1): the first hour of Peal is made of this.
- Security: none; the fast-forward is `--ff-only` on a clean checkout and never runs hooks of the work tree's choosing beyond git's own.

---

## Outcome

<!-- Written at close, replacing this comment. -->
