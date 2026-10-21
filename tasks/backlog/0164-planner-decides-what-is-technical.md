---
milestone: m3
plan: required
size: M
depends: []
priority: high
touches: [plugin/agents/planner.md, plugin/commands/work.md, plugin/commands/idea.md, plugin/lib/**, docs/reference/tasks.md, docs/reference/configuration.md, tasks/TEMPLATE.md]
---

# 0164 — The planner decides what is technical and asks the human only theirs

## Intent

Today every planned task stops for the human: the planner lists every ambiguity,
"including what feels too small to ask", and `/peal:work` asks each one and the whole
plan before anything is built. The human mostly accepts the recommended answer, often on
technical details they do not want to judge, so the stop costs their attention without
improving the work. When this is done the planner still plans (the plan, the cited
ranges and the model choice are what let a cheaper implementer do good work), but it
sorts each open question into one the human must answer and one it decides itself with
a reason. A task whose plan holds no human question is built without stopping, and the
human sees the planner's decisions afterwards, in the task's Notes and the pull
request's decisions. A task with a skipped plan gets its implementer's model from the
main session by the same rule the planner uses, and a cheaper implementer that fails is
followed by the stronger one.

## Scope

- **`plan` takes three values:** `skipped` (no planner: trivial work), `auto` (the
  planner runs and asks only human questions; the new default where `/peal:idea` and
  `plan.required-paths` give none) and `required` (the human agrees the whole plan, as
  today). `plan.required-paths` keeps giving `required`. The planner may raise `auto` to
  `required` when it finds the plan touches what needs the human (below), saying why.
- **The planner's questions are sorted.** Human questions: what the work is for or
  covers; what the human sees or uses (interaction, wording, a default that changes
  behaviour); money, accounts, anything outward or irreversible; a security boundary; a
  change to a recorded decision or a context document. Anything else (names, layout,
  which of equivalent approaches, error text) the planner decides, each with a one-line
  reason, listed as its decisions.
- **`/peal:work` with `plan: auto`:** with no human question, record the plan as agreed
  by the planner (its decisions under `## Notes`, marked as the planner's) and build;
  with some, ask only those, then build. `merge: auto` is never set without the human:
  under `auto` the planner's merge recommendation is dropped unless the human is asked
  for it anyway.
- **Model without a planner:** for `plan: skipped`, the main session picks the
  implementer's model by the planner's rule (default unless genuinely hard, with a
  one-line reason; the hard cases are a security boundary or gate, git or race
  semantics, a parser, ordering semantics) and records it as the planner would.
- **Escalation:** when an implementer on the default model ends `STOPPED`, or the
  review finds blocking findings in its work a second time, the next implementer run
  uses the stronger model, and the Outcome says so.
- **The reviewer checks the decisions** the planner made alone: one that was the
  human's to make is a finding.
- The task template, `docs/reference/tasks.md` and `docs/reference/configuration.md`
  describe the three values.

## Done when

- `plan: auto` is accepted by the frontmatter checks and is what a task gets without a
  `required` path or size; a test asserts both.
- The planner's output sorts questions into the human's and its own decisions, and
  `/peal:work` stops for the human under `auto` only when a human question is left; the
  commands' text says so, and a hand run of one `auto` task with no human question goes
  from claim to implementer without asking.
- `merge: auto` is never written for a plan the human did not see.
- A skipped plan's task carries the model the main session chose, with its reason.
- An implementer that ended `STOPPED` on the default model is followed by one on the
  stronger model.
- The reviewer's prompt lists a planner decision that was the human's as a finding.

## Raw

> I agree that there are tasks that could just skip the planning. However, for some it
> might still be useful even if not every question has to be answered my be personally.
> […] What I want is to not be bothered by some small design decisions that I don't know
> anything about anyways but still high quality. If the plan is skipped the
> orchestrator should maybe have the option to set the implemnter on opus for hard
> tasks?

## Notes

Evidence from this repository's own last 85 tasks (2026-09-25 to 10-21): the planner's
model choice was right every time (12 Opus tasks, each with a reason; every "default"
task went to the default model), and of 73 tasks built on the default model with the
stronger reviewer, 62% had no blocking finding and the review caught every blocking one
before close. Planner runs cost about 6% of the implementers' input tokens. So the plan
step is worth keeping; the human stop is what the human wants gone for technical
questions.

The control plane starts using Peal's workflow on its own issues next; this should land
first, so its unattended jobs do not put a plan approval in the human's inbox for every
issue.
