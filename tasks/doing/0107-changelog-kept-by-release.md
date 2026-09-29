---
milestone: m2
plan: required
part-of: 0031
size: M
model: opus
touches: [plugin/lib/ship.sh, plugin/lib/ship.test.sh, plugin/lib/githooks.sh, plugin/lib/githooks.test.sh, plugin/lib/hostile.test.sh, plugin/lib/config-defaults.yml, plugin/lib/config.test.sh, plugin/lib/store-issues.sh, plugin/commands/release.md, plugin/bin/peal, docs/design.md, docs/security.md, tools/ci-changes*]
---

# 0107 — CHANGELOG.md kept by /peal:release

## Intent

`/peal:release` keeps a CHANGELOG, as a generic feature for every project, not a
Peal-only file: a configuration key (e.g. `release.changelog: CHANGELOG.md`) names the
file, and `peal ship` prepends the release notes to it in the same `chore(release)`
commit. Peal turns it on for itself.

## Scope

- A generic, optional `release.changelog` key (a repository path, empty = off, checked
  with the same path rules as `release.version-files`).
- `peal ship bump` inserts the release's entry into that file in the same
  `chore(release): <tag>` commit as the version files; `peal ship tag` refuses without
  the entry; the pre-push gate accepts exactly that shape.
- Not here: turning it on for Peal itself and the v0.2.0 backfill (a follow-up task,
  filed at close, depending on 0107, run after the installed plugin is refreshed);
  `/peal:next` suggesting the key; a `peal ship changelog` command.

## Done when

- `ship.test.sh`: bump with a changelog makes one `chore(release)` commit with the
  version files and the entry under `# Changelog`; a rerun says "already at"; a second
  release goes above the first leaving the rest byte for byte; a missing file is
  created; a title-less file gets the entry on top; changelog without version files
  still commits; `ship tag` refuses without `## <tag>` and tags with it; the
  protected-main PR path carries the changelog.
- `githooks.test.sh`: the gate accepts the real bump and a hand-made commit of the same
  shape; refuses old lines changed, another tag's block, a duplicate `## <tag>`, a path
  other than the key's, and an added changelog while the key is off.
- `hostile.test.sh`: hostile `release.changelog` values refused by bump and tag, nothing
  written.
- `config.test.sh` lists the default; `ci-changes.test.sh`: a `CHANGELOG.md`-only diff
  (alone or with the version-only `plugin.json`) gives `harnesses=false`.
- `tools/lint.sh` and `tools/test-all.sh` pass.

## Raw

> - `CHANGELOG.md`, kept by `/peal:release` from then on.

Split from 0031

## Notes

- Agreed in 0031's planning: generic feature (not a hand-kept file); 0031 creates no
  CHANGELOG.
- Open: backfill from the existing tags (e.g. `peal ship notes` per tag) or start empty
  at the next release; the planner's default was to backfill.
- Code in `plugin/lib/ship.sh`, `plugin/commands/release.md`, `config-defaults.yml`.
- Size: S or M.
- Human's answers (planning, 2026-09-29): turning it on for Peal and the backfill move
  to a follow-up task depending on 0107 (after a plugin refresh), filed at close;
  backfill v0.2.0 as one section there; the gate checks the entry's shape only (both
  storages), the limit written into `docs/security.md`; heading `## v0.3.0 (2026-10-02)`
  (UTC date of the bump). Defaults agreed: items merged between bump and tag are
  accepted and documented; pre-releases get sections; `ship tag` refuses without a
  section; `/peal:next` untouched; implementer on opus.

## Plan

**Setting.** `release.changelog: ""` in `plugin/lib/config-defaults.yml` (empty = off,
else a path). A small `peal_changelog_file` in `ship.sh`, shared with the gate, checks
it with `peal_version_files`' path rules (relative, inside the repository, no `..`, `.`,
`//`, leading `-`, whitespace or control characters).

**Entry.** `_peal_ship_changelog_entry TAG ITEMS` reuses `_peal_ship_notes` with headings
one level down: `## <tag> (<UTC date>)`, blank, the notes' first line, `### Features`
etc. Inserted after a leading `# ...` title line and its blank line, else at the very
top; a file missing on main is created as `# Changelog` plus the entry.

**`peal ship bump`.** Runs when `release.version-files` or `release.changelog` is set
("nothing to bump" names both). `_peal_ship_bump_build` gets the items
(`_peal_ship_range "$tag"`, `_peal_ship_items`) and adds the changelog blob through
`peal_write_tree`. Idempotent: a `## <tag>` line in main's changelog plus version files
at the version is status 4 "already at" (0080's PR REUSE keeps working, subject
unchanged). The report lists the changelog.

**`peal ship tag`.** Refuses when the key is set and main's file has no `## <tag>`
section: "peal ship bump <tag> first".

**Pre-push gate** (`_peal_pre_push_release`, `githooks.sh`, and the shape list near
line 159). For the one path equal to `release.changelog`: M 100644→100644 where the new
blob is the parent's with one block inserted at the entry position, the block's first
line `## <subject's tag>`, the parent having no such heading; or A 100644 starting
`# Changelog` followed by that block. Shape only, no content rebuild (the limit goes
into `docs/security.md`).

**CI.** `tools/ci-changes.sh` counts `CHANGELOG.md` as read by no harness, so a bump PR
does not run the harnesses (and `ship bump`'s 540 s budget holds).

**Docs.** `plugin/commands/release.md` (step 3.1 runs when either key is set; the report
names the changelog; the bump→tag gap), `plugin/bin/peal` help, `docs/design.md` (config
block, gate shapes, Releases), `docs/security.md` (gate shapes and the shape-only
limit), the warning in `plugin/lib/store-issues.sh` (the changelog is also a write onto
main).

**At close:** file the follow-up "Peal keeps its CHANGELOG.md" (depends 0107; after the
installed plugin is refreshed from a main with 0107: `release.changelog: CHANGELOG.md` in
`.peal/config.yml` and the v0.2.0 backfill as one section).

**Verification:** the Done when list.

Ranges relied on: tasks/backlog/0031-readme-docs-newcomers.md:46-52,
tasks/backlog/0106-docs-guides.md:26-31, docs/design.md:569-579, docs/design.md:689-699,
docs/design.md:897-961, docs/security.md:97-106, plugin/lib/ship.sh:1-134,
plugin/lib/ship.sh:176-186, plugin/lib/ship.sh:225-270, plugin/lib/ship.sh:386-427,
plugin/lib/ship.sh:455-569, plugin/lib/ship.sh:705-718, plugin/lib/githooks.sh:159-161,
plugin/lib/githooks.sh:222-245, plugin/lib/githooks.sh:308-348,
plugin/lib/githooks.test.sh:274-318, plugin/lib/ship.test.sh:202-304,
plugin/lib/hostile.test.sh:650-668, plugin/lib/config.test.sh:36-47,
plugin/lib/config-defaults.yml:1-3, plugin/lib/config-defaults.yml:39-46,
plugin/lib/store-issues.sh:33-45, plugin/commands/release.md:9-14,
plugin/commands/release.md:49-67, plugin/commands/release.md:83-87,
plugin/bin/peal:272-296, .peal/config.yml:14-15, .peal/config.yml:51-57,
tools/ci-changes.sh:1-37.

---

## Outcome

<!-- Written at close, replacing this comment. -->
