# Commands

The `/peal:` commands, run in a Claude Code session. Each calls the [`peal` CLI](cli.md)
for what a script can decide and keeps the judgement for itself. The reasons are in
[the design](../design.md#claims-and-the-session-hooks).

## `/peal:work`

`/peal:work [task id | pool]`. Works a task.

- In a task's worktree (its branch, its file under `doing/`) it resumes that task and
  claims nothing. Elsewhere four digits claim that task; a pool, or nothing (the pool
  `current,unassigned`), offers the best tasks through `AskUserQuestion`.
- A task with `owner: human` is refused; `peal claim` still makes its worktree.
- After a claim the session enters the worktree. The planner runs when the plan is
  required, and the session stops for the human to agree it.
- The agreed plan goes into the task's `## Plan`, with the size, a non-default `model`,
  the planner's `touches` and, only on the human's word, `merge: auto`.
  `peal record ID plan` puts the text on the claim.
- The implementer builds; its `QUESTION`s go to the human and the answers back through
  `SendMessage`. The main session never writes the task's code.
- The planner and reviewer get their model from `peal work` and start with
  `peal brief ROLE`.

## `/peal:close`

`/peal:close [what the human says about this close]`. Closes this worktree's task once
its `## Done when` holds, or once it is decided against.

- Runs `peal close begin`, then the reviewer, unless the diff lies under
  `review.skip-paths`.
- Each finding is fixed, filed as an idea, escalated under `### Escalations`, or
  rebutted under `### Reviewer findings not acted on`.
- Writes the Outcome, runs `peal close finish`, then `peal close wait` while the verdict
  is `WAIT`.
- Ends when the pull request is open and its checks are green. The merge is the human's.

## `/peal:idea`

`/peal:idea <the idea, in your own words>`. Files a rough idea as a backlog task in one
pass, asking nothing.

- `milestone`: the current one, only with direct evidence; else none, never a parked one.
- `plan` from `plan.required-paths`; `size` left to the planner; `priority` only when the
  idea says so plainly.
- On a task branch the idea is queued and filed when the task closes. Elsewhere it is
  filed at once.
- Under Belfry, off a task branch, it files through Belfry's `task_create` tool, never
  the shell.

## `/peal:split`

`/peal:split [how to split it]`. Splits this worktree's task. Files the pieces in one
`peal create --part-of`, then narrows the task to its first piece (`peal revise` on its
own claim) or closes it as split.

## `/peal:defer`

`/peal:defer <why the task cannot go on now>`. Gives this worktree's claim back when
nothing was built. `peal defer` writes the task's text, with what the session learned,
back under the same number; `peal release ID` from outside the worktree then deletes the
claim. Work on the branch refuses it.

## `/peal:retire`

`/peal:retire <task id> <why>`. Retires an unclaimed task whose premise died: moved to
`done/` with the reason as its Outcome, straight into the storage. The human confirms
first. A claimed task is refused.

## `/peal:revise`

`/peal:revise <task id> <what changes and why>`. Rewrites an unclaimed task's text in
place, straight into the storage. Shows the `--dry-run` diff; the human confirms first. A
claimed task is refused.

## `/peal:comment`

`/peal:comment <task id> <text>`. Adds a dated line to an unclaimed task's Notes through
`peal comment`, the text passed in a file, never as a shell word. It is the prompt of
Belfry's `tasks.commands.revise`, which `peal init --stage belfry` writes for files
storage. Text starting with Belfry's `From outside (` header is added with `--origin
outsider`. A claimed or done task, a refused text or a failed write is reported with the
text quoted and "not added".

## `/peal:milestone-review`

`/peal:milestone-review [milestone id]`. Reviews a milestone before it closes. Without an
id: the milestone of this worktree's task (in a review task, the task whose `depends`
says `milestone`), else the current one.

- Runs `peal milestone-review`, walks the acceptance criteria (met with evidence, or
  carried forward as an idea), runs the steps of `.peal/review.md`, files loose ends
  through `/peal:idea`, and triages the backlog.
- Ends with one `AskUserQuestion`, "Close <milestone>?". On yes it runs
  `peal milestone-state ID done --review FILE`.
- Also runs without a task, as a Belfry action with the `milestone` trigger.

## `/peal:drift`

`/peal:drift [what to look at]`. Compares the documents `.peal/drift.md` lists against the
repository and files one idea per discrepancy. Fixes nothing.

## `/peal:release`

`/peal:release [version]`. Makes a release from the tasks finished since the last one.

- Runs `peal ship propose`, shows `peal ship notes`, and asks "Release <version>?" in
  one `AskUserQuestion`.
- On yes: `peal ship bump` (the version files and the changelog entry), `tag`, `publish`, and `wait` when `release.wait-ci` is true.
- Works in either storage and claims nothing.

## `/peal:setup`

`/peal:setup [tasks | guardrails | milestones | belfry]`. Sets the project up for Peal,
in the human's own session, on top of `peal init`.

- Without a stage: the `tasks` stage and nothing more. Reads the repository, recommends
  the storage in two sentences and asks once, shows what the stage writes, commits it as
  one `chore(peal)` commit on a `peal/setup-<stage>` branch (never the main branch),
  offers it as a pull request, proposes one or two first tasks, and ends in five lines,
  pointing at `/peal:next` for what comes later.
- With a stage: sets up that one the same way. Each stage but `tasks` needs `tasks` first.
- `milestones` asks the first milestone's title and offers its review task; `belfry`
  offers to turn the milestone review action on.

## `/peal:next`

`/peal:next [all | tasks | guardrails | milestones | review-task | belfry | decisions |
drift | releases | reviewer | review-steps]`. Suggests the one next thing to adopt, with
the evidence for it, and up to three runners-up. Changes nothing without a yes.

- Reads `peal next`: stages recorded, backlog history, milestones, local git history,
  local files. Never Belfry, never `gh`, never a fetch.
- The order is fixed: the stages, then a current milestone's missing review task, then
  the features within the stages.
- The human accepts, declines (`declined.<item>` in `.peal/config.yml`, 90 days) or asks
  for more. `all` also shows what is declined; an item named is offered regardless.
- The SessionStart orientation carries a one-line hint outside a task's worktree.
