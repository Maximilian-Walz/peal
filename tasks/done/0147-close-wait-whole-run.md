---
milestone: m3
plan: required
touches: [plugin/lib/github.sh, plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/lib/main-write.sh, plugin/lib/main-write.test.sh, plugin/lib/fake-gh, docs/reference/cli.md, plugin/commands/close.md]
size: S
---

# 0147 — Close wait reports a failure only once the whole run has finished

## Intent

`peal close wait` and verify's `BLOCKED:checks-failing` report a failure as soon as one check has failed, even while other checks of the same run are still running. `peal_pr_checks` tests for failing before pending, and `peal close wait` stops on any verdict other than `WAIT`. So a session sees a failure before the run is over and cannot use the wait to learn the whole run's outcome, or to know when a rerun of the failed jobs is possible. Once this is done, the wait holds on until the pending checks have finished, then reports the failure, so the session sees how the whole run ended.

## Scope

The verdict of `peal_pr_checks`, `peal close verify` and `peal close wait`: `plugin/lib/github.sh`, `plugin/lib/close.sh` (comment) and their tests, the case arm in `plugin/lib/main-write.sh` with its test, `plugin/lib/fake-gh`, `docs/reference/cli.md`, and one sentence in `plugin/commands/close.md` step 6. Belfry's `wait_ci` is out of scope.

## Done when

With a check failed and another still pending, verify answers a `WAIT` naming the failure (`WAIT:checks-failing-pending`) and `close wait` keeps waiting; once nothing is pending it answers `BLOCKED:checks-failing`; harness cases prove both. Main writes (idea filing, ship) still fail fast.

## Raw

> peal close wait (and verify's BLOCKED:checks-failing) reports a failing check while other checks of the run are still pending, because peal_pr_checks tests failing before pending (plugin/lib/github.sh:116-117) and close wait stops on any non-WAIT verdict (plugin/lib/close.sh:757). Make it wait for the pending checks before reporting the failure, so a session sees the whole run's outcome. Found in 0144; the human asked to file it.

## Notes

- Found in 0144, which tells sessions to wait with `gh run watch` before rerunning a flaky failure, because neither wait waits for the whole run. Once this lands, that guidance in `plugin/commands/close.md` step 6 could rely on `peal close wait` instead.
- Open question: verify's verdict is also used outside close (`plugin/lib/main-write.sh:347`, ship). Does the change apply there too, or only to the wait? Holding the verdict delays every real failure until the slowest job.
- Open question: Belfry's `wait_ci` behaves the same way under Belfry. That is Belfry's side, not this task's.
- Context: `docs/design.md` and `docs/reference/cli.md` describe the waits.
- 2026-10-20, the human's answers on the plan: main writes stay fail-fast (only close's verify and wait hold on); close.md step 6 gets one sentence for the new verdict; the verdict is named `WAIT:checks-failing-pending`; "the run" is all checks on the commit, not one Actions workflow run; budget and the cap of six waits unchanged; Belfry's `wait_ci` out of scope.
- 2026-10-20, 0144 is finished and awaiting merge, with its `gh run watch` rerun guidance in close.md step 6: its file is not edited. The Outcome mentions the link, and close files an idea to simplify that guidance once both have landed.

## Plan

Agreed with the human on 2026-10-20. Size S.

Approach:
1. `peal_pr_checks` (`plugin/lib/github.sh:96-128`): failing > 0 and pending > 0 prints `WAIT:checks-failing-pending`, status 3; failing > 0 and pending = 0 stays `BLOCKED:checks-failing`, status 1; failing = 0 unchanged. Header comment updated.
2. `plugin/lib/close.sh`: no logic change (verify passes the line through, wait loops on any `WAIT:*`); update the verdict list in the comment at 681-695. When the budget runs out the last line stands (`WAIT:checks-failing-pending`, 3).
3. `_peal_mw_merge_self` (`plugin/lib/main-write.sh:347`): the case becomes `BLOCKED:checks-failing | WAIT:checks-failing-pending)`, so main writes stay fail-fast.
4. `plugin/lib/fake-gh`: in `checks-pending` mode with `checks-fail` present, answer one failed and one in-progress run (if the tests need it).
5. Docs: `docs/reference/cli.md:528-541` names the new reason and says wait reports a failing check once nothing is pending; `plugin/commands/close.md` step 6 (around 182-183) gets one sentence: "`WAIT:checks-failing-pending`: a check has failed while others still run; keep waiting so the whole run's outcome is known (you may read the failure meanwhile), then act on the `BLOCKED` that follows." No change to `plugin/bin/peal`, `docs/design.md`, `READY:no-checks`, `WAIT:no-checks-yet`, or the wait budget.

Verification:
- `plugin/lib/close.test.sh` verify cases (near 735-743): failed + in_progress runs give `WAIT:checks-failing-pending 3`; failed run + pending status the same; both completed give `BLOCKED:checks-failing 1`.
- `plugin/lib/close.test.sh` wait cases (near 762-774): a background job completes the second run after about 2 s; `close wait` (interval 1, budget 30) ends `BLOCKED:checks-failing 1` with more than one `check-runs` read in `$FAKE_GH/log`; budget 0 gives `WAIT:checks-failing-pending 3`; the existing "BLOCKED at once" case still passes.
- `plugin/lib/main-write.test.sh` merge_self (near 152-159): `checks-pending=2` with `checks-fail` returns 1 with "checks fail: it stays open" after one `check-runs` read.
- Full harness for close, main-write, ship, store-files and apply, plus the docs checks.

Ranges:
- plugin/lib/github.sh:96-128
- plugin/lib/close.sh:681-764
- plugin/lib/main-write.sh:324-358
- plugin/lib/close.test.sh:660-663
- plugin/lib/close.test.sh:729-775
- plugin/lib/main-write.test.sh:133-169
- plugin/lib/fake-gh:1-40
- plugin/lib/fake-gh:328-348
- plugin/commands/close.md:145-189
- docs/reference/cli.md:528-541
- docs/design.md:117-122
- plugin/bin/peal:260-262

---

## Outcome

Built: `peal_pr_checks` (`plugin/lib/github.sh`) now answers `WAIT:checks-failing-pending` (status 3) while a check has failed and another check or status on the commit is still pending, and `BLOCKED:checks-failing` (status 1) only once nothing is pending. `peal close verify` passes it through and `peal close wait` keeps polling on it, so a session learns how the whole run ended, and that a rerun of the failed jobs is possible, from the wait itself. When the wait's budget runs out first, the last line stands (`WAIT:checks-failing-pending`, 3); budget and the cap of six waits are unchanged.

Decided with the human:
- Main writes (idea filing, ship) stay fail-fast: `_peal_mw_merge_self` (`plugin/lib/main-write.sh`) treats the new verdict as a failing check, so a failure there is never delayed until the slowest job.
- "The run" is every check run and status on the commit, not one Actions workflow run (no extra API call per poll).
- The verdict name is the distinct token `WAIT:checks-failing-pending`.
- Belfry's `wait_ci` is out of scope.

Tests: `close.test.sh` covers a failed check beside a running one and beside a pending status, all completed, budget 0, and a wait that holds until a background job finishes the run; `main-write.test.sh` proves main writes return 1 after one read. `fake-gh`'s `checks-pending` mode now answers a failed run beside the running one while `checks-fail` exists. Harnesses: close 1095/0, main-write 168/0, ship 555/0, store-files 621/0, apply 405/0.

0144 landed on main during this task with a flaky-failure rerun rule in `plugin/commands/close.md` step 6 that said neither wait waits for the whole run. After merging main in, the review found that false for `peal close wait`; the rule now says `peal close wait` answers `BLOCKED:checks-failing` only once no check still runs, and keeps `gh run watch` only after `wait_ci`. 0144's task file was not edited (the human's call: it was already finished). Whether `wait_ci` itself already waits for the whole run, which would let the `gh run watch` step go too, is left to the idea queued here (close-rerun-after-wait-ci).

The review also found a garbled comment in `fake-gh`; fixed.
