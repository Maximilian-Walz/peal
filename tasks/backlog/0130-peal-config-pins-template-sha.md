---
milestone: m3
plan: skipped
depends: [0126]
touches: [.peal/config.yml]
---

# 0130 — Peal's config lists the template under release.commit-files

## Intent

Task 0126 adds `release.commit-files` and `peal ship pin`, which set the template's Get
Peal SHA after the tag. Peal's own `.peal/config.yml` cannot list the template on 0126's
branch, because the installed plugin (from main) refuses the setting it does not know
yet. Once 0126 has merged and the installed plugin is refreshed, add that entry and its
commented default, so Peal's own releases pin the SHA without a hand edit.

## Scope

## Done when

## Raw

> Peal's own .peal/config.yml lists the template under release.commit-files, so its releases pin the Get Peal SHA. Found in 0126: the installed plugin (from main) refused the unknown setting on 0126's branch. After 0126 merges and the installed plugin is refreshed, add under release: `commit-files: ["plugin/templates/decisions.yml: \"fetch -q --depth 1 https://github.com/Maximilian-Walz/peal\""]` and its commented default in that file's defaults block. Done when `peal config release.commit-files` prints the line on main. Milestone m3, depends 0126, size S.

## Notes

- The marker text should match what 0126's tests and docs use for the Get Peal line
  of `plugin/templates/decisions.yml`; check it against that line before committing.
- `docs/reference/configuration.md` describes `release.commit-files`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
