# The backlog

The backlog is the tasks nobody has claimed. This page is how they get in, change and
leave. All of these write straight to the main branch, or to the storage, so none needs
a task of its own.

## Reading it

`peal list` shows every task with its claim state, and `peal offer` what would be
offered next. `/peal:work` with no number runs `offer` and asks you to pick. Both are in
[the CLI reference](../reference/cli.md#peal-list).

## Getting tasks in

- `/peal:idea <words>` files a rough idea in one pass and asks nothing. Your words go
  into `## Raw` untouched; the rest of the task is the command's best reading. On a task's
  branch the idea waits and is filed when that task closes.
- `/peal:split` cuts the task you are working into pieces, filed together, and narrows the
  task to its first piece. Use it when the plan shows the task is several.
- `/peal:defer <why>` gives your claim back when the task turns out blocked and nothing
  was built. It keeps the number and what the session learned.

## Changing and leaving

- `/peal:revise <id> <what changes>` rewrites an unclaimed task in place and shows the
  diff first. Use it when the scope moved, not to add a note.
- `/peal:retire <id> <why>` closes an unclaimed task whose premise died, with the reason
  as its Outcome.

Both ask you to confirm before anything is written, and both refuse a claimed task: the
claim's owner changes that one. The commands run these `peal` subcommands:

<!-- docs-check: run -->
```text
$ peal init --stage tasks >/dev/null
$ git add -A && git commit -qm "chore(peal): set up the tasks stage"
$ git push -q -u origin main
$ printf -- '---\nsize: S\n---\n\n# NNNN — Add a health check\n\n## Raw\n\n> a health check\n\n## Notes\n\nNone yet.\n' | peal idea health-check
filed 0001 tasks/backlog/0001-health-check.md — milestone: -, plan: -, size: S — "Add a health check"
$ printf -- '---\nsize: S\n---\n\n# NNNN — Rotate the logs\n\n## Raw\n\n> rotate logs\n\n## Notes\n\nNone yet.\n' | peal idea rotate-logs
filed 0002 tasks/backlog/0002-rotate-logs.md — milestone: -, plan: -, size: S — "Rotate the logs"
$ peal list
0001 free health-check -
0002 free rotate-logs -
$ peal offer current,unassigned
CANDIDATE 0001 unassigned Add a health check
CANDIDATE 0002 unassigned Rotate the logs
$ peal read 0001 | sed 's/^# 0001 — .*/& endpoint/' | peal revise 0001 --reason "it is an endpoint" --dry-run
revise: a dry run; nothing pushed
$ peal retire 0002 --reason "logs are rotated by the host now"
retired 0002 tasks/done/0002-rotate-logs.md
$ peal list
0002 done rotate-logs
```

`--dry-run` prints the diff and pushes nothing. `peal list` still shows the retired task,
as `done`, so nothing is lost. The `size` and `plan` of a task are the planner's to
settle; see [Tasks](../reference/tasks.md#fields).
