---
plan: auto
size: S
depends: []
touches: [.github/workflows/ci.yml, plugin/lib/hostile.test.sh]
milestone: m7
---

# 0186 — The macOS CI job runs the hostile harness sharded with PEAL_HOSTILE_SHARD

## Intent

The macOS CI job is the pull request's critical path: it took 24.5 minutes of a 25.6 minute run while every Linux shard finished within 12.6 minutes, and 1,270 of its 1,462 seconds are `hostile.test.sh`. `.github/workflows/ci.yml`'s `harnesses-macos` job names seven harnesses and sets `PEAL_HOSTILE_CASES: 'self_test awk_channels'`, which runs the two groups serially; the Linux side is sharded four ways with `PEAL_HOSTILE_SHARD` (supported in `plugin/lib/hostile.test.sh`). Every close waits for green (a median wait of 773 seconds), so this is a wait turn per close and a quarter-hour on the human's merge; and macOS minutes bill at ten times Linux on a private repository. When this is done the macOS hostile run is sharded the same way, or `awk_channels` runs on macOS only under BSD awk (what the job exists for) and `self_test` stays on Linux.

## Scope

- `.github/workflows/ci.yml`: shard the macOS hostile run with `PEAL_HOSTILE_SHARD` (a matrix), keeping every case covered on macOS that is covered there today.
- Pull request wall time goes from about 25 to about 13 minutes; the Outcome records the measured times.

## Done when

- The macOS job's longest shard is under 13 minutes in a run on a code pull request.
- Every hostile group that ran on macOS before still runs there (a check in `tools/` or the workflow itself).

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Performance review finding 2.
- Security: none (CI only); the workflow stays pinned by SHA (`tools/pins.sh`).

---

## Outcome

<!-- Written at close, replacing this comment. -->
