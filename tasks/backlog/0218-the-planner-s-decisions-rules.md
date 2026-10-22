---
milestone: m7
plan: auto
size: S
depends: []
touches: [plugin/agents/planner.md, plugin/commands/work.md, plugin/commands/commands.test.sh]
---

# 0218 — The planner's decisions rules: a small adjacent fix is done in the task, equivalent designs are its call, "you decide" is recorded as consent, at most four human questions

## Intent

Of 670 answered question items between 2026-09-25 and 10-22, 587 took the option marked recommended (93%), and after 0164 42 of 43. The 45 that departed follow two rules the planner could hold: 17 times it recommended "file an idea" or "out of scope" for a fix beside the task and the human said "fix it here" (never once the other way); 11 times the human handed the choice back ("whatever is cleaner", "you decide"). Peal task sessions still ask a median of eight questions each; a third of a sample were answerable from the repository ("where do the tests go", "which model is the stronger one"). The waits cost a code slot (9.4 h since 10-18). When this is done the planner asks only what is the human's, and a plan has at most four human questions with a stated default for everything else.

## Scope

- `plugin/agents/planner.md`, Decisions: a fix of tier-S size in a file the task already touches, found while planning, is done in the task and listed under Decisions, not asked; a choice between equivalent designs is the planner's, with its reason; a question whose answer is in a file of the repository is a decision that cites the file; at most four human questions per plan, each with the default taken when unanswered.
- `plugin/commands/work.md`: a free-text answer that delegates ("you decide", "whatever is cleaner") is recorded as the planner's decision and counts, for the reviewer, as the human's consent; the number of human questions asked is recorded in the task's Notes at close.
- `commands.test.sh` checks the wording.

## Done when

- `commands.test.sh` asserts the four rules in planner.md and the delegation rule in work.md.
- A planned task's Notes carry the count of human questions (a harness case on `peal record`).
- Over the next ten planned tasks the median count is at most three (recorded in the Outcome of the milestone review).

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Attention review F2 and agent-experience review finding 5. Builds on 0164 and on the narrowed `plan.required-paths` (PR #328).
- Security: none (prompts only); the consent rule for `merge` (0177) is untouched: a delegated answer never sets it.

---

## Outcome

<!-- Written at close, replacing this comment. -->
