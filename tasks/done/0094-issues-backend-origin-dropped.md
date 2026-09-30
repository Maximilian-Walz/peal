---
milestone: m3
plan: skipped
size:
depends: []
priority: high
---

# 0094 — `peal create --origin` silently drops on the issues backend

## Intent

0083 added `peal create --owner OWNER --title TITLE --origin outsider|writer`, writing
`origin: outsider` into a filed task's frontmatter. `task-check.awk` now accepts
`origin` as a Peal field on every backend (it is the same check `peal_store_create`
runs for both), but only the files backend actually carries the value anywhere: the
issues backend's frontmatter <-> label conversion (`plugin/lib/store-issues.sh`
`_peal_issues_from_text`, `plugin/lib/issues-text.awk`) never learned about `origin`,
so a task filed with `--origin outsider` on an issues-backend project is accepted,
files clean, and then silently loses the mark — no label is written, and reading the
issue back shows no `origin` field at all. `docs/design.md`'s field table already
documents this as intentional ("files only (the issues backend has no label for it)"),
and Belfry's own contract never names `tasks.commands.create` for the `github-issues`
backend, so this is unreachable through Belfry today; it is only reachable by a human
or script calling `peal create --origin` directly against an issues-backend project.

## Scope

Pick one:
- Wire `origin` into `_peal_issues_from_text` and `issues-text.awk` (a label
  `origin: outsider`, read back the same way `owner: human` is), so the field round-trips
  on both backends; or
- Have `peal_create_filed` refuse `--origin outsider` outright on the issues backend
  (clear error) rather than accept it and drop it silently.

## Done when

- A harness on the issues backend: `peal create --owner ai --title T --origin outsider`
  either carries `origin: outsider` through `peal read` and the board, or is refused
  with a clear message — never silently absent.

## Raw

From 0083's implementer: while wiring `--origin` through the files backend (task-scan.awk
-> task-state.awk -> board.awk), I found the issues backend shares the same
`task-check.awk` validation but has no matching label conversion, so the flag is silently
a no-op there. Filed as a follow-up rather than fixed in 0083, whose own scope and the
human's unblocking note (0083's Notes) only ever mention "the frontmatter" (files), and
Belfry's contract has no `create` command for `github-issues` at all, so no live path
reaches this today.

## Notes

---

## Outcome

Refused rather than carried (the second option in Scope). `peal_create_filed`
(`plugin/lib/backlog.sh`) now reads `storage.kind`. When the value is `issues` and
`--origin outsider` is given, it exits with status 2 and files nothing. The message is
"create: --origin outsider is not carried by the issues storage (origin is files only);
nothing filed". `--origin writer`, or no `--origin` at all, still files as before.

Why refuse: `docs/design.md` and `docs/reference/tasks.md` already record `origin` as
files only, on purpose. Carrying the mark would have needed a new label and more round-trip
code, for a path that Belfry's contract does not reach on `github-issues`. Refusing makes
the code enforce what the docs already said, and nothing is dropped silently any more.

Evidence: two new checks in `plugin/lib/store-issues.test.sh`. The first shows the
refusal with its message, the second shows `--origin writer` still filing. That harness
passes 642/0. `docs/reference/cli.md` now describes the refusal under `peal create`.

Found and left: `peal comment --origin outsider` probably drops the mark the same way on
the issues storage. It was not checked here, so it is queued as an idea
(comment-origin-issues-storage).

The reviewer had no findings.
