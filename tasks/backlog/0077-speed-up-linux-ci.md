---
milestone: m1
plan: required
size: M
touches: [.github/workflows/ci.yml]
---

# 0077 — Speed up the Linux CI job, the one pull requests actually wait on

## Intent

0065 (the macOS side of the hostile harness) found that CI's history contradicts its
own starting premise: since 0039, the Linux harnesses job has taken 29-36 minutes
against macOS's 21-24 (runs 36129832834 and 36163270642). Linux, not macOS, is the job
a pull request actually waits on. 0065 only trims the macOS job's set and forces
/bin/bash there; this task speeds up Linux itself.

## Scope

- Find where the Linux job's time actually goes: `apt-get update`/install of the awks,
  `npm install -g @anthropic-ai/claude-code`, or the harnesses themselves (0065 added
  per-harness timing output to `tools/test-all.sh`; use it).
- Cut it: caching the apt/npm installs across runs, running harnesses in parallel, or
  trimming what has to run on every pull request, whichever the numbers point to.
- `.github/workflows/ci.yml` only; job names stay as they are (required checks on main).

## Done when

- The Linux job takes meaningfully less than today's 29-36 minutes on a normal pull
  request, with a real run's number quoted in the pull request that closes this.
- Every harness that runs on Linux today (all 26, or their replacement) still does;
  nothing Linux alone covers stops running there.

## Raw

Filed from 0065, whose human answers said: the macOS goal is at most 1/3 of today's
time, as written; the Linux time becomes this follow-up task.

## Notes

- 0065's plan: "the planner found that CI's history contradicts the premise. Since
  0039, Linux takes 29-36 minutes and macOS 21-24 (runs 36129832834 and 36163270642),
  so Linux is the job pull requests wait on."
- 0065 added per-harness elapsed-seconds output to `tools/test-all.sh`; start from a
  real run's numbers rather than guessing which step is slow.

---

## Outcome
