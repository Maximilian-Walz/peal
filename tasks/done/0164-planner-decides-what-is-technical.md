---
milestone: m3
plan: required
size: M
depends: []
priority: high
touches: [plugin/agents/*.md, plugin/commands/*.md, plugin/commands/commands.test.sh, plugin/lib/task-check.awk, plugin/lib/work.sh, plugin/lib/work.test.sh, plugin/lib/store-files.test.sh, plugin/templates/task.md, tasks/TEMPLATE.md, docs/reference/*.md, docs/design.md, docs/getting-started.md, docs/guides/working-a-task.md, docs/security.md]
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

The human's answers to the planner's questions (2026-10-21):

- **DefaultPlan:** a task with no `plan` field means `auto`.
- **SizeRule:** size plays no part in the `plan` value; correct the line in
  `docs/reference/tasks.md` that says `/peal:idea` uses the declared size.
- **IdeaSkip:** `/peal:idea`, split and setup write `skipped` only for plainly trivial
  work (a typo, a one-line doc fix), `auto` otherwise; unsure counts as `auto`.
- **Backlog:** no migration of existing `plan: skipped` tasks.
- **Stronger:** the stronger model is `models.planner` (the `MODEL planner` line of
  `peal work`); no escalation when the implementer already runs on it.
- **Escalate:** on `STOPPED` from a default-model implementer, retry at once on the
  stronger model, once; a second `STOPPED` goes to the human as today.
- **ReReview:** `/peal:close` re-reviews after an implementer fix for a blocking
  finding; a second blocking round sends the next fix to the stronger model.
- **MergeAsk:** under `auto`, the planner's `merge: auto` recommendation is asked as one
  extra question only when human questions are already being asked; never a stop of
  its own, never written otherwise.
- **Unsure:** a question the planner cannot place is the human's.
- **Outsider:** `origin: outsider` forces `required`: `peal work` reports `PLAN required`
  for an outsider task holding `auto` (with a test), and `docs/security.md` says so.
- **SkipModel:** for a skipped plan, always a Notes line with the model reason; the
  frontmatter `model` only when it is not the default.
- **ImplQs:** the implementer's own `QUESTION`s are unchanged: all go to the human.
- **HandRun:** the implementer tries a `claude --plugin-dir plugin` run in a scratch
  repository; if it cannot, the Outcome hands the hand run to the human after merge.
- **Template:** both templates write `plan: auto`.
- **Design doc:** rewrite `docs/design.md` 161–171 and `docs/getting-started.md` 75–85
  to describe the three values.

## Plan

**Script side (tested):**
- `plugin/lib/task-check.awk`: accept `plan: auto`; the refusal reads "is not skipped,
  auto or required".
- `plugin/lib/work.sh` (`_peal_work_here`): `required|auto` with a filled `## Plan` →
  `PLAN agreed`; `required` → `PLAN required`; `auto` → `PLAN auto` (but `PLAN required`
  when the task's `origin` is `outsider`); `skipped` → `PLAN skipped`; a missing or empty
  `plan` → `auto`.
- Tests: `plugin/lib/work.test.sh` ("no plan field is auto", "plan auto is PLAN auto",
  "auto with a Plan is agreed", "outsider auto is required"); `plugin/lib/store-files.test.sh`
  (`peal create` accepts `plan: auto`, refuses `plan: maybe` with the new message). Both
  storages.

**Prompt side:**
- `plugin/agents/planner.md`: section 7 becomes two lists, **Human questions** (label,
  question, default) and **Decisions** (label, choice, one-line reason); the human
  categories from Scope verbatim, with "when unsure, it is the human's"; under `auto` it
  says "raise to `required`" and why when the plan touches a human category; the model
  rule names the hard cases (security boundary or gate, git or race semantics, a parser,
  ordering semantics); the description no longer says `plan: required` only.
- `plugin/commands/work.md`: step 4 gains `PLAN auto`. Step 5: `required` as today;
  `auto` raised by the planner → `peal frontmatter set <file> plan required`, then the
  required flow; `auto` with human questions → show the plan, ask only those (plus
  merge per MergeAsk), record, build; `auto` with none → no question: write `## Plan`,
  the planner's decisions under `## Notes` headed as the planner's, size/model/touches,
  `peal record <id> plan`, build. `merge auto` only on the human's word. New step for
  `skipped`: model by the planner's rule, Notes line with the reason, `model` when not
  default, `peal record <id> notes`. Step 6: `STOPPED` on the default model → a fresh
  implementer on the stronger model once, noted for the Outcome.
- `plugin/commands/close.md`: re-review after an implementer fix of a blocking finding;
  a second blocking round → next implementer on the stronger model; `--decisions` names
  the planner's decisions; the Outcome notes any escalation.
- `plugin/agents/reviewer.md`: reads the planner's decisions in Notes; one in a human
  category is a blocking finding.
- `plugin/agents/implementer.md`: description only.
- `plugin/commands/idea.md`, `split.md`, `setup.md`: triage `required` / `auto` /
  `skipped` per IdeaSkip.
- `plugin/commands/commands.test.sh`: text checks for the planner's two lists and
  categories, `PLAN auto` and building without asking in `work.md`, `merge auto` only on
  the human's word, the escalation sentences in `work.md` and `close.md`, and the
  reviewer's check; update existing merge/touches checks if phrases move.

**Docs:** `docs/reference/tasks.md`, `configuration.md`, `cli.md` (`PLAN` states),
`commands.md`; `docs/design.md` 161–171; `docs/getting-started.md` 75–85;
`docs/guides/working-a-task.md` (docs-check output becomes `PLAN auto`);
`docs/security.md` (outsider forces `required`); `plugin/templates/task.md` and
`tasks/TEMPLATE.md` (`plan: auto`, comment names three values).

**Verification:** the tests above on both storages, `bash tools/lint.sh`,
`tools/test-all.sh`; the hand run per HandRun.

**Ranges relied on:**
- tasks/doing/0164-planner-decides-what-is-technical.md:1-93
- plugin/agents/planner.md:1-73
- plugin/agents/reviewer.md:29-64
- plugin/agents/implementer.md:1-11
- plugin/commands/work.md:65-144
- plugin/commands/idea.md:42-81
- plugin/commands/close.md:50-125
- plugin/commands/split.md:49-70
- plugin/commands/setup.md:166-199
- plugin/commands/commands.test.sh:53-92
- plugin/commands/commands.test.sh:145-150
- plugin/lib/work.sh:51-75
- plugin/lib/work.sh:135-186
- plugin/lib/work.test.sh:116-140
- plugin/lib/work.test.sh:142-208
- plugin/lib/task-check.awk:51-75
- plugin/lib/store-files.test.sh:210-220
- plugin/templates/task.md:1-38
- tasks/TEMPLATE.md:1-38
- docs/reference/tasks.md:35-55
- docs/reference/tasks.md:88-94
- docs/reference/configuration.md:23-43
- docs/reference/cli.md:446-453
- docs/reference/commands.md:7-52
- docs/design.md:145-172
- docs/design.md:325-334
- docs/getting-started.md:67-88
- docs/guides/working-a-task.md:45-60
- docs/security.md:240-263
- docs/security.md:346-359
- .belfry.yml:100-148
- .peal/config.yml:9-13
- docs/milestones/m3.md:1-27

---

## Outcome

Built as planned. `plan` takes three values: `skipped`, `auto` and `required`. A task
with no `plan` now reads `PLAN auto`, where before it read `skipped`.
- `task-check.awk` accepts `auto`.
- `work.sh` prints `PLAN auto`. It prints `PLAN agreed` for `auto` or `required` with a
  filled `## Plan`, and `PLAN required` for an `auto` task whose `origin` is `outsider`.

The planner (`plugin/agents/planner.md`) now returns two lists:
- **Human questions:** the categories from Scope. When unsure, a question is the human's.
- **Decisions:** each with a one-line reason. Under `auto` it says "raise to `required`"
  when the plan touches a human category.

`/peal:work`:
- Under `auto` with no human question, it records the plan and builds without asking. It
  writes the planner's decisions under `## Notes`, in a block headed "Decisions of the
  planner".
- Under `auto` with human questions, it asks only those. It adds the planner's
  `merge: auto` recommendation as one extra question, never as a stop of its own.
- For `skipped`, the main session picks the model by the planner's rule and adds a Notes
  line with the reason.
- A `STOPPED` implementer on the default model is retried once on `models.planner`.

`/peal:close` re-reviews after an implementer fix of a blocking finding. A second
blocking round sends the next fix to the stronger model, the Outcome names any
escalation, and `--decisions` names the planner's decisions.

The reviewer treats a planner decision that was the human's as a blocking finding.

Idea, split and setup write `skipped` only for plainly trivial work. The templates write
`plan: auto`. The docs, `design.md` and `getting-started.md` included, describe the three
values. `security.md` says an outsider task is always `required`. Existing
`plan: skipped` tasks were not migrated, as the human decided.

Review found two things, both fixed in b3b3d1b:
- The ten new text checks in `commands.test.sh` ran after `finish`, so they could not
  fail the run. They are now counted: 168 checks, and a broken phrase makes the run exit 1.
- The planned "auto with a Plan is agreed" test was missing. It is added and runs on both
  storages.

For the next session: `tools/test-all.sh` was not run to the end here (time limit). The
work, store-files, commands, setup and docs tests and the lint pass; CI is the full check.
The outsider rule is tested on the files storage only, since the issues storage carries
no `origin`. This change takes effect for this repository's own process only once the
installed plugin is updated from `main`.

### Escalations

- The Done when line "a hand run of one `auto` task with no human question goes from
  claim to implementer without asking" is not met yet. The sandbox has no interactive
  Claude session for a `claude --plugin-dir plugin` run, so per the human's HandRun answer
  it is the human's check after merge.
