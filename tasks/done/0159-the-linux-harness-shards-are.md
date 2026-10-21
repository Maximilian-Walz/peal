---
milestone: m3
plan: required
priority: high
size: S
touches: [.github/workflows/ci.yml, tools/test-all.sh, tools/test-all.test.sh, CONTRIBUTING.md]
---

# 0159 — The Linux harness shards are balanced again, so no shard runs much longer than the others

## Intent

Since 0152 the hostile shards take about 3 minutes, so the slowest required job on every pull request is now `linux (rest)`. On recent main runs it took 18, 22, 24 and 28 minutes, against 5 to 12 for `linux (a)`, `(b)` and `(c)`. `rest` runs every harness the other shards do not name, and the harnesses added since 0077 measured the split. Among them is `plugin/lib/apply.test.sh` (0112), which landed there by default.

The slowest harnesses in `rest`, from main's run at 2026-10-21 06:22: `tools/docs.test.sh` 296 s, `plugin/lib/apply.test.sh` 293 s, `plugin/lib/next.test.sh` 144 s, `plugin/lib/claim.test.sh` 127 s, `plugin/lib/ship.test.sh` 118 s, `plugin/lib/tasks.test.sh` 85 s, `plugin/lib/session.test.sh` 85 s, `plugin/lib/main-write.test.sh` 63 s. Shards `a`, `b` and `c` name 3 or 4 harnesses each.

Split them again by measured seconds, as 0077 did, so that every Linux shard, `rest` included, finishes in about the time of the slowest named one (around 10 minutes, or less with another shard). Keep `rest` computed, so a new harness is still covered the moment it exists, and make the next drift visible: CI warns when a shard takes much longer than the others, or `tools/test-all.sh` prints the shard's total.

## Scope

- `.github/workflows/ci.yml`: shard lists, a new named shard `d`, timeouts, comments, `PEAL_TEST_BUDGET`.
- `tools/test-all.sh`: prints its total; warns over `PEAL_TEST_BUDGET`.
- `tools/test-all.test.sh` (new): the harness for `tools/test-all.sh`.
- `CONTRIBUTING.md`: one sentence on how the shards are balanced and how drift shows.

## Done when

- On the pull request's CI, every Linux shard job finishes within about 12.5 minutes, and no non-hostile shard's harness total is above 1.15× another's.
- `rest` is still computed and runs every `*.test.sh` the named shards do not name.
- `tools/test-all.sh` prints its total, and warns (never fails) when the total exceeds `PEAL_TEST_BUDGET`; under `GITHUB_ACTIONS=true` the warning is a `::warning` annotation.
- `tools/test-all.test.sh` covers the total, the warning, its annotation form and a bad budget value.

## Raw

> Since 0152 the hostile shards take 3 minutes, but linux (rest) takes 18 to 28 minutes on every run (docs.test.sh and apply.test.sh about 5 minutes each), while a, b and c take 5 to 12. Rebalance the shards so pull requests wait about 12 minutes.

## Notes

- 0128 (the docs harness runs faster) shrinks `tools/docs.test.sh` itself. Rebalancing does not wait for it, but the measured seconds change once it lands.
- `.github/workflows/ci.yml` never merges by itself under Belfry, so the human merges this one.
- The anchors `&shard_a` and so on, and the "rest" step that reads them, are in `.github/workflows/ci.yml`; 0077's notes have how the split was measured.
- 2026-10-21, plan agreed with the human: Scope and Done when as above; a fifth named shard `d`; drift shows as both the total and a budget warning (`PEAL_TEST_BUDGET=780` for every Linux shard, one value); the smaller defaults below as the planner proposed.
- Measured after 0128 landed (main run 39561021393, 07:18): `tools/docs.test.sh` is now 31 s. rest ≈1210 s (apply 309, next 144, claim 135, ship 122, session 89, tasks 88, main-write 64, doctor 53, review 41, init 39, setup 35, docs 31, migrate 20, commit 20, rest small); a ≈600 (close 549, frontmatter 29, git-guard 23); b ≈451 (store-issues 268, decisions 162, milestones 21); c ≈576 (backlog 192, store-files 181, githooks 107, work 96). Run 39559464837 (07:04) has the same shape, 15 to 20% faster.

## Plan

Approach: a fifth named shard `d`, balanced from run 39561021393 (cross-check 39559464837):

| shard | harnesses | seconds |
|---|---|---|
| a | close, frontmatter | ≈578 |
| b | store-issues, decisions, ship, milestones | ≈573 |
| c | backlog, store-files, githooks, work (unchanged) | ≈576 |
| d | apply, next, claim | ≈588 |
| rest (computed) | everything else, git-guard included | ≈520 |

- `.github/workflows/ci.yml`: add `shard: d` anchored `&shard_d`, alias `SHARD_D: *shard_d` in the rest step and include it in `named=`; move `ship` to b and `git-guard` to rest; `rest`'s timeout 45 → 20 and the comment above `timeout-minutes` fixed; the job comment cites 0159 and the run id; job-level `env: PEAL_TEST_BUDGET: '780'` on `linux`.
- `tools/test-all.sh`: always print the total (`test-all: all N harnesses passed in Ts`, and the total on the failure line too); optional `PEAL_TEST_BUDGET=<seconds>`: over it, a warning on stderr, as `::warning title=…::` under `GITHUB_ACTIONS=true`; exit status unchanged. A value that is not a non-negative integer exits 2 before anything runs. Header comment updated.
- `tools/test-all.test.sh` (new): throwaway harnesses in a temp dir passed as absolute paths; cases: all pass (total, exit 0), one fails (failed list, total, exit 1), budget 0 with a 1 s harness (warning, exit 0), `GITHUB_ACTIONS=true` (`::warning` prefix), budget unset or above total (no warning), `PEAL_TEST_BUDGET=abc` (exit 2, nothing run).
- `CONTRIBUTING.md` (around lines 63-66): one sentence: shards are balanced from `test-all.sh`'s timings, it prints its total, CI warns over `PEAL_TEST_BUDGET`. No fenced block.
- Hostile shards stay 4/4; that 3 might do is noted in the Outcome.

Verification: `tools/test-all.test.sh` and `tools/lint.sh` pass; on the pull request's CI all Linux jobs and the gate pass, the `rest` list holds no path a/b/c/d name, the union of a, b, c, d, rest and hostile is every `*.test.sh`, each non-hostile total ≤ about 660 s, no job over about 12.5 minutes, no budget warning fires. If a shard comes out over target, reshuffle once from that run's numbers. Record the run id and timings in the Outcome.

Ranges:
- tasks/doing/0159-the-linux-harness-shards-are.md:1-35
- .github/workflows/ci.yml:85-177
- .github/workflows/ci.yml:179-200
- tools/test-all.sh:1-40
- CONTRIBUTING.md:47-66
- tasks/done/0077-speed-up-linux-ci.md:49-70
- tasks/done/0077-speed-up-linux-ci.md:156-182

---

## Outcome

Rebalanced the Linux harness shards by measured seconds, from main run 39561021393 (after 0128 made `tools/docs.test.sh` about 31 s). There is a fifth named shard `d` (apply, next, claim). `ship` moved to `b`, and `git-guard` moved from `a` to the computed `rest`. On those numbers each non-hostile shard holds about 520 to 590 s of harnesses: a 578, b 573, c 576, d 588, rest about 525. `close.test.sh` (about 550 s) stays the floor for any one shard. `rest` is still computed from `find` minus the anchored lists, and its timeout dropped from 45 to 20 minutes like the others.

Drift now shows in two ways:
- `tools/test-all.sh` prints its total on both the passed line and the failed line.
- With `PEAL_TEST_BUDGET=<seconds>` set, a total over the budget warns without changing the exit status. Under `GITHUB_ACTIONS=true` the warning is a `::warning` annotation. A value that is not a non-negative integer exits 2 before anything runs.

CI sets the budget to 780 s for every Linux shard, about 30% over the target, because two main runs differed by 15 to 20% from noise alone. The new `tools/test-all.test.sh` (24 checks) covers the total, the warning, its annotation form and bad values. It runs in `rest`.

Why a budget and not a comparison of shard durations in the gate job: a comparison needs `actions: read` or an artifact action, and a fixed per-shard budget catches the same drift.

The first Done when line, the timings, can only be met on the pull request's own CI run. The run id and the per-shard figures are added below once it is green. If a shard comes in over target, reshuffle once from that run's numbers.

For the next session:
- The hostile shards take 3 to 4 minutes each at 4/4. Three of them would still finish well under the others and would pay back the extra runner `d` costs. That was left out of scope.
- When a budget warning appears, re-measure from that run's `test-all` timings and move harnesses between the anchored lists in `ci.yml`.

The review found nothing to act on.
