# Configuration

A project keeps everything of Peal's in `.peal/`. Every setting is optional; a key not
listed here is refused, except under `task.fields`. The defaults are in
`plugin/lib/config-defaults.yml`; `peal config [KEY]` prints the effective values
([CLI](cli.md#peal-config)). The reasons are in [the design](../design.md#configuration).

## Files

| Path | What |
|---|---|
| `.peal/config.yml` | the settings, below |
| `.peal/peal` | the launcher, committed |
| `.peal/reviewer.md`, `.peal/planner.md` | optional: the project's own rules for these subagents, appended to their prompts |
| `.peal/drift.md` | optional: what `/peal:drift` compares |
| `.peal/review.md` | optional: the project's steps for `/peal:milestone-review` |

## Settings

A dotted key is a key under its parent: `storage.issues.label` is `label` under `issues`
under `storage`.

| Key | Default | Meaning |
|---|---|---|
| `remote` | `origin` | the remote |
| `main` | `main` | the branch tasks land on |
| `main-writes` | `auto` | how Peal's own writes reach the main branch: `push`, `pr` (through a pull request) or `auto` (push; `pr` once the remote refuses) |
| `tasks` | `tasks` | the directory holding `backlog/`, `doing/`, `done/` and `TEMPLATE.md` |
| `milestones` | `docs/milestones` | the milestone files' directory |
| `branch-prefix` | `task/` | a claim's branch is `<prefix>NNNN-slug` |
| `worktrees` | `../{repo}-wt` | where claims live; each is `{worktrees}/NNNN-slug` |
| `worktree-setup` | `""` | a command run once in each new or resumed claim's worktree, with `PEAL_PRIMARY` the primary checkout's path; a failure fails the claim |
| `sizes` | `{S: 60, M: 120, L: 200}` | tool calls per size tier; the turn budget nudges there |
| `plan.required-paths` | `[]` | a task touching one of these gets `plan: required` |
| `review.skip-paths` | `[docs/, tasks/]` | a diff only under these skips the reviewer |
| `context` | `[]` | documents the planner, reviewer and `/peal:idea` read |
| `checks.commit` | `[]` | commands the `commit-msg` gate runs; `"PATH...: COMMAND"` only when the commit touches one of those paths |
| `checks.close` | `[]` | commands `peal close finish` runs before opening the pull request |
| `pr.sections` | `[]` | extra prose sections close asks the session for, each `"Title: what to write"` |
| `commit.areas` | `[]` | allowed `<area>` values in commit subjects, then required; empty allows any or none; `tasks` is always one |
| `models` | `{planner: opus, reviewer: opus, implementer: sonnet}` | the subagents' models; a task's `model` overrides the implementer's |
| `task.fields` | `{}` | the project's own frontmatter fields: name, and optionally the allowed values |
| `storage.kind` | `files` | where tasks live: `files` or `issues` ([Storage](storage.md)) |
| `storage.issues.repo` | `""` | `owner/name`; empty: the remote's GitHub repository |
| `storage.issues.label` | `""` | only issues with this label are tasks; empty: the issues opened by someone with write access |
| `release.tag-prefix` | `v` | release tags are `<prefix>MAJOR.MINOR.PATCH` |
| `release.wait-ci` | `false` | `/peal:release` waits for the workflow runs of the tag |
| `release.report` | `[]` | texts whose lines in those runs' logs the release reports, e.g. `"digest: sha256:"` |
| `release.version-files` | `[]` | files the release sets to its version before the tag, each `"PATH: FIELD"`, a top-level field of a JSON, TOML or YAML file |
| `decisions` | `false` | the decisions module: `false`, or its directory to turn it on |
| `stages` | `[]` | the setup stages `peal init` has done; belongs to it |
| `declined` | `{}` | `/peal:next`'s declines, `{item: [DATE]}`; blocks an item for 90 days from `DATE` |

The issues storage writes no task onto main: with the decisions module off and no
`release.version-files`, a `main-writes` other than `auto` only warns.

## Conventions with no setting

The `backlog`/`doing`/`done` directories, `NNNN-slug.md` names, one task per branch and
pull request, the task sections, the commit subject grammar
`<type>(<area>): <what> [NNNN]`, which pushes may reach the main branch directly, and the
close sequence. A setting exists only where two real projects would differ.

## `worktree-setup`

Gives a task worktree the local files the project's commands need (`.env`,
`*.local.yaml`), which git does not carry. It runs in the new worktree after the git
gates are ensured and before the scope-overlap warning, with no timeout. It is a command
taken from the checkout's config, like `checks.commit` ([Security](../security.md)). The
common case links the files from the primary checkout:

<!-- docs-check: config -->
```yaml
worktree-setup: 'for f in .env values.local.yaml; do ln -sf "$PEAL_PRIMARY/$f" "$f"; done'
```
