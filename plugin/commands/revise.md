---
description: Correct an unclaimed task's text (scope narrowed, depends fixed, milestone retriaged, priority changed) straight into the storage, once the human confirms the change.
argument-hint: "<task id> <what changes and why>"
---

Arguments: `$ARGUMENTS`, a task id and what changes, with why (e.g. `0284 drop the CLI
flag: 0276 removed the script`).

`peal` is Peal's CLI, on the Bash tool's path. Revise corrects the text of a task nobody
has claimed, because something else changed its ground: a sibling shipped part of its
scope, a `depends` went stale, its milestone needs retriaging. It writes straight into
the storage, with no pull request: the human's confirmation below is the only review it
gets. Its priority changes the same way: `priority: urgent`, `high` or `low` in the
frontmatter, or the line dropped for `normal`. A `merge: auto` the task no longer earns
(its ground grew riskier) is dropped the same way; revise never adds one, since only the
human's agreement to a plan writes it. A task whose whole premise died is retired (`/peal:retire`), not revised; a
claimed one is changed in its own session. It never touches this worktree.

If the id or the change is missing, ask the human for it with `AskUserQuestion`.

## 1. Compose the new text

Read the task with `peal read <id>` and write its full new text. What `peal revise`
refuses:

- a heading with another number (`# <id> — <Title>`; the title may change);
- a changed `## Raw`, or one added or dropped: it is the human's own words. A wrong Raw
  is retired and filed again instead;
- a changed `part-of` (only a split writes it);
- an Outcome filled in, or its heading added or dropped;
- a milestone moved into or out of a `parked` one (a milestone review's call), or a
  `depends` naming no task;
- a `depends` that closes a cycle (exit 1, `refused: depends cycle 0042 → 0043 → 0042`):
  every task on it would wait for itself; drop the entry that closes it;
- for task files, no `## Notes` section: the reason is recorded there;
- the text unchanged.

## 2. Confirm with the human

Run the dry run first, so what the human sees already passed every check:

```bash
peal revise <id> --reason "<why>" --dry-run <<'TEXT'
<the new text>
TEXT
```

Show the human the diff it printed and the reason, and ask with `AskUserQuestion`:
revise (first), or not. Anything but a yes ends the command, nothing changed.

## 3. Revise it

The same call without `--dry-run`, the same text. It reads the task afresh, refuses
anything the dry run would and a task claimed since, and replaces the task's text whole:
if anything may have changed the task since the dry run, start over from step 1, since
the diff the human saw is stale.

On success the task holds the new text; the reason is a dated line
`Revised <date>: <why>`, under the file's `## Notes` or as the issue's comment.

## 4. Report

Say what `peal revise` printed. The next read of the backlog sees the new text.
