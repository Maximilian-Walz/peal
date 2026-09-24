---
description: Review a milestone before it closes. Checks that its tasks are done, walks its acceptance criteria, runs the project's review steps and triages the backlog, then asks the human whether to close it. On yes it marks the milestone done and the next one current.
argument-hint: "[milestone id]"
---

Arguments: `$ARGUMENTS`, the milestone to review. Without one: the milestone of this
worktree's task (in a milestone's review task, the task whose `depends` says
`milestone`), else the current milestone.

`peal` is Peal's CLI, on the Bash tool's path. Closing a milestone is the human's
decision. This command prepares that decision and carries it out once the human
answers. It runs in the review task's worktree, or anywhere else (a Belfry action with
the `milestone` trigger runs it as `/peal:milestone-review {milestone}`). It never claims
a task and never writes task files itself. Follow-ups go through `/peal:idea`, and the
milestone's state changes only through `peal milestone-state`.

## 1. Readiness

Run `peal milestone-review <id>` (no id when none was given). It prints the milestone
and its review task, the milestone's tasks that are not done (its review task aside),
the milestone that becomes current once this one is done, the parked milestones with
their reasons, how many tasks have no milestone, the milestone's text (its file, or the
GitHub milestone's description), and the project's review steps from
`.peal/review.md`. The last line is `READY` or `OPEN <count>`.

On `OPEN`, the milestone is not finished. Tell the human which tasks are open and ask
with `AskUserQuestion`: stop here (first option, the default), or review anyway and move
the open tasks out (step 5). Stop means stop, with nothing changed.

## 2. Acceptance criteria

Walk the milestone text's acceptance criteria (its "Done when", goals, whatever the
project calls them) one at a time. Each one is either **met**, with the evidence (the
task that delivered it, a file, a command's output), or **carried forward**: into the
next milestone as a task filed with `/peal:idea`, naming the criterion. None is dropped
silently. A criterion that no longer makes sense is carried forward as a question for
the human, not declared met.

## 3. The project's review steps

Run every step of `.peal/review.md` in order, if the project has one. Some steps need
the human, for example playing a build or looking at a render. Ask for those with
`AskUserQuestion` and record the human's verdict in their own words, not paraphrased.

## 4. Loose ends

Read the Outcomes of the milestone's done tasks: escalations, reviewer findings not
acted on, and "later" notes. Each one worth a future session becomes an idea
(`/peal:idea`). Answer the rest in one line in the review.

## 5. Backlog triage

Run `peal overview`. Triage covers only what this review has evidence for:

- **Tasks without a milestone**: set one with `peal set-milestone <id> <milestone>` only
  when the task plainly belongs to the next milestone's goal. Otherwise leave it without
  a milestone.
- **Parked milestones**: re-read each one's reason. A parked milestone whose reason no
  longer holds (the issues its `until` names are done, the date passed) is a question
  for the human: ask whether to un-park it, and on yes run `peal milestone-state <id>
  open`.
- **Open tasks of this milestone** (only after the human chose to review anyway in step
  1): move each one to the next milestone, to no milestone, or to a parked milestone
  with `peal set-milestone`. A claimed task cannot be moved: name it in the review.

Every change here goes straight into the storage. List each one in the review.

## 6. Write the review

Put the review in a file (for example `$(mktemp)`), in plain Markdown without a heading
of its own (`peal milestone-state` adds `## Review, <date>`):

- one line per acceptance criterion: met (with the evidence) or carried forward (to
  what);
- the project's review steps and their results, the human's verdicts quoted;
- the ideas filed, by title (queued ideas get their numbers at the close);
- the triage: tasks moved, milestones un-parked or left parked, and why;
- what the next milestone starts with.

## 7. Ask, then close

End with exactly one `AskUserQuestion`: "Close <milestone>?". Put the review's summary
in the question, in a few lines: criteria met and carried forward, open tasks, ideas
filed, the milestone that becomes current. Options: close it (first), or not yet.

- **Yes**: run `peal milestone-state <id> done --review <file>`. The milestone becomes
  `done`, the review is added to its file (task files, straight onto the main branch)
  or to its description (GitHub). With no milestone current any more, the first open
  milestone by order becomes current for task files; for GitHub issues, the open
  milestone due soonest is current. Report its last line, `current milestone: ...`.
  With no open milestone to follow, say so: the next milestone is the human's to create.
- **Not yet**: change nothing. Report what stands in the way, as the human said.

In the review task's worktree, go on with `/peal:close` afterwards. The task's Outcome
says whether the milestone was closed, and points to the review.
