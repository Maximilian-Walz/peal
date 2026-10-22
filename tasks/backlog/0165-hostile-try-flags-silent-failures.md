---
plan: required
touches: [plugin/lib/hostile.test.sh]
milestone: m7
---

# 0165 — Hostile try() flags a silent status-2 run

## Intent

The hostile harness's `try()` accepts any exit status from 0 to 3. A run that fails with status 2 but prints no `peal:` reason line on stderr therefore passes unnoticed. A silent failure, such as the macOS `git archive | tar` SIGPIPE flake found in 0137, can then skew many cases without any of them failing. `try()` should report such a run (status 2, no `peal:` reason line on stderr) as a finding.

## Scope

## Done when

## Raw

> The hostile harness's try() accepts any status 0-3, so a run that fails with status 2 and no `peal:` reason line on stderr passes unseen; a silent failure (like the macOS git archive | tar SIGPIPE flake found in 0137) can skew many cases. try() should flag a status-2 run whose stderr carries no `peal:` reason line as a finding. Found in 0137.

## Notes

- Open question: some commands may legitimately refuse with status 2 and a reason that does not start with `peal:` (git's own text, a usage line). Which reason forms count needs checking against the harness's cases before tightening.
- Open question: whether status 1 and 3 runs without a reason should be flagged too; the idea names status 2 only.

---

## Outcome

<!-- Written at close, replacing this comment. -->
