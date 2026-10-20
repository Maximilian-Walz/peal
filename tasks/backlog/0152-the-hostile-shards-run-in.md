---
milestone: m3
plan: required
priority: high
---

# 0152 — The hostile shards run in minutes again, print progress, and a job that hangs fails fast

## Intent

Since `peal apply` (0112, #231) merged, the Linux hostile shards of CI take 7 to 44 minutes each instead of 2 to 5. On main, the four shards took 3, 3, 5 and 2 minutes at a10b7d1 (0129). At 136c108 (0112) they took 7, 8, 28 and 10 minutes. Since 0132 one of them takes about 42 minutes on most runs (43c528a: 19, 11, 17 and 42 minutes). So every pull request waits about 45 minutes for its required `harnesses (ubuntu-latest)`, which waits for the slowest shard. That slows every close, every release (`peal ship bump` waits for its pull request) and every pull request Belfry merges by itself.

The slow shard prints nothing between `== plugin/lib/hostile.test.sh` and its result (on 43c528a: "hostile shard 1/4: ran 724 of 2894 tries", "789 passed", 2509 s). For 40 minutes it looks hung, and a release session cancelled one that would have passed. The workflow sets no `timeout-minutes`, so a real hang would hold a runner for GitHub's 6 hours.

Bring each shard back to a few minutes, make a long shard show that it is alive, and have a job that does hang fail within minutes.

## Scope

## Done when

## Raw

> CI got slow: the hostile shards take up to 42 minutes since peal apply, print nothing meanwhile, and have no timeout. Find what made them slow and bring them back to minutes, show progress, and fail a hang fast.

## Notes

- First suspect, unconfirmed: 0112 added hostile cases (`apply, raw values` and `apply, escaped values [...]`, one per hostile value) whose batch holds a `file` proposal. A `file` makes `peal apply` file a task: a commit (the shard's log shows `commit-msg: a wip commit; the checks are skipped` lines) and a write onto main, which may wait or poll as `peal ship bump` does. Time one such try first. The fix is perhaps a stub for the main write in those cases, or one escaped case instead of one per value.
- The shards split `hostile.test.sh` by tries (`PEAL_HOSTILE_SHARD`), not by time, so the slow cases pile into whichever shard gets them. Splitting by measured time (as the non-hostile shards are) would spread them, but only once each try is fast.
- Progress: a line per group, or every N tries, with the elapsed time, so a long shard is visibly alive.
- `timeout-minutes` on each job of `.github/workflows/ci.yml`, a few times its normal duration. That file never merges by itself under Belfry, so the human merges this one.
- Measured on main's push runs, 2026-10-19 to 10-20.

---

## Outcome

<!-- Written at close, replacing this comment. -->
