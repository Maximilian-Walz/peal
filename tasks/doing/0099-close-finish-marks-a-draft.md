---
plan: required
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/commands/close.md]
milestone: m3
---

# 0099 — `close finish` marks a draft pull request ready

## Intent

Some tasks can only write their Outcome after a real CI run, because their Done when quotes one. CI runs only on pull requests, and `close finish` opens the pull request after the Outcome is written, so such a task has no CI result when it needs one. One session worked around this by opening a draft pull request by hand before the review. `finish` then found that pull request and updated its body, but left it a draft, and the session had to run `gh pr ready` by hand.

When this is done, `finish` marks an existing draft pull request for the branch ready for review and says it did. The close command also tells a session how to get a CI run early when its Outcome needs one: open a draft pull request before the review.

## Scope

- `close finish`: when it finds an open pull request for the branch that is a draft, mark it ready (and say so).
- `plugin/commands/close.md`: one line on opening a draft pull request before the review when the Outcome needs a CI result.

## Done when

- close.test.sh: finish on a branch with an open draft pull request leaves it ready for review.

## Raw

Belfry friction, 2026-09-28 (job 33b6933b2e19f581): "peal close has no step for getting CI before the Outcome ... finish updates the PR but leaves it a draft."

## Notes

- No milestone: nothing in m2's goals or acceptance criteria covers this.
- Open question: should the early draft be a step of its own (a `close draft` subcommand, or `finish` able to run twice) rather than a manual `gh pr create --draft`? Out of scope unless the planner and the human agree to it.
- Open question: does `finish` refresh the draft's body with the final Outcome? The friction suggests it does; check.
- Open question: check that close's wait for green checks still works when CI already ran on the draft.

---

## Outcome

<!-- Written at close, replacing this comment. -->
