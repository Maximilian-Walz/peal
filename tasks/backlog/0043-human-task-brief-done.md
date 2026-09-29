---
plan: required
milestone: m5
---

# 0043 — Human tasks: /peal:brief and peal done

## Intent

Human tasks (the `owner` field) need a start and a finish of their own, for Belfry's
Start and Done of a human task: a brief that tells the human what the result must meet,
and a way to close a task that leaves nothing in the repository.

## Scope

- `/peal:brief {task}`: writes a brief for the human into the task's `## Notes` from
  the project's docs (what the result must meet, names, constraints, where files go) and
  commits it on the task's branch. It is what Belfry's `prepare` prompt runs for a Peal
  project; projects can extend it with their own scaffolding.
- Closing a human task that changed the repository is `/peal:close`, as for any task;
  the reviewer judges the diff the human made.
- `peal done <id> <note>` closes a human task that leaves nothing in the repository: it
  moves to done with the note as its outcome, straight into the storage without a PR, the
  way `/peal:retire` does. It refuses an AI task. It is what Belfry's `done` command
  runs.

## Done when

- Harnesses cover `peal done` (and its refusal of an AI task) and the brief's commit on
  the branch.

## Raw

Filed as issue #43 (https://github.com/Maximilian-Walz/peal/issues/43), part of human tasks (#33, done); its text is carried over
into the sections above and below.

## Notes

Deferred 2026-09-28 after a claim: stale claim: its session stopped; given back so auto mode picks it up again

Decided up front: the existing `peal brief ROLE` of the CLI stays as it is;
`/peal:brief` is a command, not that subcommand.

Once `peal done` and `/peal:brief` exist, `.belfry.yml` can name them as
`tasks.commands.done` and `tasks.commands.prepare`.

- A plan drafted by an earlier session (autosaved, never agreed), kept here for the next one:

  # Draft plan for 0043, NOT agreed (the human's questions timed out twice on 2026-09-25/26)

  Planner's plan, as proposed. Rerun /peal:work 0043 to ask the human; delete this file once the plan is recorded.

  ## Approach
  - peal done <id> <note>: new CLI subcommand.
    - store-files.sh: _peal_files_done, modelled on _peal_files_build_retire. Moves backlog/NNNN to done/NNNN and writes the note into the Outcome. Commit `docs(tasks): done NNNN slug [NNNN]`, pushed with peal_push_main.
    - Refuses: AI tasks (explicit owner: ai, or no owner), tasks already done, an empty note, an Outcome already filled in, and a claimed branch holding real work (it points to /peal:close; model on _peal_files_no_work).
    - Allows, unlike retire: a claim, and tasks that depend on this one.
    - store-issues.sh: _peal_issues_done. Adds a dated comment, closes the issue as completed, removes the `in progress` label.
    - bin/peal: the done dispatch and usage line, plus a hostile.test.sh case.
    - githooks.sh: a pre-push `docs(tasks): done` shape like retire's, with its own allowed and refused cases. git-guard.sh:233: add done to the message list.
  - /peal:brief: new plugin/commands/brief.md.
    - Checks this worktree holds the task and refuses an AI task.
    - Reads the task and the context docs from `peal config context`, then writes or replaces `### Brief` under ## Notes.
    - Records it with `peal record <id> notes`.
    - Follows .peal/brief.md if the project has one, for its own scaffolding, committed with peal commit.
    - Pushes the branch and ends by printing the brief in full.
  - Wiring: prepare/done lines in init.sh's generated .belfry.yml and in this repo's .belfry.yml. hand_in stays out and is filed as an idea.
  - Docs: docs/design.md and README.md.
  - Tests: store-files, store-issues, githooks, hostile, work.test (the brief's notes commit on a human task's branch), commands.test, init.test.
  - Size M (near the top). Model: default. Merge: default (the task widens the pre-push gate).
  - Touches: plugin/bin/peal, plugin/lib/*.sh, plugin/commands/brief.md, plugin/commands/commands.test.sh, docs/design.md, README.md, .belfry.yml

  ## Open questions (the planner's defaults in parentheses)
  A1 Split, or build it whole? (whole)
  A2 Accept a claim; refuse real work on the branch? (yes)
  A3 Which text lands in done/? (the remote branch's doing/ copy, else main's)
  A4 Release the worktree after done? (no, leave it for reaping)
  A5 Outcome wording? (a dated line: `Done <date> by the human: <note>`)
  A6 Skip done tasks in the release notes, like retire? (skip; touches ship.sh:169)
  A7 Allow done on a split origin with pieces still open? (allow)
  A8 Is the brief's commit covered by reusing `peal record notes` in a harness plus a static check of brief.md? (yes, no new WHAT)
  A9 Should /peal:brief push the branch? (yes)
  A10 /peal:brief on an AI task, or outside the task's worktree? (refuse both)
  A11 Extension point? (.peal/brief.md, scaffolding committed separately)
  A12 Wire prepare/done into both .belfry.yml files? (yes; hand_in goes to an idea)
  A13 Does a re-run replace the Brief block or append another? (replace)
  A14 Print the brief in full as the final answer? (yes)
  A15 Extend peal_store_finish with a third kind, or add peal_store_done? (extend peal_store_finish)
  A16 Issues: close as completed, with the note as a dated comment? (yes)
  A17 A /peal:done command as well? (no, the CLI only)
  A18 Closing a human task with changes: document it? (a line in design.md only)
  A19 Positional arguments: exactly two, empty note refused? (yes)
  A20 Commit subject `docs(tasks): done NNNN slug [NNNN]`? (yes)

---

## Outcome

