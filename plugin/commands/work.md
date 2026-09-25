---
description: Work a task. Resume this worktree's task, or claim a named task or one offered from a pool into a worktree of its own, then plan it with the human and build it in a subagent.
argument-hint: "[task id | pool]"
---

Arguments: `$ARGUMENTS`. None means the pool `current,unassigned`; four digits are a task
id; anything else is a pool, a comma list of milestone ids, `current` and `unassigned`.

`peal` is Peal's CLI, on the Bash tool's path. Every step below that a script can decide,
`peal work` decides; its last lines tell you which step comes next. This session plans
with the human and delegates the build: it never writes the task's code itself.

## 1. Where this session stands

Run `peal work $ARGUMENTS` and act on its output:

- **Refused** (non-zero exit): report its message and stop. In a task's worktree it
  refuses any other task or pool: that work starts from the main checkout. It refuses a
  human task (`owner: human`): the human works it, never a session; `peal claim` makes
  its worktree for them.
- **`TASK <id> <file>`**, followed by `PLAN` and `MODEL` lines: this worktree already
  holds the task (its branch is the task's, and the task is claimed here), whether the
  human opened the session here or something started it here after claiming. Claim
  nothing; go to step 4.
- **`CLAIMED <id> <path>`**: the task is claimed into the worktree at `<path>` (or was
  claimed on this machine already). Go to step 3.
- **`CANDIDATE` lines**: go to step 2.
- **Nothing**: the pool has no free task. Say so and stop; do not fall back to another
  pool.

## 2. The human picks

Ask with `AskUserQuestion`, one option per `CANDIDATE` line, labelled `Task <id>` and
described with its title and bucket (a milestone id, or `unassigned`); a piece of an open
split already says `(part of <origin>, <done>/<total> done)`. Put every `MORE <bucket>
<count>` line into the question, so a bucket with tasks beyond the ones shown never reads
as drained. The pick is the human's, never yours: the human may type another id under
"Other", which is claimed the same way.

Then run `peal work <picked id>`. A refusal now (most likely a race lost since the offer)
is reported and ends the command; do not claim another candidate instead. Otherwise go on
with its `CLAIMED` line.

## 3. Into the worktree

Pass along whatever `peal work` printed before `CLAIMED`: scope overlap warnings are for
the human, never a reason to stop.

Call `EnterWorktree` with the claimed `<path>`. If the tool is missing or refuses, do not
retry: tell the human to continue with `cd <path> && claude "/peal:work <id>"` and stop;
the claim stands either way. Once inside, run `peal work <id>` again: it prints the
`TASK`, `PLAN` and `MODEL` lines of step 4.

## 4. The task

Read the task file `TASK` names: it is the whole scope of this session. `PLAN` says what
comes next:

- `required`: the plan is not agreed yet. Step 5.
- `agreed`: the task's `## Plan` holds the plan the human agreed. Step 6.
- `skipped`: no plan needed. Step 6.

The `MODEL <role> <model>` lines name the model each subagent runs on: pass it as the
`model` of the `Agent` call that starts that subagent.

## 5. Plan, and stop for the human

Run `peal brief planner` and start the `peal:planner` subagent on the planner's model,
its prompt the brief followed by "Plan task <id>." and anything the human already said
about it in this session.

Then show the human the plan, whole, and stop for them: nothing is built until they agree
it. Ask through `AskUserQuestion`, which reaches the human however this session runs:

- each ambiguity the planner raised, its proposed default the first option, marked
  "(Recommended)" (at most four questions a call; ask again for more);
- then whether they agree the plan, the planner's model verdict, size, touches and merge
  recommendation included.

When the human changes the plan, revise it (start a fresh planner with their changes when
the approach itself moves) and ask again. Settle the plan with them; never settle it on
their behalf.

Once they agree, record it. Edit the task's text, the file `TASK` names (for tasks kept
elsewhere than in files, a copy of the task), never touching `## Raw`:

- `## Plan`, a new section after `## Notes` and before the `---` above `## Outcome`, if
  there is one: the agreed approach, the files, the verification, and the planner's
  `path:start-end` ranges;
- the human's answers under `## Notes`, and `## Scope` and `## Done when` sharpened where
  the human agreed to it;
- the size: `peal frontmatter set <file> size S|M|L`;
- the model: `peal frontmatter set <file> model <model>` when the agreed model is not the
  implementer's `MODEL` line, nothing otherwise;
- the touches: `peal frontmatter set-list <file> touches <path>...`, the plan's
  `Touches:` list as agreed;
- the merge: `peal frontmatter set <file> merge auto` only when the human agreed the
  planner's `merge: auto`, nothing otherwise. Never set it on your own judgement: it lets
  the pull request merge with no human looking at it.

Then `peal record <id> plan < <file>` puts it on the claim (a commit on the task's
branch, or the task where it is kept); a refusal names what to fix. Run `peal work <id>`
again: `PLAN agreed`, and the implementer's model as agreed.

## 6. Build, in the implementer

Run `peal brief implementer` and start the `peal:implementer` subagent on the
implementer's model, its prompt the brief followed by "Build task <id>." It reads the
task, the plan and the cited ranges itself. It ends with a status block:

- `STATUS: QUESTION`: ask the human each question through `AskUserQuestion`, the
  implementer's proposed default first and marked "(Recommended)"; for anything they
  must see, show them the files it names first. Record the answers under the task's
  `## Notes` and run `peal record <id> notes < <file>`, as in step 5; then
  resume the same implementer with `SendMessage` and the answers. If it cannot be
  resumed, start a fresh one: it continues from the branch.
- `STATUS: STOPPED`: tell the human what stopped it, with its block, and ask how to go
  on.
- `STATUS: DONE`: check that `git status --porcelain` is empty and the block's `COMMITS`
  are on the branch; then continue with `/peal:close`.

When the human interrupts a build to change something, resume the implementer with what
they said rather than making the change here.

## 7. Report

Say which task this session works and how it got here (resumed, claimed by id, or
picked from which pool), whether it entered the worktree, what `peal work` warned about,
where the plan stands, and the implementer's status block. A task that is awaiting merge
is finished and waits on the human's merge; it is never resumed.
