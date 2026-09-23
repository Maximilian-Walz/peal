# Peal — design

Peal turns a repository's tasks into a process Claude Code sessions can follow: task
files with YAML frontmatter, and commands that claim, plan, implement, close, file,
split, defer, revise and retire them, grouped by milestones.

This document is being written (see issue #1). Its principles so far:

## Peal and Belfry

Peal and [Belfry](https://github.com/Maximilian-Walz/belfry) are separate projects that
fit together.

- **Peal never needs Belfry.** Every command works in an interactive session with
  nobody else involved.
- **Belfry never knows Peal.** Belfry talks to projects through its contract
  (`.belfry.yml`); Peal is one tooling that answers it.

Where they meet is small and written down, so either can change without the other
following:

| | Peal provides | Belfry expects |
|---|---|---|
| tasks | list, offer, claim (printing the worktree), board and idea commands | the `commands` backend of its contract |
| milestones | milestones as data | a milestone list in the board output |
| a session | `/work` and `/close` in the claimed worktree | claim before the session; finished means a PR open and green |
| the human | questions through `AskUserQuestion` | routes them to its inbox |

## Task files

A task's header is real YAML frontmatter: a `---` block at the top, lists such as
`depends` and `needs` as YAML lists.

## Milestones

Milestones are data: an id, a title, a state (`open`, `current`, `done`, `parked`), an
order, and an optional due date. Belfry reads them from the board output.

## Storage

The commands work on tasks through a small storage interface (create, read, edit, a
part-of relation, set milestone and state, finish as done or retired). Task files in
the repository are the first implementation; others, such as GitHub issues, can follow
when a project wants Peal's workflow on them.
