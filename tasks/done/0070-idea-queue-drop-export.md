---
milestone:
plan: skipped
size: S
depends: []
priority: low
touches: [plugin/lib/, plugin/commands/close.md]
---

# 0070 — The idea queue can be dropped or exported, and the Outcome check accepts quoted comments

## Intent

A task branch's queued ideas can only be filed by `close finish`. When filing is not
possible, the session has no way out but hand-editing the queue file in the git
directory. When this is done, `peal ideas --export` prints the queue as Markdown and
`peal ideas --drop <n>|--all` removes entries, each after saying what it removes; and the
placeholder check no longer trips on an idea's `<!-- -->` placeholder quoted, indented, in
the Outcome.

## Scope

- `peal ideas --export` and `--drop <n>|--all`, on both storages.
- The Outcome placeholder check ignores indented (quoted) blocks.

## Done when

- Harnesses cover export, drop of one and of all, and an Outcome that quotes an idea with a
  placeholder passing the check.

## Raw

Friction from a session (0061's gap): `close finish` could not file queued ideas onto a
protected main; the workaround was copying the queue out by hand and indenting the ideas
into the Outcome, where their placeholder tripped the placeholder check. 0061 fixes the
filing itself; this keeps the manual way out for when filing fails for another reason.

## Notes


---

## Outcome

Built as scoped, with no plan (size S, `plan: skipped`).

- `peal ideas --export` (`plugin/lib/ideas.sh`) prints the queue as Markdown: each idea's
  text byte-for-byte, the internal `-----IDEA slug-----` markers removed, one blank line
  between entries. An empty queue prints nothing, like the plain listing.
- `peal ideas --drop N|--all` removes entries. `N` is the idea's 1-based position in the
  plain `peal ideas` listing, the only stable handle before filing. Each removal prints
  `dropped SLUG — "Title"`, shaped like `peal idea`'s `queued ...` line. A non-number, 0
  or a position past the end is refused with status 2; an empty queue says
  `no queued ideas`, like `--flush`. The queue lives in the worktree's git directory, so
  both storages behave alike; harnesses prove it on each.
- `peal_text_outcome_placeholder` (`plugin/lib/task-text.sh`) skips lines with leading
  whitespace before looking for an HTML comment. An idea quoted indented into an Outcome, its own
  placeholder included, no longer trips the check. The template's placeholder is not
  indented, so an unwritten Outcome is still caught. All four callers (close begin,
  finish, `peal check`, files storage's finish) share this helper.
- `peal close begin`'s queued-ideas NOTE, `plugin/commands/close.md` and the CLI help now
  name `--export` and `--drop`, and describe the indent-to-quote way out when filing at
  finish fails.
- `plugin/bin/peal` is outside the frontmatter's `touches`, for the help text only.

Tests: `store-files.test.sh` (export empty and populated, drop refusals, drop one, drop
all), `store-issues.test.sh` (export and drop on an issue's branch), `close.test.sh`
(an Outcome quoting an indented idea with its placeholder passes `peal check`). All of
them, `hostile.test.sh` and `tools/lint.sh` are green.

Found and left: `peal close begin` hangs on its fetch of the main branch when SSH cannot
authenticate (no BatchMode, no timeout). This session hit it in a sandbox and got past
it with `GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5'`. It is reported as
friction to this project's idea box.

The review found nothing.
