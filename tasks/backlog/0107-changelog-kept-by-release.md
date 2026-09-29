---
milestone: m2
plan: required
part-of: 0031
---

# 0107 — CHANGELOG.md kept by /peal:release

## Intent

`/peal:release` keeps a CHANGELOG, as a generic feature for every project, not a
Peal-only file: a configuration key (e.g. `release.changelog: CHANGELOG.md`) names the
file, and `peal ship` prepends the release notes to it in the same `chore(release)`
commit. Peal turns it on for itself.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
