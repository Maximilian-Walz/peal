---
plan: required
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

Decided up front: the existing `peal brief ROLE` of the CLI stays as it is;
`/peal:brief` is a command, not that subcommand.

Once `peal done` and `/peal:brief` exist, `.belfry.yml` can name them as
`tasks.commands.done` and `tasks.commands.prepare`.

---

## Outcome

