---
plan: skipped
touches: [.peal/peal]
milestone: m2
---

# 0098 — Refresh this repository's committed launcher and hook stubs

## Intent

This repository's committed `.peal/peal` has fallen behind `plugin/templates/launcher`:
`peal doctor version` no longer finds it byte-identical. Regenerate it with
`.peal/peal init --stage tasks` and commit the result. Check the installed git hook stubs
against `plugin/templates/githook` the same way (`peal doctor hooks`), and refresh them
if they differ.

## Scope

## Done when

## Raw

> Refresh this repository's committed .peal/peal launcher: `peal doctor version` finds it no longer byte-identical to plugin/templates/launcher (found by 0036's smoke run). Run `.peal/peal init --stage tasks` and commit the result; check the installed hook stubs the same way.

## Notes

- Found by task 0036's smoke run (`PEAL_ROOT=$PWD/plugin plugin/bin/peal doctor`).
- Open question: the hook stubs are installed per clone, not committed, so refreshing them
  is `.peal/peal hooks install` on each machine; is there anything to commit there at all?
- Open question: should CI run `peal doctor version` so the committed launcher cannot fall
  behind the template again?

---

## Outcome

<!-- Written at close, replacing this comment. -->
