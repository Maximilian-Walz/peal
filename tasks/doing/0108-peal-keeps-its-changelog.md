---
milestone: m2
plan: skipped
size: S
depends: [0107]
touches: [.peal/config.yml, CHANGELOG.md]
---

# 0108 — Peal keeps its CHANGELOG.md

## Intent

Peal turns on the generic `release.changelog` of 0107 for itself: from the next
release on, `/peal:release` writes each release's entry into `CHANGELOG.md` in the same
`chore(release)` commit as the version bump, and the file starts with the v0.2.0
release backfilled as one entry.

## Scope

- `release.changelog: CHANGELOG.md` in `.peal/config.yml`.
- `CHANGELOG.md` created with `# Changelog`, a blank line, then one entry for v0.2.0 in
  the shape `peal ship bump` writes (`## v0.2.0 (<its tag's UTC date>)`, a blank line,
  `peal ship notes v0.2.0` with its headings one level down).
- Run only after the installed plugin is refreshed from a main that has 0107: the
  process runs the installed plugin, whose config loader must know the key and whose
  pre-push gate must accept the changelog.

## Done when

- `peal config release.changelog` prints `CHANGELOG.md`.
- `CHANGELOG.md` holds the v0.2.0 entry under `# Changelog`, its text `peal ship notes
  v0.2.0` with `### ` section headings.
- `tools/lint.sh` and `tools/test-all.sh` pass.

## Raw

> - `CHANGELOG.md`, kept by `/peal:release` from then on.

Split from 0031, through 0107.

## Notes

- Agreed in 0107's planning (2026-09-29): the backfill is v0.2.0 as one section; the
  heading carries the UTC date, e.g. `## v0.3.0 (2026-10-02)`.
- `tools/ci-changes.sh` already counts `CHANGELOG.md` as read by no harness (0107).

---

## Outcome

<!-- Written at close, replacing this comment. -->
