---
milestone: m1
priority: high
plan: required
depends: []
---

# 0073 — Two filings at once never give two tasks the same id

## Intent

Since writes to a protected main go through pull requests (0061), two filings can
pick their id from different states of main: #71 and #72 both filed a 0069, and both
merged, so the backlog held two tasks with one id. Every command that looks a task up
by id is then ambiguous. When this is done, a filing whose id is taken by the time its
pull request merges is renumbered first, and the lint refuses a tree with duplicate ids,
so CI catches what slips through.

## Scope

- The main-write path: before merging (or when its PR conflicts), check the id against
  the current main and renumber the task file, its heading and any `depends`/`part-of`
  in the same PR that name it.
- The lint: duplicate ids in the tasks directories fail, naming both files.

## Done when

- Harnesses: two filings from the same base end as two ids; a tree with a duplicate id
  fails the lint.

## Raw

Found when 0069 was filed twice on 2026-09-25; the later filing's text was renumbered
to 0070 by hand.

## Notes


---

## Outcome
