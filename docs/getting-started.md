# Getting started

This takes you from an installed plugin to a first task worked and closed. Each step says
what it adds and how to take it back.

## Install

In a Claude Code session:

<!-- docs-check: install -->
```text
/plugin marketplace add Maximilian-Walz/peal
/plugin install peal@peal
```

This tracks `main`. To pin a release instead, add its tag as the `ref` of the marketplace
source in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "peal": {"source": {"source": "github", "repo": "Maximilian-Walz/peal", "ref": "vX"}}
  },
  "enabledPlugins": {"peal@peal": true}
}
```

## Set up, one stage at a time

Run `/peal:setup` in your repository. It reads the repository, recommends where the tasks
should live, asks once, and writes the first stage as one commit on a `peal/setup-tasks`
branch for you to review. It never commits to your main branch. Then it proposes one or
two first tasks from what it read, and ends by saying what you can do now and which stage
comes next. Merge that branch into your main branch (setup offers to open the pull
request) before working a task: `/peal:work` claims from the main branch.

`/peal:setup STAGE` sets up one stage. Every stage but `tasks` needs `tasks` first. Each
is safe to run again, and `peal init --remove STAGE` takes it back; your tasks stay.

| Stage | Adds | Take it back |
|---|---|---|
| `tasks` | `.peal/config.yml`, the launcher `.peal/peal`, `tasks/` with `backlog/`, `doing/`, `done/` and `TEMPLATE.md`, and the plugin in `.claude/settings.json`. With the issues storage, tasks are GitHub issues instead of files. | `peal init --remove tasks`, once no other stage is set up |
| `guardrails` | Git hooks that check commit subjects and pushes. | `peal init --remove guardrails` |
| `milestones` | A first milestone, `docs/milestones/m1.md`. | `peal init --remove milestones` |
| `belfry` | `.belfry.yml`, so [Belfry](https://github.com/Maximilian-Walz/belfry) can list and run the tasks. | `peal init --remove belfry` |

`peal init` is what `/peal:setup` runs underneath. In a git repository it looks like
this:

<!-- docs-check: run -->
```text
$ peal init --stage tasks
created .peal/config.yml
created .peal/peal
created tasks/backlog/.gitkeep
created tasks/doing/.gitkeep
created tasks/done/.gitkeep
created tasks/TEMPLATE.md
created .claude/settings.json (the peal plugin enabled for the project)
$ git add -A && git commit -qm "chore(peal): set up the tasks stage"
$ peal next
SUGGEST guardrails /peal:setup guardrails …
$ peal init --stage milestones
created docs/milestones/m1.md
$ peal init --remove milestones
removed docs/milestones/m1.md
removed docs/milestones/
removed docs/
```

Nothing is committed by `peal init`; the lines show what changed, for you to commit.
`.peal/config.yml` records the stages done, as `stages:`.

## What to adopt next

`/peal:next` looks at your repository and its task history and suggests the one next
stage or feature, with the evidence for it, and up to three more. Besides the stages
above it knows the features `decisions`, `drift`, `releases`, `reviewer` and
`review-steps`. It suggests nothing your project has not earned: `guardrails` once a task
is done, `milestones` at ten tasks done, and so on. It never asks GitHub or Belfry.

You accept, decline or ask for more; nothing changes unasked. To decline, run `peal next
--decline ITEM`: it records `declined.ITEM` with today's date in `.peal/config.yml`, and
the item is not suggested again for 90 days. To undo a feature, delete its file (for
example `.peal/drift.md`) or its key from `.peal/config.yml`; nothing is filed. A
decline looks like this:

<!-- docs-check: config -->
```yaml
stages: [tasks, guardrails]
declined:
  drift: [2026-09-29]
```

## Your first task

1. File an idea. `/peal:idea a health check endpoint` writes a task file in
   `tasks/backlog/` and prints its `filed` line. On a task's branch the idea is queued
   and filed when that task closes.
2. Work it. `/peal:work 0001` claims the task into its own branch and worktree, has the
   planner write a plan, asks you to agree it, and has the implementer build it. Without
   a number, it offers the next task.
3. Close it. `/peal:close` reviews the diff, writes the task's Outcome, moves the task to
   `done/` and opens the pull request, then waits for its checks. You merge it. Opening
   the pull request needs the `gh` command line tool, logged in to GitHub.

`peal list` shows the backlog at any time.

## Already have a task process

See [migrating an existing project](migrating.md).

## Where to look things up

The [guides](guides/README.md) take each workflow in turn, starting where this page ends;
the [reference](reference/README.md) lists every command, `peal` subcommand, setting and
task field; [the design](design.md) says why.
