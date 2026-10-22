---
plan: required
size: M
depends: []
touches: [tools/test-all.sh]
milestone: m7
priority: high
---

# 0190 — tools/test-all.sh runs harnesses in parallel with a -j flag

## Intent

0077 split CI's Linux job into parallel shards (`PEAL_HOSTILE_SHARD` for `hostile.test.sh`, plus a few `tools/test-all.sh` invocations balanced by measured seconds) so a pull request is not waiting on one long serial run. None of that helps a contributor or a session running `tools/test-all.sh` locally, which still runs every harness one after another, an hour or more in all. The performance review counts 133 implementer runs and 156 main-session runs of it. A `-j N` mode lets a local run use the machine's other cores the way CI does its shards, and turns the run from an hour-plus into minutes. This task replaces 0086, which sat in the parked `later` milestone: only a milestone review moves a task out of a parked one, so it is retired as a duplicate of this one.

## Scope

- `tools/test-all.sh -j N` runs harnesses as N parallel workers, output kept per harness and printed in order, the exit status the worst of them.
- Open: whether `-j` also lets a shard of `hostile.test.sh` (`PEAL_HOSTILE_SHARD`) run as one of the workers, or stays a separate, finer-grained knob CI uses on its own.

## Done when

- A test (or a documented run) shows `-j 4` running the harnesses in parallel with the same pass and fail result as the serial run.
- CONTRIBUTING.md and the implementer's brief say to use it for a full run.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind
>
> Defaults kept: 27 harnesses; macOS job unchanged; no concurrency block; shard names as planned; an idea for a local `-j` mode in `tools/test-all.sh` filed at close. (0077's agreed plan, 0086's own Raw.)

## Notes

- Carried over from 0086, filed from 0077 (speed up the Linux CI job), which sharded CI's Linux job but left `tools/test-all.sh` itself serial. Performance review finding 1: it matters more than its old place suggested, and is the other half of the one-awk task of this milestone.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
