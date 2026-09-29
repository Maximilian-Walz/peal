# Reference

Where to look a thing up. Each page is complete and terse; the reasons are in
[the design](../design.md), the walk-throughs in [getting started](../getting-started.md)
and [migrating](../migrating.md).

| Page | Holds |
|---|---|
| [Commands](commands.md) | the `/peal:` commands: what each takes and does |
| [CLI](cli.md) | the `peal` subcommands, their output, exit statuses, environment variables |
| [Configuration](configuration.md) | `.peal/`, every setting with its default |
| [Tasks](tasks.md) | task files, their frontmatter, sections and claim states; milestone files |
| [Storage](storage.md) | task files or issues: ids, the issue mapping, who is admitted |

## Words

The docs and the commands use these words, and only these, for these things.

- **task**: the unit of work, a file under `tasks/` or a GitHub issue. Not "ticket".
- **idea**: a task filed rough, by `/peal:idea`, before anyone plans it. It is a task;
  the word says only how it was filed.
- **backlog**: the tasks not claimed and not done; the directory `backlog/`.
- **claim**: one session's hold on one task: a branch, a worktree, a moved file. Also
  the verb of `peal claim`.
- **worktree**: the checkout a claim lives in, `{worktrees}/NNNN-slug`.
- **main branch**: the branch tasks land on, the `main` setting. Not "master", not
  "trunk".
- **milestone**: a goal with tasks, a file or a GitHub milestone. Not "release".
- **release**: a tagged version, made by `/peal:release`. `peal release ID` is not that:
  it releases a claim's worktree. The docs write "release a claim" for it.
- **pull request**: what `peal close` opens. Written out in text, "PR" only in code and
  settings (`pr.sections`).
- **state**: a task's claim state (`free`, `claimed-live`, ...) or a milestone's
  (`open`, `current`, ...). Say which.
- **stage**: a step of setting a project up (`tasks`, `guardrails`, `milestones`,
  `belfry`), run by `peal init`. Not a feature.
- **feature**: something `/peal:next` suggests within the stages (`drift`, `releases`,
  ...). Not a stage.
- **gate**: a git hook Peal installs, `pre-push` or `commit-msg`. The **guard** is the
  PreToolUse hook on Bash. Hooks are the Claude Code ones.
- **storage**: where tasks live, `files` or `issues`. Not "backend": that is Belfry's
  word for the same choice in its contract.
- **pool**: a comma list of milestone ids, `current` and `unassigned`, for `offer`.
- **plan**: what the planner proposes and the human agrees; the task's `## Plan`.
- **Outcome**: the section written at close; the pull request shows it.
- **launcher**: `.peal/peal`, the script that finds the installed plugin.
- **reference project**: the project whose process Peal generalises.
