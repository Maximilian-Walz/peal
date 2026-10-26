---
plan: required
---

# 0256 — Retire 0206 or narrow it to showing a wrong pin failing CI

## Intent

Task 0252 made CI's `shellcheck` job check out with `fetch-depth: 0` and `fetch-tags: true` and run `tools/pins.test.sh` on every pull request. That covers most of backlog task 0206 (pins.test.sh checks the template's Peal pin in CI, not only in clones that have the tags). Either retire 0206, or narrow it to the one part still open, its Done when: show once that a template whose SHA is not its tag's commit fails CI, through a harness case or a throwaway branch.

## Scope

## Done when

## Raw

> 0206 is largely done by 0252: CI's shellcheck job now fetches tags (fetch-depth 0, fetch-tags true) and runs tools/pins.test.sh on every pull request. Retire 0206, or narrow it to its remaining Done when: a template whose SHA is not its tag's commit is shown failing CI once (a harness case or a throwaway branch).

## Notes

- Open question: retire 0206 with `/peal:retire` or narrow it with `/peal:revise`? This idea may need no work of its own beyond that.
- Context: tasks/backlog/0206-pins-test-sh-checks-the.md; docs/security.md, the section on the template's Peal pin.

---

## Outcome

<!-- Written at close, replacing this comment. -->
