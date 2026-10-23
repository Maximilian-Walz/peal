---
milestone: m8
plan: required
---

# 0237 — Decide whether setup writes every workflow Peal ships

## Intent

Adopting a project takes two different paths today. Most of the adoption is written by `peal setup` stages, but the CI workflow templates Peal ships (`plugin/templates/decisions.yml`, and `plugin/templates/merge-gate.yml` from 0161) are copied into the project by hand. Look at setup as a whole and decide whether one setup step should write every workflow Peal ships, either a stage of its own or the belfry stage, so that every workflow is adopted the same way. Then either build that, or record why hand-copying stays.

## Scope

## Done when

## Raw

> Look at setup as a whole: adopting projects copy CI workflow templates by hand (decisions.yml, and merge-gate.yml from 0161), while other parts are written by `peal setup` stages. Decide whether one setup (a stage, or the belfry stage) should write every workflow Peal ships, so the adoption path is consistent. From the human's answer at 0161's planning.

## Notes

- Open: a written workflow still needs steps only the human can take, such as making it a required check in branch protection or adding it to Belfry's `auto_merge` checks. How does setup hand those over?
- Open: does setup keep a written workflow's pinned Peal SHA current, or does the project do that?
- Related: the starter release.yml for the Belfry template, filed in the same triage.
- Context: docs/guides/setting-up.md (the stages and how to undo each), docs/guides/belfry.md.

---

## Outcome

<!-- Written at close, replacing this comment. -->
