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

- `.peal/config.yml`: `release.commit-files` lists the Get Peal line of
  `plugin/templates/decisions.yml`, and the commented defaults block describes
  `commit-files: []`.

## Done when

- `peal config release.commit-files` prints
  `plugin/templates/decisions.yml: "fetch -q --depth 1 https://github.com/Maximilian-Walz/peal"`
  with the installed plugin.

## Raw

> Peal's own .peal/config.yml lists the template under release.commit-files, so its releases pin the Get Peal SHA. Found in 0126: the installed plugin (from main) refused the unknown setting on 0126's branch. After 0126 merges and the installed plugin is refreshed, add under release: `commit-files: ["plugin/templates/decisions.yml: \"fetch -q --depth 1 https://github.com/Maximilian-Walz/peal\""]` and its commented default in that file's defaults block. Done when `peal config release.commit-files` prints the line on main. Milestone m3, depends 0126, size S.

## Notes

Revised 2026-10-20: human hold lifted: v0.3.0 (with 0126) is released and installed

Deferred 2026-10-19 after a claim: installed plugin 0.2.0 predates 0126 and refuses release.commit-files; waits for a release containing 0126 and a plugin refresh

- The marker text should match what 0126's tests and docs use for the Get Peal line
  of `plugin/templates/decisions.yml`; check it against that line before committing.
- `docs/reference/configuration.md` describes `release.commit-files`.
- 2026-10-19, after a claim: 0126 has merged, but the installed plugin is still 0.2.0,
  which predates it, so the installed `peal config` and `peal commit` refuse the entry
  ("unknown setting release.commit-files"). Blocked (`human`) until the human cuts a
  release containing 0126 and the installed plugin is refreshed to it; that release
  still needs the template's SHA set by hand. The human chose to defer rather than land
  the edit with the release.
- Verified then: the marker matches the Get Peal line of `plugin/templates/decisions.yml`
  (line 48) and the existing `release.version-files` entry, in the `PATH: "TEXT"` form
  `peal_commit_files` (`plugin/lib/ship.sh`) accepts. The checkout's CLI
  (`PEAL_ROOT=$PWD/plugin plugin/bin/peal config release.commit-files`) printed the line.
  The edit, a few lines: under `release:`,
  `commit-files: ["plugin/templates/decisions.yml: \"fetch -q --depth 1 https://github.com/Maximilian-Walz/peal\""]`,
  and in the commented defaults block above `version-files`, `#   commit-files: []`
  with a comment: files with one marked line holding a commit SHA that `peal ship pin`
  sets to the tag's commit, each `"PATH: \"TEXT\""`.
- The `chore(release): pin` gate in `plugin/lib/githooks.sh` also reads this setting, so
  the entry should land before the first release that is meant to pin by itself.

---

## Outcome

<!-- Written at close, replacing this comment. -->
