---
milestone: m2
plan: skipped
depends: []
priority: high
---

# 0083 — `peal create` takes `--origin` for text Belfry marks untrusted

## Intent

0074's `peal create --owner OWNER --title TITLE` files a task straight from Belfry's
`tasks.commands.create`, but carries no record of where the text came from: an
outsider's issue or comment reads the same as a trusted filing. The reference project
keeps that origin in a filed task's frontmatter (Belfry #211); Belfry's own `create`
does not yet pass the job's untrusted flag through to the command it runs, so there is
nothing for `peal create` to read today. Once Belfry does, add `--origin outsider` (or
whatever Belfry's flag is named) to `peal create`, writing it into the new task's
frontmatter the same way `owner` is.

## Scope

- `plugin/lib/backlog.sh` (`peal_create_filed`): an `--origin` option, written into the
  frontmatter as a field task-check.awk allows (a new `peal` key, or a `task.fields`
  style project field — decide against the field Belfry actually sends).
- `.peal/peal create --owner {owner} --title {title}` in `_peal_init_belfry_text` gains
  `--origin {origin}` (or equivalent), once Belfry's contract documents that
  placeholder.

## Done when

- A harness: `--origin outsider` (or the field Belfry lands on) is written into the
  filed task's frontmatter; without it, the field is absent, as today.

## Raw

0074's plan (human's answer, 2026-09-27): "no `--origin` now; a follow-up idea depending
on Belfry passing the job's untrusted flag."

## Notes

Revised 2026-09-28: priority high: goes into Peal's next patch release (daily-use fixes after m1)

- Blocked on Belfry adding an untrusted-origin flag to the job it runs
  `tasks.commands.create` in and documenting the placeholder its contract passes; no
  Peal task id names that Belfry-side work, so nothing to put in `depends`. Check
  Belfry's own backlog and contract docs before starting.
- 0074's own `## Notes` records the same open question in full.
- Unblocked 2026-09-28: Belfry's contract (docs/contract.md on its main) now documents it.
  `tasks.commands.create` gets `{origin}` as a plain word, `outsider` when the text came
  from outside, else `writer`; no other placeholder is allowed besides `{title}` and
  `{owner}`. The board's `origin` field: `writer`, or `outsider`; missing is `writer`; any
  word other than `writer` is external (quoted as data, never unattended, never
  self-merged). A `commands` project whose create does not name `{origin}` still has its
  filing job run for outsider text, since the task file then carries no mark. So the field
  is `origin` in the frontmatter, `--origin writer` writes nothing (absent as today), and
  `peal board` must carry `origin` through or the mark is inert.

---

## Outcome

Built: `peal create` takes `--origin outsider|writer`, the `{origin}` placeholder Belfry's
contract now passes to `tasks.commands.create`. `outsider` writes `origin: outsider` into
the filed task's frontmatter the way `owner` is written; `writer` or no `--origin` writes
nothing (missing means writer, as the contract reads it); any other word, or the option
twice, is refused before anything is filed. `task-check.awk` allows `origin` (empty or
`outsider`); the files backend's read pipeline (`task-scan.awk` → `task-state.awk` →
`board.awk`) carries it, and `peal board` emits `"origin":"outsider"` only when set, so the
mark reaches Belfry, which treats the task as external. `peal init --stage belfry` writes
`--origin {origin}` on the create line, and init's harness allows `{origin}` beside
`{owner}` and `{title}`. A local `origin` in `task-state.awk`'s split logic became
`splitof`, since `origin` now names an array. `docs/design.md`, `docs/security.md` and both
task templates document the flag, the key and the board field. Harnesses: store-files
(outsider written; writer and none absent; bad word and repeat refused), tasks (board
carries it), hostile (argument fuzz), init.

Decided: the field is the frontmatter key `origin`, not a project field, because the
contract's board field has that name and meaning. It is carried by the files backend only.
The issues backend accepts the option but does not turn it into the `origin: outsider`
label yet. Belfry has no create command for `github-issues`, so that path cannot be reached
through Belfry today. The idea `issues-backend-origin-dropped` is filed for it.

Left: this repository's own `.belfry.yml` (its create line came from 0082, merged in here)
stays without `--origin {origin}`. `.peal/peal` runs the installed release, which would
refuse the option. The idea `own-belfry-yml-origin` is filed to add it once a release
ships 0083.

Next session: the task was blocked until Belfry's contract documented `{origin}`; it now
does (see Notes). The implementer ran the touched harnesses and lint, all green. The full
`tools/test-all.sh` was not run to the end here; CI runs it.
