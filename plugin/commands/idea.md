---
description: File a rough idea as a backlog task in one exchange, without questions. Queued on a task branch and filed when the task closes; filed at once anywhere else.
argument-hint: "<the idea, in your own words>"
---

The human's idea, verbatim:

$ARGUMENTS

`peal` is Peal's CLI, on the Bash tool's path. `peal idea` files the task through the
project's storage: on a task's branch it queues the idea in this worktree and the task's
close files it; anywhere else (or with `--now`) it files it at once. Never switch
branches, stash or commit for an idea, and never write a task file yourself.

File only what would cost a future session to lose. A remark, a nicety or a passing
thought is answered in a sentence instead, and nothing is filed.

Do not ask the human anything: every judgement below is yours, made in this one pass.
What the idea leaves unclear goes into the task's `## Notes` as an open question.

## 1. What you need to judge

Run these once:

- `peal milestones`: one line per milestone, `id state order due title`.
- `peal config plan.required-paths`: the paths whose tasks need a plan first.
- `peal config context`: the project's context documents. Read those whose subject the
  idea touches.

## 2. Compose the task

- **Title**: short, from the idea.
- **Intent**: the idea restated in your own words, lightly expanded, adding no scope the
  human did not express. `## Raw` below is what a later session checks your reading
  against.
- **Scope** and **Done when**: the headings only, left empty. Writing them is inventing
  scope; the session that claims the task writes them with the planner.
- **Raw**: the human's words above, verbatim, quoted.
- **Notes**: open questions, and the context documents that bear on it (cite a document
  only when it plainly covers the idea; nothing rather than a loose match).

Frontmatter, triaged now:

- `milestone`: the `current` milestone's id only with direct evidence the idea belongs to
  it: it names one of the milestone's goals or acceptance criteria, or it splits off a
  task already in it. Otherwise leave the field out: no milestone, the default pool. An
  `open` milestone only when the idea names it. Never a `parked` or `done` one: `peal
  idea` refuses them, moving a task there is a milestone review's call.
- `plan`: `required` when the work the idea describes (not merely what it mentions) will
  touch one of `plan.required-paths`; unsure counts as `required`. `skipped` otherwise,
  and whenever that list is empty.
- `depends`: only when the idea says, in terms of a task, that it cannot be worked before
  that task is done: its id. `human` when it waits on the human (a hand-over, a decision
  only they can make); left in prose only, no claim could see it. A number you are unsure
  is a real prerequisite stays out and goes into Notes: a wrong one blocks the task
  silently.
- `priority`: only when the idea says so plainly: `urgent` when it says it is urgent or
  blocks something now ("urgent", "blocks …", "cannot wait"), `high` when it says it
  should come first or soon, `low` when it says it can wait. Otherwise leave it out: no
  priority is `normal`. Priority orders the offer within a milestone, never across them.
- `touches`: only when the idea names the files or directories it will change plainly
  ("the board's awk", "`docs/api.md`"): those paths, relative to the repository's root.
  Otherwise leave it out; the planner writes it when the plan is agreed. It is a hint
  for starting tasks in parallel, never a guess worth making.
- `size`: left out; the planner sizes a task when it is claimed.
- `merge`: never. Only the human's agreement to a plan writes `merge: auto`.

Write `NNNN` wherever the task's number belongs, the heading first; the storage puts in
the number it gets. Never invent a number.

```markdown
---
milestone: <id, or leave the line out>
plan: <required | skipped>
depends: [<ids, human>]
priority: <urgent | high | low, or leave the line out>
touches: [<paths the idea names plainly, or leave the line out>]
---

# NNNN — <Title>

## Intent

<your restatement>

## Scope

## Done when

## Raw

> <the human's words, verbatim>

## Notes

<open questions; the context documents that apply>

---

## Outcome

<!-- Written at close, replacing this comment. -->
```

Drop `depends` when it is empty. A project's own fields (`peal config task.fields`) are
set only when the idea says their value.

## 3. File it

Pick a slug, two to five kebab-case words from the title, and run:

```bash
peal idea <slug> <<'IDEA'
<the composed text>
IDEA
```

Add `--now` after the slug only when another session must see the idea before this
task closes.

A refusal names what to fix: fix it and run again once. A `depends` id it does not
know moves into Notes as prose.

## 4. Report

Say what `peal idea` printed, `queued ...` or `filed ...` with its milestone, plan and
title, as printed, and the `pull request #N <url>` line when main takes writes through
pull requests (the number is final once it merges): the human may overrule the triage in
one sentence while here.
