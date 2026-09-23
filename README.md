# Peal

A task-file process for [Claude Code](https://claude.com/claude-code) projects, packaged
as a plugin. Tasks live in your repository as Markdown files with YAML frontmatter.
Commands claim a task into its own branch and worktree, plan it, implement it in a
subagent, and close it as a pull request, and file, split, defer, revise and retire
tasks along the way. Milestones group the backlog.

A peal is a full, ordered ringing of changes on a set of bells: a backlog worked through
in order.

**Status:** being designed; nothing to install yet. See [docs/design.md](docs/design.md)
and the issues.

## Peal and Belfry

Peal works on its own: every command runs in an ordinary interactive Claude Code session.

[Belfry](https://github.com/Maximilian-Walz/belfry) is a self-hosted control plane that
runs Claude Code sessions unattended on your machines and gathers every decision they
need into one inbox. Peal provides the commands Belfry's task contract asks for (list,
offer, claim, board, idea), so Belfry can show a Peal project's backlog, run its tasks,
and bring you only the questions, reviews and merges. Neither depends on the other.
