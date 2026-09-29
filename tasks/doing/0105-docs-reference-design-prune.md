---
milestone: m2
plan: required
depends: [0031]
part-of: 0031
size: M
touches: [docs/reference/**, docs/design.md, docs/migrating.md, docs/getting-started.md, CONTRIBUTING.md, README.md, tools/docs.test.sh, .peal/config.yml, .belfry.yml]
---

# 0105 — docs/reference/ and design.md pruned to the why

## Intent

A reader looking something up finds it in `docs/reference/`: the commands, the `peal`
CLI, the configuration keys, the task frontmatter and the storage settings, complete and
terse, with a short "Words" list so the docs use the same words as the commands.
`docs/design.md` keeps the why and loses what moved to the reference. The docs check
that 0031 builds (`tools/docs.test.sh`) grows completeness checks: every key in
`plugin/lib/config-defaults.yml` is in the config reference and back, every subcommand in
`peal --help` is in the CLI reference, every `plugin/commands/*.md` is in the commands
reference.

## Scope

- `docs/reference/`: `README.md` (index, then `## Words`), `commands.md`, `cli.md`,
  `configuration.md`, `tasks.md` (task and milestone frontmatter), `storage.md`.
- `docs/design.md` pruned to the why, every `##`/`###` heading kept, linking the
  reference.
- Links only: `docs/migrating.md`, `CONTRIBUTING.md` (line 3 is now false),
  `docs/getting-started.md`, `README.md`.
- `.peal/config.yml` `context` gains `docs/reference/cli.md`,
  `docs/reference/configuration.md`, `docs/reference/tasks.md`; `.belfry.yml` `docs:`
  gains "Reference: docs/reference/".
- `tools/docs.test.sh`: completeness checks (config, CLI, commands, frontmatter fields),
  the `frontmatter` marker, negative cases.
- Not in scope: `plugin/` (stale design.md pointers there are listed in the Outcome and
  one idea is filed), backlog tasks citing design.md ranges (named in the Outcome).

## Done when

- `bash tools/docs.test.sh` passes and proves, each with a negative case that fails:
  - every key of `plugin/lib/config-defaults.yml` has a row in
    `docs/reference/configuration.md`, and back;
  - every Peal field of `plugin/lib/task-check.awk` has a row in
    `docs/reference/tasks.md`, and back;
  - every subcommand in `peal --help`, grouped second words included, has a heading in
    `docs/reference/cli.md`;
  - every `plugin/commands/*.md` has a heading in `docs/reference/commands.md`.
- The reference's marked blocks load or check (`config`, `frontmatter`); every
  `peal <sub>`, `/peal:<cmd>` and link in `docs/reference/` and the pruned design.md is
  validated by the existing checks.
- `docs/design.md` holds no table, flag list, output shape or settings block the
  reference holds (except the scope tables, the Belfry table and the storage interface
  table); every former heading still exists.
- `docs/reference/README.md` has a Words list, and the new pages use its words.
- `tools/test-all.sh` and `tools/lint.sh` pass.

## Raw

> - `docs/reference/`: commands, the `peal` CLI, configuration keys, task frontmatter,
>   storage settings; complete and terse, the place to look things up.
> - `docs/design.md`: the why, kept, pruned of what moved to the reference.
> - One voice: short sentences, the same words for the same things as the commands use.

Split from 0031

## Notes

- Agreed in 0031's planning: no word-level enforcement of banned synonyms; a "Words"
  list in the reference instead.
- design.md's examples are the hard part of "every example is exercised": the agreed
  level is the middle one (marked blocks run or load through `<!-- docs-check: run -->`
  / `<!-- docs-check: config -->`, everything else name- and link-validated).
- Size: M, maybe L (design.md is about 1180 lines).
- Planning answers (human, 0105): add the reference to `.peal/config.yml` `context` and
  `.belfry.yml` `docs:`; milestone frontmatter goes in `tasks.md`, the index is
  `docs/reference/README.md`, `storage.md` covers the issue mapping, states, ids and the
  admission rule (the shell-function interface table stays in design); the commit-subject
  grammar goes to the reference, the pre-push rules and session-hook behaviour stay in
  design, `cli.md` lists `peal hook …` tersely; the CLI check covers grouped second
  words, the fields check and the `frontmatter` marker are in; `plugin/` and backlog
  tasks are left untouched, the reference follows the code where design disagrees, and
  all of it is listed in the Outcome with one idea filed to repoint `plugin/`'s
  design.md pointers; Words list of 15-25 one-line terms spelling out the collisions,
  no CLI renames, "pull request" only in text this task rewrites; the `.belfry.yml`
  example stays in design unchecked, "Building Peal" stays; whole task, not split.

## Plan

Approach:
1. Write the reference pages from design.md, `peal --help` (`plugin/bin/peal:69-296`),
   the command files' frontmatter and `config-defaults.yml`; the code wins where
   design disagrees (e.g. design.md:537-579 vs `config-defaults.yml:4-49`).
   - `README.md`: index, then `## Words` (origin, release, pull request/PR, idea/task,
     stage/feature collisions spelled out).
   - `commands.md`: one `` ## `/peal:<cmd>` `` per command (12), argument hint and what
     it does; from design.md:156-192, 396-452, 499-509, 897-961, 1026-1070.
   - `cli.md`: one `` ## `peal <sub>` `` per first word of `--help`, sub-entries for
     grouped ones (close, ship, decision, hook, hooks, frontmatter, migrate, init);
     output shapes, exit statuses, `PEAL_*` env vars, `peal.mainWrites` /
     `peal.projectHooks`, the commit-subject grammar (design.md:700-713); from
     design.md:79-106, 337-369, 402-452, 511-521, 616-633, 714-719, 852-889, 904-957,
     1003-1024, 1072-1115. Write `peal --version`, never `peal version`.
   - `configuration.md`: `.peal/` files table (525-533), one row per dotted key
     (`` | `storage.issues.label` | default | meaning | ``), conventions without a
     setting (581-584), the `worktree-setup` example (586-596) marked
     `<!-- docs-check: config -->`.
   - `tasks.md`: layout and naming, frontmatter example (marked `frontmatter`), fields
     table (245-296), sections (316-320), claim states (322-333), depends cycles
     (298-305), milestone files and fields (463-491).
   - `storage.md`: `storage.kind`, `storage.issues.*`, ids, an issue as a task
     (756-795), the admission rule, claims on issues (797-805).
2. Prune design.md, keeping every heading (anchors used by `migrating.md`), each
   section its why plus a "See reference/…" link. Kept whole: Principles, Belfry table
   and principle, scope tables, storage interface table, Distribution's launcher
   resolution, main writes, git gates (pre-push rules 689-699), `.belfry.yml` example
   (58-77), Building Peal (1147-1175). Migrating shrinks to a paragraph plus link.
   Target about 450-550 lines.
3. Repoint links: `docs/migrating.md:98` → `reference/configuration.md`,
   `CONTRIBUTING.md:3`, one link in README's Start section and at the end of
   getting-started; `.peal/config.yml` `context` and `.belfry.yml` `docs:`.
4. `tools/docs.test.sh`, in its style (`check`/`has`, `mutant`):
   (a) dotted keys from `config-defaults.yml` by indent vs first-column code spans of
   `configuration.md`'s table, both ways; (b) every first word of `--help` (from
   `$known`) and grouped second word (synopsis column only, `substr($0,1,32)`) has a
   heading in `cli.md`; (c) every `plugin/commands/*.md` has a heading in
   `commands.md`; (d) fields of `task-check.awk:52-53` vs `tasks.md`'s field rows, both
   ways; (e) `<!-- docs-check: frontmatter -->` writes the block to a file and runs
   `peal frontmatter check`; the used-marker check (285-286) gains `frontmatter` and
   its glob gains `docs/reference/*.md`. Negative cases through `mutant` for each.

Verification: `bash tools/docs.test.sh`; `tools/test-all.sh tools/docs.test.sh
plugin/lib/frontmatter.test.sh`; `tools/lint.sh`; `grep -c '' docs/design.md` before and
after (in the Outcome); `grep -n '^| `' docs/design.md` shows only design tables;
`PEAL_ROOT=$PWD/plugin plugin/bin/peal --help` diffed by eye against `cli.md` once.

Outcome must list: design/code disagreements found; stale design.md pointers in
`plugin/` (`config-defaults.yml:1`, `doctor.sh:2`, `store.sh:2`, `close.sh:2`,
`ship.sh:2`, `review.sh:2`, `next.sh:2`, `peal:98`, `commands/next.md:56,86`,
`frontmatter.test.sh:14`, dangling `common.sh:17`, `githooks.sh:2`) with one idea filed;
backlog tasks citing design.md ranges (0043, 0044, 0055, 0056, 0060, 0064, 0067, 0068);
this repository's `.belfry.yml:12` `create:` lacking `--origin {origin}`.

Ranges: tasks/done/0031-readme-docs-newcomers.md:54-153, tasks/backlog/0106-docs-guides.md:1-32,
docs/design.md:1-1176, docs/migrating.md:1-146, README.md:1-69, CONTRIBUTING.md:1-11,
CONTRIBUTING.md:47-59, docs/getting-started.md:1-112, tools/docs.test.sh:1-315,
tools/test-all.sh:16-21, tools/ci-changes.sh:24-35, plugin/bin/peal:69-296,
plugin/lib/config-defaults.yml:1-49, plugin/lib/task-check.awk:51-58,
plugin/lib/frontmatter.test.sh:7-39, .peal/config.yml:5-15, .belfry.yml:12,
.belfry.yml:37-43.

Touches: see frontmatter.

---

## Outcome

<!-- Written at close, replacing this comment. -->
