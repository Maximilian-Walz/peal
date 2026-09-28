# Peal — migrating an existing project

A project that already runs its own task-file process adopts Peal by migrating, not
rewriting: tasks keep their numbers, history stays, and the project's own tooling keeps
working through Peal's extension points ([`docs/design.md`, "Scope: what moves, what
stays"](design.md#scope-what-moves-what-stays)). This is the whole procedure, in the
order a project follows it. It lands as one task, one pull request, in the project
itself — the same commit gates and review as any other change there.

## 1. Decide what moves and what stays

Read [the scope tables](design.md#scope-what-moves-what-stays) (commands, subagents,
scripts, hooks, documents) before touching anything. Each reference piece is marked:

- **moves** — Peal replaces it outright (task state, claim/offer/release, the backlog
  commands, the close sequence, the subagents, the git gates, the task template, ...).
- **moves, with an extension point** — Peal supplies the generic half and calls into
  the project for the rest (the reviewer's and planner's rules, the checks a commit or a
  close must pass, a pull request's extra prose sections, the milestone review's own
  steps). These move into `.peal/`, step 4 below.
- **stays** — project-specific tooling Peal never absorbs: an engine layering guard,
  a code-health counter, screenshot or render scripts, a byte-budget guard, `.belfry.yml`.
  Nothing here changes; a "moves, with an extension point" row is how it keeps reaching
  a task (a project's checks, its PR sections, ...).
- **dropped** — superseded by a Peal mechanism (a claim gate replaced by the worktree
  check).

Make this call once, before step 5 deletes anything: a script marked "stays" keeps
running exactly as it does today; only its trigger (a hook, a command) may need to call
it from a Peal extension point instead of the piece it replaces.

## 2. Install the plugin

`peal init --stage tasks` and `peal init --stage guardrails`. Run with an existing
`tasks/` directory, the `tasks` stage keeps its layout (`backlog/`, `doing/`, `done/`)
and its `TEMPLATE.md` as they are — nothing here converts a single file yet. It also
writes `.peal/config.yml` (with Peal's defaults as comments), the committed launcher
`.peal/peal`, and the `.claude/settings.json` lines that enable Peal for everyone
working on the project ([`docs/design.md`, "Distribution"](design.md#distribution)).
`guardrails` installs the git hooks for this clone.

**Replace the project's own `TEMPLATE.md` with Peal's** (`${CLAUDE_PLUGIN_ROOT}/templates/task.md`
in a Claude Code session, or the marketplace's own `plugin/templates/task.md`): the
converters in the next step skip it deliberately, since it is prose, not a `key: value`
header to rewrite, so it is the one file this migration does not touch for you. A
project's old template keeps writing the old header on every new task until this file is
replaced by hand.

## 3. Convert task headers

`peal migrate headers [--parked P,...] [--open P,...] [--none P,...]` rewrites every
numbered task file's `key: value` header into YAML frontmatter, in place: space- or
comma-separated `depends` and `needs` become flow lists, a trailing comment is dropped,
a numbered milestone becomes its id. The three flags carry the project's own pool
names — there are no defaults, so no project's vocabulary is built into Peal itself:

- **`--none`**: a pool that maps to no milestone (the project's "unassigned").
- **`--parked`**: a pool that becomes a `parked` milestone (never offered until a
  milestone review or a human moves its tasks out; the project's "later", and any
  recurring, never-offered pool it used for something other than a fixed checklist).
- **`--open`**: a pool that becomes an `open` milestone (claimable by name, never
  offered blind; the project's "process"-style pool).

A pool named in none of the three is reported, not guessed. One line converts a whole
project's own pools, comma-separating more than one name under the same flag:

```sh
peal migrate headers --none unassigned --parked later,any --open process
```

It prints anything it cannot convert (a header line that is not `key: value`, blank or a
comment, an unknown key, an unmapped pool) and leaves that one file entirely untouched;
every other file still converts. Exit 1 if anything was reported, 0 otherwise. A file
already in frontmatter (first line `---`) is left alone, so the command is safe to run
again once the reported files are fixed by hand. It never commits — review the diff
before committing it.

## 4. Convert milestone docs

`peal migrate milestones [--parked P,...] [--open P,...]` (the same pool names as step
3, `--none` does not apply here — there is no milestone to make for it) adds frontmatter
to every numbered milestone doc that has none: `id: mNN` from the file's own digits, the
highest number `current`, the rest `done`, `order` the number; the title stays whatever
the first heading already says. It also creates `<pool>.md` for every `--parked` or
`--open` pool that has no file yet, `state: parked` or `state: open`, an empty body for
the project to fill in. It refuses to make a second `current`, and reports any milestone
id a task uses that has no file (a pool left out of both flags, or a stray one). Safe to
run again; never commits.

```sh
peal migrate milestones --parked later,any --open process
```

## 5. Move project settings into `.peal/config.yml`

Everything a project used to hard-code into its own scripts, prompts and CI now lives as
settings Peal reads, or as files under `.peal/` an extension point appends
([`docs/design.md`, "Configuration"](design.md#configuration)):

| Was | Becomes |
|---|---|
| plan-required paths | `plan.required-paths` |
| paths the reviewer skipped | `review.skip-paths` |
| context documents the planner/reviewer read | `context` |
| the commit gate's build-and-test command(s) | `checks.commit` |
| the close's build-and-test command(s) | `checks.close` |
| extra prose sections a pull request asked for (a player-facing note, screenshots) | `pr.sections`, each `"Title: what to write"` |
| allowed commit-subject areas | `commit.areas` |
| the reviewer's own architecture rules | `.peal/reviewer.md`, appended to its prompt |
| the planner's own rules | `.peal/planner.md`, appended to its prompt |
| what a recurring drift check compared | `.peal/drift.md`, what `/peal:drift` compares |
| a milestone review's own steps (playing the build, a rendered screenshot, a code-health counter) | `.peal/review.md`, what `/peal:milestone-review` runs beyond the generic acceptance-criteria walk |

Project-specific frontmatter fields the old process used move under `task.fields` in the
same file. Nothing here is required: every setting has a default, and a field left out
of `task.fields` is simply not one Peal knows — declare only what the project actually
uses.

## 6. Replace the generic pieces; keep what stays

With settings and rules moved, swap in Peal's commands, subagents, scripts and hooks for
the reference pieces the scope tables in step 1 marked **moves**, and delete those
pieces from the project. Leave everything marked **stays** exactly where it is — an
engine guard, a render or screenshot script, a byte-budget check, `.belfry.yml`'s
content — since Peal never absorbs project-specific tooling, only calls into it through
the extension points now wired up in step 5. A row marked **moves, with an extension
point** is the two working together: Peal's generic half runs the step, the project's
own half (now a `.peal/` file or a `checks.*`/`pr.sections` entry) supplies the rest.

## 7. Point `.belfry.yml` at the launcher

If the project runs under Belfry, `peal init --stage belfry` writes `.belfry.yml`'s
`commands` backend (or `github-issues`, for the issues storage) pointing at `.peal/peal`
([`docs/design.md`, "Peal and Belfry"](design.md#peal-and-belfry)). A `.belfry.yml` that
is not already Peal's is left alone, its expected shape printed, so a hand-edit merges
the two instead of overwriting a working file.

## Checking the result

`peal list` and `peal board` read the same task files and milestone docs the project's
own scripts did; run both once the conversions land and compare their done/free/blocked
state, task by task, against the old process's own listing. `peal check` catches a
malformed milestone file, a task id used twice, and a depends cycle. Commit everything —
converted task files, `.peal/config.yml`, the deleted old tooling, `.belfry.yml` — as one
change; the project's own commit gate and CI are the last check before it merges.
