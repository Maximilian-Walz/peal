---
plan: required
touches: [tools/test-all.sh]
milestone: later
---

# 0086 — `tools/test-all.sh` runs harnesses in parallel with a `-j` flag

## Intent

0077 split CI's Linux job into parallel shards (`PEAL_HOSTILE_SHARD` for
`hostile.test.sh`, plus a few `tools/test-all.sh` invocations balanced by measured
seconds) so a pull request is not waiting on one long serial run. None of that helps a
contributor running `tools/test-all.sh` locally, which still runs every harness one
after another. A `-j N` mode would let a local run use the machine's other cores the
same way CI now does its shards.

## Scope

## Done when

## Raw

> Defaults kept: 27 harnesses; macOS job unchanged; no concurrency block; shard names as
> planned; an idea for a local `-j` mode in `tools/test-all.sh` filed at close. (0077's
> agreed plan.)

## Notes

- Filed from 0077 (speed up the Linux CI job), which sharded CI's Linux job but left
  `tools/test-all.sh` itself serial.
- Open: whether `-j` should also let a shard of `hostile.test.sh` (`PEAL_HOSTILE_SHARD`,
  added in 0077) run as one of the parallel workers, or stay a separate, finer-grained
  knob CI uses on its own.

---

## Outcome

<!-- Written at close, replacing this comment. -->
