# Peal

Peal keeps a project's tasks as Markdown files in its repository and gives
[Claude Code](https://claude.com/claude-code) the commands to work them: file an idea,
plan a task, build it on its own branch, and open the pull request.

<!-- docs-check: shape -->
```text
> /peal:idea a health check endpoint
filed 0001 tasks/backlog/0001-health-check.md — milestone: -, plan: -, size: S — "Add a health check"

> /peal:work 0001
claimed 0001 task/0001-health-check ../myproject-wt/0001-health-check
  ... the plan, for you to agree; then the build in a subagent ...

> /peal:close
closed 0001: pull request #12 https://github.com/you/myproject/pull/12
```

The lines shown are what the commands print. You agree the plan, and you merge the pull
request.

## Why

- **Tasks live in the repository.** A task is a Markdown file with YAML frontmatter,
  reviewed and versioned like the code.
- **One branch and one worktree per task.** Claiming a task creates both, so work on
  several tasks never mixes.
- **A plan before code.** A planner subagent writes the plan, you agree it, and only then
  does an implementer build it. A reviewer checks the diff before the pull request opens.

Peal is not a tracker with a screen of its own. It does not replace GitHub issues: it can
keep the tasks in them. It does not need Belfry. It is not an autonomous agent: nothing
merges until you say so.

## Start

Install the plugin in a Claude Code session:

<!-- docs-check: install -->
```text
/plugin marketplace add Maximilian-Walz/peal
/plugin install peal@peal
```

Then run `/peal:setup` in your repository. [Getting started](docs/getting-started.md)
walks through what it does and the first task; the [reference](docs/reference/README.md)
lists every command and setting. A project that already has its own
task-file process migrates with [docs/migrating.md](docs/migrating.md).

## Status

Peal is before its first stable version. The [milestones](docs/milestones/) are the
roadmap.

## Peal and Belfry

Peal works on its own: every command runs in an ordinary Claude Code session.
[Belfry](https://github.com/Maximilian-Walz/belfry) is a self-hosted control plane that
runs Claude Code sessions unattended and gathers the decisions they need into one inbox.
Peal provides the commands Belfry's task contract asks for; neither depends on the
other.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md). MIT, see [LICENSE](LICENSE).

A peal is a full, ordered ringing of changes on a set of bells: a backlog worked through
in order.
