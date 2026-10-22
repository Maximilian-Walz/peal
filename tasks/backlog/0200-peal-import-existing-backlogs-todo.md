---
plan: required
size: M
depends: []
touches: [plugin/lib/import.sh, plugin/bin/peal, plugin/commands/setup.md, docs/guides/setting-up.md, docs/adopting.md]
milestone: m8
---

# 0200 — peal import: existing backlogs (TODO.md, GitHub issues, CSV) into task files

## Intent

`docs/migrating.md` covers a project that already runs the reference process, which is one project in the world. The common cases are a `TODO.md` checklist, a `tasks/*.md` folder without headers, a GitHub Projects board, or a Linear or Jira export. `/peal:setup` already surveys TODO lists and marks (`todo-marks 2`) and proposes one or two first tasks; the natural extension is `peal import` with three sources: a Markdown checklist (one task per unchecked item, the item as `## Raw`), issues into files (a project leaving GitHub issues for files, or the reverse), and CSV or JSON with `title,body`. `/peal:setup` then offers "14 open items in TODO.md: file them as tasks?" as a multi-select instead of two. When this is done adoption does not start from an empty backlog.

## Scope

- `peal import --from FILE|issues` with the three sources; builds on `create`'s batch filing and its task separator; replaces the hand-written `peal create` loop in `setup.md` step 5.
- Everything imported is the importing human's own text, but text from a tracker export is data: pass it through the same checks as `create`, and files from issues keep `origin` rules (issues by strangers are not writers' text).

## Done when

- A test per source files the expected tasks and a second run files none again (idempotent by the source's id kept in `## Notes`).
- `/peal:setup` offers the import.

## Raw

> yes, go ahead with all of it and file those proposals.

## Notes

- Usability review P6. The m2 "Adoption" milestone's migration criterion stops short of it.
- Security: touches "hostile prose is read, never run": imported text is data; an imported issue by a stranger gets `origin: outsider`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
