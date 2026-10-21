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

---

## Outcome

The rerun rule in `plugin/commands/close.md` step 6 no longer tells a session to run `gh run watch` after `wait_ci`. It says instead that `wait_ci` with `done: true` ends only once every check of the pushed head has finished, so neither wait needs `gh run watch`, and that `done: false` means the limit passed with checks possibly running: wait again, do not rerun.

The finding: `wait_ci`'s own tool description says it answers when a look begun after the call finds every check of the pushed head finished (or the PR merged or closed); `done: false` means the time limit passed first. So a `done: true` never comes with a check still running, and the `gh run watch` step was dead weight. `peal close wait` already holds until nothing is pending (0147).

Verified: `plugin/commands/commands.test.sh` passes; no other file in plugin/, docs/ or README.md mentions `gh run watch`. The reviewer found nothing.

For the next session: the rule relies on `wait_ci`'s documented contract; if that tool ever answers early, the rule needs the watch step back.
