# Tasks and milestones

A task is a Markdown file `tasks/<dir>/NNNN-slug.md`, or, under the issues storage, a
GitHub issue ([Storage](storage.md)). The reasons are in
[the design](../design.md#task-files).

## Layout and naming

- The number is four digits, the slug two to five kebab-case words (`a-z0-9`).
- The state is the directory (`backlog`, `doing`, `done`) together with refs; there is no
  status field.
- The title is the first heading, `# NNNN — Title`.
- A malformed task id is refused where it enters (`refused: ...`, status 2). A file or
  branch whose slug is not kebab-case is skipped with a warning; `peal check` names it.
- Free text (titles, reasons, bodies) is passed only as data.

## Frontmatter

The header is real YAML frontmatter. Peal reads and writes a subset: scalars, and lists
of scalars in flow (`[a, b]`) or block style.

<!-- docs-check: frontmatter -->
```markdown
---
milestone: m08
plan: required
size: M
depends: [0271, human]
part-of: 0190
needs: [display, gpu]
model: opus
---
```

### Fields

Peal's fields, all optional.

| Field | Meaning |
|---|---|
| `milestone` | a milestone id; absent means unassigned |
| `plan` | `required` or `skipped`; `/peal:idea` sets it from `plan.required-paths` and the declared size |
| `size` | `S`, `M` or `L`, the tool-call tiers of `sizes`; empty until the planner sizes it |
| `depends` | a list of task ids that must be done first, plus the keywords `milestone` and `human`; see below |
| `part-of` | the task this one was split from; filed by `/peal:split` only |
| `needs` | capabilities a worker must have, Belfry's vocabulary; carried to the board |
| `model` | the implementer's model when not the default; written when the human agrees the plan |
| `breaking` | `true` when the task breaks something its users rely on: the next release is a major one |
| `release-note` | `none` leaves the task out of the release notes and the bump |
| `priority` | `urgent`, `high`, `normal` or `low`; absent means normal; orders the offer within a milestone, never across; `/peal:idea` sets it only when the idea says so plainly, `/peal:revise` changes it |
| `owner` | `ai` or `human`; absent means ai; a human task is never offered and `/peal:work` refuses it, while `peal claim` still makes its worktree |
| `origin` | `outsider`, or absent for the project's own text (`writer`); written only by `peal create --origin outsider` and `peal comment --origin outsider`; files only |
| `merge` | `auto`, or absent for the project's default; the human agreed the pull request may merge itself once its checks are green; `/peal:work` writes it only on the human's word, `/peal:revise` can remove it, a close ending `merge-auto: withdraw` removes it |
| `touches` | a list of paths, directories or globs (`*`, `?`, `[...]` within a directory, `**` across), relative to the repository's root, none absolute or holding a comma, and on issues none over GitHub's 50 label characters; written by the planner, a hint only |
| `after_deploy` | a list of pull requests that must be deployed before the task can be worked, each `N`, `#N`, `repo#N` or `owner/repo#N` (a scalar is a one-item list); write it when the task depends on a control-plane change that is merged but may not be deployed yet; Peal only passes it to the board, all-digit entries as numbers and the rest as strings, and does nothing else with it; `/peal:idea` sets it only when the idea says so, `/peal:revise` may add it |

- `depends` keywords: `milestone` is every other task of this task's milestone, written
  only on a milestone's review task; `human` never resolves by itself. A `depends` on a
  task with `owner: human` waits until it is done, like any other. Depending on a task
  that was split waits for it and all its pieces.
- A project's own fields are declared under `task.fields` in `.peal/config.yml`
  ([Configuration](configuration.md)). Peal carries them through every command and
  refuses undeclared keys when filing.

### Depends cycles

A cycle is refused where a task text is filed, revised or deferred: exit 1 with
`refused: depends cycle 0042 → 0043 → 0042` (`#42 → #43 → #42` for issues; a task still to
be filed shows as `NNNN` or `PART1`). A task depending on its own milestone is no cycle.
A cycle made by hand is shown instead: `peal list` and `peal board` show its tasks as
blocked with the cycle, and `peal check` names it.

## Sections

The body after the title:

```markdown
## Intent
## Scope
## Done when
## Raw
## Notes
## Plan

---

## Outcome
```

- `Raw` is the human's words and never rewritten.
- `Plan` follows `Notes` for a task with `plan: required`, once the human agrees the
  plan; until it holds something, the plan is not agreed.
- `Outcome` is written at close and must not be empty or a placeholder.

## Claim states

Derived from refs and the main branch on the remote, never from the calling worktree.

| State | Means |
|---|---|
| `free` | no branch; claimable |
| `claimed-live` | the branch has a worktree, or exists only on the remote |
| `parked` | a local branch ahead of main without a worktree; `peal claim` resumes it |
| `awaiting-merge` | the branch tip holds the task under `done/`; waits for the human's merge |
| `blocked` | a `depends` entry is not done yet, or the task lies on a depends cycle |
| `done` | the file is under `done/` on main; outranks every other state |

## Milestone files

A milestone is one Markdown file in the `milestones` directory: its data as frontmatter,
its prose (goal, acceptance criteria, the review) as the body.

<!-- docs-check: frontmatter -->
```markdown
---
id: m08
title: Combat
state: current
order: 8
due: 2026-11-01
---
```

### Milestone fields

| Field | Meaning |
|---|---|
| `id` | defaults to the file name without `.md` |
| `title` | defaults to the first heading |
| `state` | `open`, `current`, `done` or `parked` |
| `order` | the order milestones follow |
| `due` | an optional due date |
| `reason` | a parked milestone's reason, free text; `'until #12, other/repo#43'` names the issues it waits for |

More than one `current` milestone is refused. The state is written, never inferred.
On GitHub the reason is the rest of the description's first line after "Parked:".

### Milestone states

| State | Offered by a bare `/peal:work` | Claimable by number |
|---|---|---|
| `current` | yes, first | yes |
| no milestone | yes, after `current` | yes |
| `open` | no; `/peal:work <milestone-id>` offers it | yes |
| `parked` | no | no; a milestone review or the human moves the task out first |
| `done` | no | no (its tasks are done) |

`peal milestone-state` changes a state ([CLI](cli.md#peal-milestone-state)). Milestone
files are read-only during an ordinary task; `peal close begin` notes a branch that
touches one. Every milestone has a review task, `depends: [milestone]`, whose session
runs `/peal:milestone-review`.
