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

Built as scoped. `.peal/config.yml` sets `release.changelog: CHANGELOG.md` in its
existing `release:` block. `CHANGELOG.md` starts with `# Changelog`, then one entry
`## v0.2.0 (2026-09-28)` whose body is `peal ship notes v0.2.0` with `## ` turned into
`### `, the transform `_peal_ship_changelog_entry` in `plugin/lib/ship.sh` applies. The
date comes from the annotated v0.2.0 tag (2026-09-28 16:15 +0200, the same day in UTC),
where `bump` would have used `date -u` on the release day, the same day here. The entry
keeps the notes' opening line (`v0.2.0: the first release, 41 features.`), as `bump`
would. `tools/lint.sh` and `tools/test-all.sh` (32 harnesses) pass. The reviewer
confirmed the notes byte for byte and found nothing to act on.

Precondition, and what the next session needs to know: the installed plugin had to know
0107's key, and getting there took three human steps.

1. Main's `plugin.json` still says 0.2.0, and the plugin cache is keyed by version, so a
   `/plugin` update kept the 0.2.0 copy built before 0107. The human deleted the cache
   directory and reinstalled.
2. The recorded root in the git directory (`peal-root`) pinned the launcher and gates to
   0.1.0.
3. Project-scoped 0.1.0 installs, the main checkout's among them, wrote that root back at
   every session start. The human removed the 0.1.0 cache, moved the main checkout's
   install to 0.2.0 and rewrote the root.

Any machine still running a Peal from before 0107 fails on this config with `unknown
setting release.changelog` until its plugin is refreshed. This was reported as friction
(the refresh needs a version bump per merge, or a launcher that prefers the newest root).

Not exercised yet: the next `/peal:release` should insert its entry above v0.2.0, and
the pre-push gate should accept it.
