# Setting up in stages

[Getting started](../getting-started.md) takes the shortest road: install, run
`/peal:setup`, work a first task. This guide holds what that page leaves out: pinning a
version, the stages one at a time and how to undo each, and how Peal suggests what to
adopt next.

## Pin a release

The install in getting started tracks `main`, so you get every change as it lands. To pin
a release instead, add its tag as the `ref` of the marketplace source in
`.claude/settings.json`:

<!-- docs-check: settings -->
```json
{
  "extraKnownMarketplaces": {
    "peal": {"source": {"source": "github", "repo": "Maximilian-Walz/peal", "ref": "vX"}}
  },
  "enabledPlugins": {"peal@peal": true}
}
```

## The stages

Peal sets a project up in steps called stages. `/peal:setup` with no argument takes the
first one, `tasks`. `/peal:setup STAGE` takes one named stage. Every stage but `tasks`
needs `tasks` first. Each is safe to run again, and `peal init --remove STAGE` takes it
back; your tasks stay.

| Stage | Adds | Take it back |
|---|---|---|
| `tasks` | `.peal/config.yml`, the launcher `.peal/peal`, `tasks/` with `backlog/`, `doing/`, `done/` and `TEMPLATE.md`, and the plugin in `.claude/settings.json`. Peal supports two storages for tasks: the files described here, or GitHub issues (`peal init --stage tasks --storage issues`), where tasks are issues instead of files. | `peal init --remove tasks`, once no other stage is set up |
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
