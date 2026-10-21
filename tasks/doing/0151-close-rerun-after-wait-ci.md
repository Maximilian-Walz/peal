---
milestone: m3
plan: skipped
size: S
touches: [plugin/commands/close.md]
---

# 0151 — Close's rerun rule trusts wait_ci's whole-run answer, if it gives one

## Intent

The flaky-failure rule in `plugin/commands/close.md` step 6 still tells a session that waited with Belfry's `wait_ci` to run `gh run watch` before `gh run rerun --failed`, in case a check of the run is still running. `wait_ci` says it answers only once every check of the pushed head has finished; if that holds, the `gh run watch` step is dead weight and the rule can say both waits end only with the whole run. Since 0147, `peal close wait` already does (it holds `WAIT:checks-failing-pending` until nothing is pending).

## Scope

Find out whether a `done: true` from `wait_ci` can come while a check is still running; if not, drop the `gh run watch` step from close.md's rerun rule.

## Done when

close.md's rerun rule says only what the waits actually do, and a session never runs `gh run watch` when it has no need to.

## Raw

> Found in 0147: after 0144 and 0147 both landed, close.md's rerun guidance can be simplified to rely on the waits; the human asked to file it.

## Notes

- Peal never knows Belfry beyond the tool names its command markdown already names; this changes only the instruction text.
- Finding: `wait_ci` answers `done: true` only once every check of the pushed head has finished (or the PR merged or closed); `done: false` means the limit passed first, checks possibly still running. So the `gh run watch` step is dropped; on `done: false` the session waits again rather than rerunning.
