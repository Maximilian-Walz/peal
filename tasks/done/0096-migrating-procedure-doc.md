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

Built `docs/migrating.md`, the procedure a project with its own task-file process
follows to adopt Peal, in seven steps: decide what moves and what stays (the scope
tables), install the plugin, convert task headers (`peal migrate headers --none ...
--parked ... --open ...`), convert milestone docs (`peal migrate milestones --parked ...
--open ...`; `--none` is not accepted there), move settings into `.peal/config.yml` (a
"was → becomes" table for plan paths, review skip paths, context documents,
`checks.commit`/`checks.close`, `pr.sections`, commit areas, and the
`.peal/reviewer.md`/`planner.md`/`drift.md`/`review.md` extension points), replace the
generic pieces while keeping what stays, and point `.belfry.yml` at the launcher; then a
"Checking the result" section (`peal list`, `board`, `check` against the old process's
own listing). Step 2 tells the human to replace the old `TEMPLATE.md`, which the
converters skip and the `tasks` setup stage keeps, with Peal's `plugin/templates/task.md`.

Linked from `docs/design.md` "Migrating an existing project", `README.md`'s Getting
Started paragraph and `plugin/commands/setup.md`'s existing-tasks-directory branch.

The facts in the doc were checked against `plugin/lib/migrate.sh`,
`plugin/lib/config-defaults.yml`, `plugin/lib/init.sh` and `docs/design.md`. The review
found two step references in step 1 still numbered after design.md's six-step list;
fixed on the branch. `## Scope` and `## Done when` were empty (split-off task, plan
skipped) and were filled in at close from what was built. `origin/main` (task 0030,
`/peal:next`) was merged in before the review; it touched README.md and design.md and
merged cleanly.

For the next session: the reference project's migration is its own task, run once Peal
is ready; this doc is what it follows.
