---
plan: required
size: M
depends: []
touches: [README.md, docs/getting-started.md]
milestone: m8
---

# 0191 — README rewrite: the first screen says what Peal is, what it needs and what a task costs

## Intent

The README opens with a line about bells, not with what Peal is; its round trip is three long numbered paragraphs that each introduce two or three terms; requirements are nowhere (a GitHub remote, the `gh` command installed and logged in, since `close` ends `BLOCKED:no-gh` otherwise, macOS or Linux, Claude Code with plugins); nothing says what a task costs (a planner and a reviewer on the stronger model and an implementer on the faster one by default, the `models` setting: the words cost, token, Opus and Sonnet appear nowhere in README, getting-started or the guides); and one promise is not kept: the README says "you agree the plan", but under the default `plan: auto` the planner asks only the questions that are the human's and, when there are none, the build starts without stopping and the plan is never shown. When this is done a newcomer reads, in one screen, what Peal does, what it needs and what it costs, and is not surprised by the build starting.

## Scope

- Rewrite the README from the outline in Notes: title and one line, the problem paragraph (kept), one task start to finish, where you stay in charge (the three plan modes and the merge), what you need, try it (the two `/plugin` lines, the CLI form for scripts and agents, `/peal:setup`), what Peal adds to the repository and the machine and how to take it out, works with what you have, the commands in a 14-row table from their own descriptions, why this shape, the documentation map, status, contributing.
- `docs/getting-started.md`: requirements first; the pin example uses a real tag (`v0.6.0`, not `vX`); the five facts about where an idea lands as bullets; "the build may start at once" in step 2; `peal doctor` and the troubleshooting page at the end; one line on what `.claude/settings.json` does to teammates.
- The README transcript uses what `/peal:idea` really prints (`plan: auto, size: -`); adjust the docs harness fixture it is compared with.

## Done when

- The README's first screen has the one-line statement, the problem, the example, the plan modes, the requirements and a sentence on cost with the models.
- The README states that the default plan mode may start the build without showing the plan.
- `tools/docs.test.sh` passes with the transcript's `filed` line matching the real `/peal:idea` output.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Documentation review, section 3 and A1, A2, A4, A9, A13, 8.1 and 8.2. Outline for the first screen: "A task process for Claude Code: an idea becomes a task, a task becomes a reviewed pull request, each on its own branch in its own worktree, so what to do next no longer lives in your head or your chat history." with the bell aside as a short italic line after it; then the problem paragraph; then the `/peal:idea` and `/peal:work` example; then "Where you stay in charge" (by default the planner decides the technical questions and asks only yours, if it has none the build starts at once; `plan: required` stops the session until you agree the whole plan; the merge is yours unless you mark a task `merge: auto` when agreeing its plan); then "What you need" (a git repository with a GitHub remote and `gh` logged in, macOS or Linux, Claude Code with plugins; up to three subagents per task, planner and reviewer on the stronger model, implementer on the faster one, `models` in the settings).
- The README's claim "nothing merges by itself" waits on the security tasks of the Main decides milestone; word it as what the project's merge rules do.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
