# Peal

A task-file process for [Claude Code](https://claude.com/claude-code) projects, packaged
as a plugin. Tasks live in your repository as Markdown files with YAML frontmatter.
Commands claim a task into its own branch and worktree, plan it, implement it in a
subagent, and close it as a pull request, and file, split, defer, revise and retire
tasks along the way. Milestones group the backlog.

A peal is a full, ordered ringing of changes on a set of bells: a backlog worked through
in order.

**Status:** being built; the plugin installs, its CLI lists, offers, claims, files,
revises and retires tasks and gates commits and pushes, its session hooks orient a
session, keep its budget and autosave its work, `/peal:work` claims, plans and builds
a task with the planner and implementer subagents, and `/peal:close` reviews it and opens
its pull request. See [docs/design.md](docs/design.md) and the issues.

## Peal and Belfry

Peal works on its own: every command runs in an ordinary interactive Claude Code session.

[Belfry](https://github.com/Maximilian-Walz/belfry) is a self-hosted control plane that
runs Claude Code sessions unattended on your machines and gathers every decision they
need into one inbox. Peal provides the commands Belfry's task contract asks for (list,
offer, claim, board, idea), so Belfry can show a Peal project's backlog, run its tasks,
and bring you only the questions, reviews and merges. Neither depends on the other.

## Working on Peal

This repository is a Claude Code plugin marketplace (`.claude-plugin/marketplace.json`)
with one plugin, `peal`, in `plugin/`:

- `plugin/bin/peal`, the CLI every command, hook and outside caller runs;
- `plugin/lib/`, its libraries, in bash and awk only: the frontmatter reader and writer
  for Peal's YAML subset, the configuration, the milestones, and the task storage
  (`store.sh`, the interface; `store-files.sh`, the task files; `store-issues.sh`, GitHub
  issues through `gh`, with `fake-gh` for its harness; `task-state.awk`, the read model's
  rules), claims (`claim.sh`), the session hooks (`session.sh`), and the
  git gates (`githooks.sh`, pre-push and commit-msg; `commit.sh`, `peal commit`;
  `git-guard.sh`, the Claude Code guard), `/peal:work`'s checks and the subagents'
  briefs (`work.sh`), and the close (`close.sh`: begin, finish, the pull request's body,
  verify, wait, the Stop hook), through `gh` (`github.sh`);
- `plugin/commands/`, the plugin's Claude Code commands (`/peal:work`, `/peal:close`), and
  `plugin/agents/`, its subagents (`planner`, `implementer`, `reviewer`);
- `plugin/hooks/`, the plugin's Claude Code hooks;
- `plugin/templates/`: `launcher`, the `.peal/peal` a project commits; `githook`, the
  git hook `peal hooks install` writes; and `task.md`, the task template.

Every script has a harness next to it, `<script>.test.sh`, runnable on its own with
`bash`. `tools/test-all.sh` runs them all and `tools/lint.sh` runs `shellcheck`; CI runs
both on every pull request.

## License

MIT, see [LICENSE](LICENSE).
