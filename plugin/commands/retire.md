---
description: Retire an unclaimed task whose premise died, straight into the storage, once the human confirms.
argument-hint: "<task id> <why>"
---

Arguments: `$ARGUMENTS`, a task id and the reason (e.g. `0283 the script it fixes was
deleted by 0276`).

`peal` is Peal's CLI, on the Bash tool's path. Retire is for a task nobody has claimed
whose premise died: something else landed first, a decision took its ground away. It
writes straight into the storage, with no pull request: the human's confirmation below
is the only review it gets. It never touches a claimed task (give that back with
`/peal:defer`, or close it with `/peal:close`) and never this worktree.

If the id or the reason is missing, ask the human for it with `AskUserQuestion`.

## 1. Confirm with the human

Read the task with `peal read <id>`. Then ask with `AskUserQuestion`, whatever the
arguments already said, showing:

- the task's id and title;
- the reason, as given;
- what happens: for task files, the file moves to `done/` and everything from its
  `## Outcome` heading on becomes one line, `Retired <date> without being claimed: <why>`
  (a file without the heading gets it); for issues, the issue is closed as not planned,
  that line its comment.

Options: retire (first), or not. Anything but a yes ends the command, nothing changed.

## 2. Retire it

```bash
peal retire <id> --reason "<why>"
```

It refuses, and changes nothing, when: the task does not exist, is done, or is claimed
anywhere; the reason is empty; its Outcome is filled in (work happened: that is a
close); or a task not done still names it in `depends` or `part-of`. For the last, the
refusal lists them: re-point each with `/peal:revise` first, then retire again.

## 3. Report

Say what `peal retire` printed. The task is `done` from the next read on; nothing else
is needed.
