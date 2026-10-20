---
milestone: m3
plan: required
priority: low
touches: [plugin/commands/close.md, plugin/commands/commands.test.sh]
---

# 0144 — Close says when a failed CI job can be rerun

## Intent

Two sessions ran `gh run rerun <id> --failed` over and over while closing, and gh refused every time with "This workflow is already running". One job of the run had failed, probably a flaky check like the macOS one 0137 describes, while other jobs of that run were still going. gh reruns only a run that has finished. Nothing in `/peal:close` told the sessions that, so they kept retrying.

Once this is done, `/peal:close` step 6 tells a session how to retry a failure that looks flaky: wait until the whole run has finished, then rerun the failed jobs once. If they fail again, it is a real failure and gets fixed like any other. The guidance applies to both ways of waiting, `wait_ci` and `peal close wait`.

## Scope

- `plugin/commands/close.md` step 6: one or two sentences about retrying a flaky failure, under both waits (`wait_ci` and `peal close wait`).
- `plugin/commands/commands.test.sh`: a check that the sentence is there.

## Done when

- Step 6 says a rerun waits until the run has finished and happens at most once.
- The harness checks it.

## Raw

> Close says when a failed CI job can be rerun
>
> ## Intent
>
> Two sessions ran `gh run rerun <id> --failed` again and again, and gh refused each time: "This workflow is already running". A job had failed (probably a flaky check, like the one 0137 reports) while other jobs of the same run were still going. gh only reruns a run that has finished. When this is done, `/peal:close` step 6 says how to retry a failure that looks flaky: wait until the whole run has finished, then rerun the failed jobs once. If it fails again, treat it as a real failure.
>
> ## Scope
>
> - `plugin/commands/close.md` step 6: one or two sentences about retrying a flaky failure, under both waits (`wait_ci` and `peal close wait`).
> - `plugin/commands/commands.test.sh`: a check that the sentence is there.
>
> ## Done when
>
> - Step 6 says a rerun waits until the run has finished and happens at most once.
> - The harness checks it.
>
> ## Raw
>
> > Belfry detected, in jobs 340fb9450af14292 and dbfc74d898c92cb1: `gh run rerun <id> --failed` failing again and again with "run cannot be rerun; This workflow is already running".

## Notes

- The human wrote Scope and Done when in the idea, so they are kept as written, not left for the planner.
- The human chose milestone m3 and priority low.
- 0137 (the flaky macOS hostile-stdin check) is only an example of a flaky failure. It is not a prerequisite.
- Open question: step 6's existing branches send a failing check (`ci: failure` under `wait_ci`, `BLOCKED:checks-failing` under `peal close wait`) straight to "fix, commit, push". Should the one rerun come before that fix, and how does a session tell whether a failure "looks flaky" (for example, the failing check has nothing to do with the diff)?
- Open question: under `wait_ci`, does `done: true` with `ci: failure` already mean the whole run has finished, or can it report while other jobs are still running? The wording depends on the answer.
- Context: `docs/design.md` (Peal never needs Belfry), so the guidance must also hold without `wait_ci`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
