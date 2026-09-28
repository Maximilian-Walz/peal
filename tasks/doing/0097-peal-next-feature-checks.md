---
milestone: m2
plan: required
depends: [0030]
part-of: 0030
---

# 0097 — /peal:next knows the features within the stages

## Intent

`/peal:next` (the origin) suggests the setup stages and the milestone review task. The
features around them, the decisions module, `/peal:drift`, `.peal/review.md`,
releases and the reviewer's settings, should find the user the same way: one
suggestion with this repository's evidence, never a change unasked.

## Scope

## Done when

## Raw

> It knows the stages of `peal init` and the features within them (the decisions
> module, drift and milestone review, releases, the reviewer's settings), each with a
> short check of whether it would help here.

Split from 0030

## Notes

What the origin's planning agreed with the human for this piece:

- Catalogue items `decisions`, `drift`, `releases`, `reviewer` in `plugin/lib/next.sh`,
  checked in fixed order after the stages, with the agreed draft thresholds:
  - `decisions`: off, and an ADR-like directory (`docs/adr`, `docs/decisions`,
    `doc/adr`) or at least 20 tasks done.
  - `drift`: no `.peal/drift.md`, `context` set or a `docs/` of Markdown files, and at
    least 10 tasks done.
  - `releases`: no release tag under `release.tag-prefix` and at least 5 `feat`/`fix`
    tasks done; a version file (`package.json`, `Cargo.toml`, `pyproject.toml`,
    `.claude-plugin/plugin.json`) suggests `release.version-files`.
  - `reviewer`: no `.peal/reviewer.md` and `context` empty while design-like docs exist,
    or CI files while `checks.close` and `checks.commit` are empty.
- `.peal/review.md` joins the `review-task` item or becomes an item of its own: the
  piece's plan decides.
- Accepting does a small step, shown first and committed as `chore(peal)` (`decisions:
  <dir>` in the config, a stub `.peal/reviewer.md` or `.peal/drift.md`,
  `release.version-files`), or runs the command once (`/peal:drift`, `/peal:release`).
  No new `peal init` stages. `templates/decisions.yml` is named for the human to copy,
  not written.
- The checks feed the SessionStart hint too, so they stay cheap: local files and git
  only, no `gh`.
- Likely Done when: `next.test.sh` covers each new item firing and not firing, and its
  decline; on a scratch project with all four stages, `/peal:next` suggests one of these
  features with fitting evidence, and nothing once each is set up or declined.
- Size estimate: M.

---

## Outcome

<!-- Written at close, replacing this comment. -->
