# Storage

Where tasks live: task files on the main branch, or GitHub issues. The commands do not
differ; the storage under them does. The interface, and why it is shaped so, is in
[the design](../design.md#storage).

## Settings

| Setting | Means |
|---|---|
| `storage.kind` | `files` (the default) or `issues` |
| `storage.issues.repo` | `owner/name`; empty: the remote's GitHub repository |
| `storage.issues.label` | only issues with this label are tasks; empty: the issues opened by someone with write access |

The issues storage needs `gh`, logged in. `peal init --stage tasks --storage issues
[--label L]` sets it up ([CLI](cli.md#peal-init)).

## Ids

A task file's id is four digits (`0042`), an issue's its number (`42`). Every command
takes either. The commit subject's `[NNNN]` is the id: `[42]` in an issues project. The
branch is `task/NNNN-slug` for files, `issue/N` for issues; the worktree
`{worktrees}/NNNN-slug` or `{worktrees}/issue-N`.

## An issue as a task

| Task field | On the issue |
|---|---|
| title | the issue's title; the slug is its first five words |
| `milestone` | the issue's milestone, by title |
| `depends` | lines `Depends on #3, #7` (with `human` and `milestone` too), read up to the first word that is none of those |
| `part-of` | a line `Part of #3` |
| `needs` | labels `needs: <capability>` |
| `size`, `plan`, `model`, `breaking`, `release-note`, the project's own fields | labels `<field>: <value>` |
| `priority` | labels `priority: urgent`, `priority: high`, `priority: low`; of two the higher counts, none is normal |
| `owner` | the label `owner: human`; none is ai |
| `merge` | the label `merge: auto`; none is the project's default |
| `touches` | labels `touches: <path>`, one per entry |

`origin` has no label: it is for files only. The sections (Intent, Scope, Raw, ...) are
the body's own headings. GitHub's sub-issues are not read as `part-of`, and `peal read`
gives the body without the comments.

## States of an issue

- `done` when closed.
- `awaiting-merge` while an admitted open pull request says `Fixes #N` (or closes,
  resolves, ...).
- `claimed-live` when `issue/N` has a worktree here, or the issue carries the label
  `in progress`.
- `parked` for a local `issue/N` ahead of main without a worktree.
- Then `blocked` and `free` by the same rules as for files ([Tasks](tasks.md#claim-states)).

## Who is admitted

One rule, applied on every read path (`read`, `claim`, `work`, `defer`, the listing):

- With a filter label, only issues carrying it are tasks. An issue edited later than its
  own labelling by someone without write access is refused too, so a stranger cannot slip
  a task's text in after a maintainer's label.
- Without one, only issues opened by someone with write access are tasks.
- Only pull requests from the repository itself, or by someone with write access, mark an
  issue awaiting merge.

A refused issue is refused without quoting any of its text. See
[Security](../security.md).

## Claims on issues

`peal claim N` makes the worktree `{worktrees}/issue-N` on branch `issue/N`, continuing
the remote's `issue/N` if there is one, and adds the label `in progress`. Belfry's
`github-issues` backend claims the same way, so `peal claim N` on an issue Belfry claimed
prints Belfry's worktree. A worktree alone is a claim. The label is no lock: two claims at
the same moment can both add it. The session hooks read the task's size from a copy of its
text the claim keeps in the worktree's git directory.

## Differences of the two

| Operation | Task files | Issues |
|---|---|---|
| `peal close finish` | the file moves to `done/` with its Outcome | the pull request's body says `Fixes #N`; the Outcome is in a file of the close's own |
| `peal retire` | file moved to `done/` with the reason, on main | closed as not planned, the reason a comment |
| `peal create` | a backlog file on main, numbered by push-as-lock | a new issue; frontmatter becomes milestone, labels and reference lines |
| `peal comment` | appended under `## Notes` | a comment |
| `peal milestone-state` | the milestone file rewritten on main | the GitHub milestone closed or opened |
| writes onto main | yes | none, but decisions and version files |
