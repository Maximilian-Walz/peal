---
milestone: m2
plan: skipped
depends: [0014]
part-of: 0014
---

# 0096 — `docs/migrating.md`: the migration procedure

## Intent

Write `docs/migrating.md`, the whole procedure a project with its own task-file process
follows to adopt Peal, once `peal migrate headers` and `peal migrate milestones` exist
(task 0014): which pieces a project keeps, how to invoke the converters with its own
pool names (`--parked`, `--open`, `--none`), and how its checks, context documents, PR
sections and reviewer/planner rules move into `.peal/`.

## Scope

- `docs/migrating.md`: the whole migration procedure, which pieces a project keeps, the
  converters' one-line invocation with a project's own pool names, replacing the old
  template with Peal's, and how checks, context documents, PR sections and
  reviewer/planner rules move into `.peal/`.
- Links to it from `docs/design.md` "Migrating an existing project", `README.md` and
  `plugin/commands/setup.md`.

## Done when

- `docs/migrating.md` exists and every fact in it matches `plugin/lib/migrate.sh`,
  `plugin/lib/config-defaults.yml` and `docs/design.md`.
- `docs/design.md`, `README.md` and `plugin/commands/setup.md` link to it.
- `tools/lint.sh` passes.

## Raw

> - `docs/migrating.md`: the whole procedure, including which pieces a project keeps and
>   how its checks, context documents, PR sections and reviewer rules move into `.peal/`.

(from the origin's `## Scope`)

Split from 0014

## Notes

- The converters take pool names as flags with no defaults; the doc shows the one-line
  invocation for a project's own pools.
- The converters skip `TEMPLATE.md`; the doc tells the human to replace a project's old
  template with Peal's.
- Link it from `docs/design.md` "Migrating an existing project" (the origin corrects that
  section's wording), and possibly from `README.md` and `plugin/commands/setup.md`.
- Size estimate: S.

---

## Outcome

<!-- Written at close, replacing this comment. -->
