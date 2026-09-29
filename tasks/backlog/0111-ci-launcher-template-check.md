---
plan: required
---

# 0111 — CI checks the committed launcher against its template

## Intent

The committed `.peal/peal` fell behind `plugin/templates/launcher` unnoticed until a
smoke run found it (task 0098 refreshed it). CI should fail when the two differ, so the
launcher cannot drift again. Only the launcher comparison of `peal doctor version`
belongs in CI: its other check, the installed plugin's version against the running one,
has no meaning on a CI runner.

## Scope

## Done when

## Raw

> CI runs the launcher check of `peal doctor version` (committed .peal/peal byte-identical to plugin/templates/launcher), so the committed launcher cannot fall behind the template again. Found in 0098, whose Notes raised it as an open question; the full `doctor version` also compares the installed plugin version, which CI cannot, so the check needs just the launcher comparison.

## Notes

- Found in task 0098, where it was an open question.
- Open question: a plain `cmp` step in CI, or a launcher-only mode of `peal doctor`
  (which would touch `plugin/`)?
