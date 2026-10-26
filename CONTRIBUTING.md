# Contributing to Peal

Thank you for helping. Read [docs/design.md](docs/design.md) first: it is the design
(the why); [docs/reference/](docs/reference/README.md) is the reference. This page is how to work in the repository.

Peal runs on itself. Its backlog is the task files under `tasks/`, its milestones are
`docs/milestones/`, its settings `.peal/config.yml`. A task is worked with `/peal:work`
and closed with `/peal:close`, and new work is filed with `/peal:idea`. GitHub issues
are not tasks: open one to report a bug or propose an idea (the templates ask what a
maintainer needs), and a maintainer files the task. A vulnerability goes in a private
report, not an issue: see [SECURITY.md](SECURITY.md).

## Layout

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
  briefs (`work.sh`), the backlog commands' steps above the storage, defer and the
  revise of one's own claim (`backlog.sh`), the close (`close.sh`: begin, finish,
  the pull request's body, verify, wait, the Stop hook), through `gh` (`github.sh`),
  a milestone's end (`review.sh`: the review's brief, the state change), the optional
  decision records (`decisions.sh`: reserve, check, index, publish, brief), releases
  (`ship.sh`: the proposal, the notes, the version files, the tag, the GitHub release, the wait), writes
  onto the main branch (`main-write.sh`), a project's setup in stages and the survey `/peal:setup` decides from (`init.sh`,
  with `config-block.awk` and `settings-json.awk` editing the config and Claude Code's
  settings as text), what to adopt next, with the `declined:` bookkeeping (`next.sh`), and
  what is broken in a project's installation, one fix per problem (`doctor.sh`);
- `plugin/commands/`, the plugin's Claude Code commands (`/peal:work`, `/peal:idea`,
  `/peal:split`, `/peal:defer`, `/peal:revise`, `/peal:retire`, `/peal:close`,
  `/peal:milestone-review`, `/peal:drift`, `/peal:release`, `/peal:setup`,
  `/peal:next`), and
  `plugin/agents/`, its subagents (`planner`, `implementer`, `reviewer`);
- `plugin/hooks/`, the plugin's Claude Code hooks;
- `plugin/templates/`: `launcher`, the `.peal/peal` a project commits; `githook`, the
  git hook `peal hooks install` writes; `task.md`, the task template; and
  `decisions.yml`, the workflow that regenerates a project's decisions index after a
  merge; and `merge-gate.yml`, the workflow that fails a pull request in which a task
  file gains a `merge` key.

## Harnesses, lint and CI

Every script has a harness next to it, `<script>.test.sh`, runnable on its own with
`bash`. `tools/test-all.sh` runs them all, or the ones you name, and `tools/lint.sh` runs
`shellcheck`, `tools/pins.sh` (a workflow's action or Peal fetch must be pinned by SHA), `tools/guards.sh` (every guard `docs/security.md` names is in `.belfry.yml`'s reviewed paths), a
`cmp` of `.peal/peal` against `plugin/templates/launcher` (a task that changes the template
refreshes the committed launcher in the same PR) and `peal check`. `tools/docs.test.sh` checks the documentation: every
command and relative link it names exists, and every fenced block carries a marker
comment, `<!-- docs-check: KIND -->` right above it, so a copied example works. The kinds:
`run` (its `$ ` lines run), `config` (loads as `.peal/config.yml`), `frontmatter` (a header
`peal frontmatter check` accepts), `shape` (the `filed`, `claimed` and `closed` lines),
`install` (the `/plugin` and `claude plugin` lines match the marketplace and plugin), `settings` (a `.claude/settings.json`
as `peal init` writes it), `migrate` (the `peal migrate` lines run on a pre-Peal project),
`sections` (the task template's sections), `belfry` (a `.belfry.yml` as `peal init` writes
it) and `decision` (an entry `peal decision check` accepts). A block with no marker is
reported, and there is no exempt one.

CI runs the lint and every harness on each pull request, with `tools/pins.test.sh`; a pull request that changes only
tasks, milestones or a release's bump and pin (the version, the changelog entry, the SHA
and tag of a template's Peal fetch line) skips the harnesses. The slow harnesses are split into shards, and
"rest" is computed, so a new `*.test.sh` is covered the moment it exists
(`.github/workflows/ci.yml`).
The shards are balanced from the seconds `tools/test-all.sh` prints per harness; it prints
its total too, and CI warns when a shard's total passes `PEAL_TEST_BUDGET`, so drift shows.

## Running on itself

A fresh clone installs the git gates itself, at the first `peal claim` or session start;
`.peal/peal hooks install` does it by hand, or again over a `core.hooksPath` the
automatic install only warned about. The process runs the installed plugin, not the
checkout's `plugin/`, so a branch cannot change the gates it is checked by. To try a
branch's CLI, run `PEAL_ROOT=$PWD/plugin plugin/bin/peal`.

### Refreshing the installed plugin from main

Merges to main do not change the plugin's version, so `/plugin` update can keep a cached
copy that predates tasks merged since. To get the latest main in one go:

<!-- docs-check: install -->
```sh
claude plugin marketplace update peal
claude plugin uninstall peal@peal --scope project
claude plugin install peal@peal --scope project
```

Use the scope the plugin is installed at (`claude plugin list`). The reinstall fetches a
fresh copy into the cache (an uninstalled copy is marked `.orphaned_at`, which the
launcher skips). Then restart the Claude Code session; its SessionStart hook records the
new root. A stale `.git/peal-root` no longer pins old code: the launcher and the git hooks
run the highest version among the recorded root and the cache, and the record is never
moved back to an older Peal. Between two builds of the same version, the recorded root
wins, which is the same path after a reinstall. Clones whose git hooks were installed
before need `.peal/peal hooks install` once, to replace the stubs with the current ones.

The reinstall and `.peal/peal hooks install` were tried against a scratch
`CLAUDE_CONFIG_DIR` with this checkout as the marketplace; `marketplace update` was tried
there too, but not against GitHub.

## Commits and pull requests

Commit with `peal commit "<type>(<area>): <what> [NNNN]" [PATH...]`: the type is one of
`feat fix test refactor docs chore`, NNNN the task's id. Each commit runs the project's
checks. One task is one branch and one pull request, which `/peal:close` opens; write the
body by hand only for a change made outside a task.

Peal generalises a process; only what is generic belongs here. Project-specific tooling
stays in its project, behind an extension point.
