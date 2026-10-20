---
milestone: m3
plan: required
touches: [plugin/lib/github.sh, plugin/lib/close.sh]
---

# 0147 — Close wait reports a failure only once the whole run has finished

## Intent

`peal close wait` and verify's `BLOCKED:checks-failing` report a failure as soon as one check has failed, even while other checks of the same run are still running. `peal_pr_checks` tests for failing before pending, and `peal close wait` stops on any verdict other than `WAIT`. So a session sees a failure before the run is over and cannot use the wait to learn the whole run's outcome, or to know when a rerun of the failed jobs is possible. Once this is done, the wait holds on until the pending checks have finished, then reports the failure, so the session sees how the whole run ended.

## Scope

## Done when

## Raw

> peal close wait (and verify's BLOCKED:checks-failing) reports a failing check while other checks of the run are still pending, because peal_pr_checks tests failing before pending (plugin/lib/github.sh:116-117) and close wait stops on any non-WAIT verdict (plugin/lib/close.sh:757). Make it wait for the pending checks before reporting the failure, so a session sees the whole run's outcome. Found in 0144; the human asked to file it.

## Notes

- Found in 0144, which tells sessions to wait with `gh run watch` before rerunning a flaky failure, because neither wait waits for the whole run. Once this lands, that guidance in `plugin/commands/close.md` step 6 could rely on `peal close wait` instead.
- Open question: verify's verdict is also used outside close (`plugin/lib/main-write.sh:347`, ship). Does the change apply there too, or only to the wait? Holding the verdict delays every real failure until the slowest job.
- Open question: Belfry's `wait_ci` behaves the same way under Belfry. That is Belfry's side, not this task's.
- Context: `docs/design.md` and `docs/reference/cli.md` describe the waits.

---

## Outcome

<!-- Written at close, replacing this comment. -->
