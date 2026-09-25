---
milestone:
plan: skipped
size: S
depends: []
priority: low
touches: [plugin/lib/, plugin/commands/close.md]
---

# 0069 — The idea queue can be dropped or exported, and the Outcome check accepts quoted comments

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
