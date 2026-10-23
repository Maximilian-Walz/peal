---
milestone: m7
plan: auto
size: S
depends: []
touches: [plugin/agents/planner.md, plugin/commands/work.md, plugin/commands/commands.test.sh]
---

# 0218 — The planner's decisions rules: a small adjacent fix is done in the task, equivalent designs are its call, "you decide" is recorded as consent, a question only where no default fits

## Intent

Of 670 answered question items between 2026-09-25 and 10-22, 587 took the option marked recommended (93%), and after 0164 42 of 43. The 45 that departed follow two rules the planner could hold: 17 times it recommended "file an idea" or "out of scope" for a fix beside the task and the human said "fix it here" (never once the other way); 11 times the human handed the choice back ("whatever is cleaner", "you decide"). Peal task sessions still ask a median of eight questions each; a third of a sample were answerable from the repository ("where do the tests go", "which model is the stronger one"). The waits cost a code slot (9.4 h since 10-18). When this is done the planner asks only what is the human's: a choice with no reasonable default, or one that is the human's to make. Everything else is decided, with its default stated where the human can overturn it. There is no fixed limit on the number of questions; a plan that still has many says so.

## Scope

- `plugin/agents/planner.md`, Decisions: a fix of tier-S size in a file the task already touches, found while planning, is done in the task and listed under Decisions, not asked; a choice between equivalent designs is the planner's, with its reason; a question whose answer is in a file of the repository is a decision that cites the file; a human question only where no reasonable default exists or the choice is the human's (scope, product behaviour, risk, cost), each with the default taken when unanswered; every other choice is decided and listed under Decisions with its default, where the human can overturn it. No fixed limit: a plan with more than five human questions says so and proposes splitting the task or making it `plan: required`, and keeps the questions rather than cutting them.
- `plugin/commands/work.md`: a free-text answer that delegates ("you decide", "whatever is cleaner") is recorded as the planner's decision and counts, for the reviewer, as the human's consent; the number of human questions asked is recorded in the task's Notes at close.
- `commands.test.sh` checks the wording.

## Done when

- `commands.test.sh` asserts the rules in planner.md (adjacent fix, equivalent designs, answers from the repository, a question only where no default fits, the many-questions note) and the delegation rule in work.md.
- A planned task's Notes carry the count of human questions (a harness case on `peal record`).
- Over the next ten planned tasks the median count is at most three (recorded in the Outcome of the milestone review). This is a measure of the rules, not a limit the planner applies.

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

> I don't know if I am a fan of a strict limit of four. It sounds a bit arbitrary.

## Notes

- Attention review F2 and agent-experience review finding 5. Builds on 0164 and on the narrowed `plan.required-paths` (PR #328).
- Security: none (prompts only); the consent rule for `merge` (0177) is untouched: a delegated answer never sets it.
- 2026-10-23: revised. The fixed limit of four human questions is dropped. A hard cap would make the planner merge real questions or default choices that are the human's; the other rules carry the reduction (93% of answers took the recommended option). In its place, a question only where no default fits, and a plan with more than five says so (split, or `plan: required`) instead of cutting them.

---

## Outcome

<!-- Written at close, replacing this comment. -->
