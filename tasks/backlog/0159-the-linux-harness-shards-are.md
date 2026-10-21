---
milestone: m3
plan: required
priority: high
---

# 0159 — The Linux harness shards are balanced again, so no shard runs much longer than the others

## Intent

Since 0152 the hostile shards take about 3 minutes, so the slowest required job on every pull request is now `linux (rest)`. On recent main runs it took 18, 22, 24 and 28 minutes, against 5 to 12 for `linux (a)`, `(b)` and `(c)`. `rest` runs every harness the other shards do not name, and the harnesses added since 0077 measured the split. Among them is `plugin/lib/apply.test.sh` (0112), which landed there by default.

The slowest harnesses in `rest`, from main's run at 2026-10-21 06:22: `tools/docs.test.sh` 296 s, `plugin/lib/apply.test.sh` 293 s, `plugin/lib/next.test.sh` 144 s, `plugin/lib/claim.test.sh` 127 s, `plugin/lib/ship.test.sh` 118 s, `plugin/lib/tasks.test.sh` 85 s, `plugin/lib/session.test.sh` 85 s, `plugin/lib/main-write.test.sh` 63 s. Shards `a`, `b` and `c` name 3 or 4 harnesses each.

Split them again by measured seconds, as 0077 did, so that every Linux shard, `rest` included, finishes in about the time of the slowest named one (around 10 minutes, or less with another shard). Keep `rest` computed, so a new harness is still covered the moment it exists, and make the next drift visible: CI warns when a shard takes much longer than the others, or `tools/test-all.sh` prints the shard's total.

## Scope

## Done when

## Raw

> Since 0152 the hostile shards take 3 minutes, but linux (rest) takes 18 to 28 minutes on every run (docs.test.sh and apply.test.sh about 5 minutes each), while a, b and c take 5 to 12. Rebalance the shards so pull requests wait about 12 minutes.

## Notes

- 0128 (the docs harness runs faster) shrinks `tools/docs.test.sh` itself. Rebalancing does not wait for it, but the measured seconds change once it lands.
- `.github/workflows/ci.yml` never merges by itself under Belfry, so the human merges this one.
- The anchors `&shard_a` and so on, and the "rest" step that reads them, are in `.github/workflows/ci.yml`; 0077's notes have how the split was measured.

---

## Outcome

<!-- Written at close, replacing this comment. -->
