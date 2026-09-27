---
milestone:
plan: skipped
depends: []
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

- Blocked on Belfry adding an untrusted-origin flag to the job it runs
  `tasks.commands.create` in and documenting the placeholder its contract passes; no
  Peal task id names that Belfry-side work, so nothing to put in `depends`. Check
  Belfry's own backlog and contract docs before starting.
- 0074's own `## Notes` records the same open question in full.

---

## Outcome

<!-- Written at close, replacing this comment: what was built, what was decided, what was
     found and left (each a new task), and what the next session needs to know. -->
