---
milestone: m3
plan: required
---

# 0119 — Every example in the docs is checked by the docs harness

## Intent

Carried forward from milestone m2's review (0046), acceptance criterion 4's second half:
"every example in the docs is exercised by a harness". `tools/docs.test.sh` checks only
fenced blocks that carry a `<!-- docs-check: ... -->` marker, and four blocks carry none:
the settings.json pin in `docs/getting-started.md`, both `peal migrate` commands in
`docs/migrating.md`, and the section skeleton in `docs/reference/tasks.md`. Mark or check
them, and make the harness fail on an unmarked block so a new example cannot slip past.

## Scope

## Done when

## Raw

> every example in the docs is exercised by a harness (m2's acceptance criterion 4,
> found not met by the m2 review, 0046: four unmarked fenced blocks)

## Notes

- Open: whether a block that cannot run sensibly (the settings.json pin) gets an explicit
  exempt marker, or a check of its own (valid JSON, the repo and marketplace names).
- Open: the migrate commands need a pre-Peal fixture project to run against;
  `plugin/lib/migrate.test.sh` has synthetic fixtures that may serve.

---

## Outcome

<!-- Written at close, replacing this comment. -->
