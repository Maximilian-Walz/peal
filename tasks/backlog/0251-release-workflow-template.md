---
milestone:
plan: required
size:
depends: []
---

# 0251 — peal init --stage belfry suggests a release workflow, not /peal:release

## Intent

`peal init --stage belfry` (plugin/lib/init.sh, the commented-out `actions:` block)
still suggests a `release` action with `prompt: /peal:release`. Under Belfry's sandbox
that prompt cannot release: `peal ship` fetches, pushes and calls `gh release` inside one
process, without a key or a `gh` login. Task 0232 moved Peal's own release to a GitHub
workflow the Release button dispatches (`.github/workflows/release.yml`,
docs/guides/releases.md, Under Belfry). Other projects set up for Belfry should get the
same: a generic release workflow template next to plugin/templates/decisions.yml and
merge-gate.yml, and the suggested action `workflow: release.yml` with an asked version.

## Scope

- A release workflow template (plugin/templates/), pinned like the others, that the
  release bumps and pins, and that `peal init --stage belfry` or `/peal:setup belfry`
  offers to write.
- The suggestion in plugin/lib/init.sh and the `docs-check: belfry` blocks that show it.
- docs/guides/belfry.md, Actions, and docs/guides/releases.md, Under Belfry.

## Done when

- A fresh `peal init --stage belfry` suggests the workflow action, and the template it
  writes validates (actionlint, tools/pins.sh).

## Raw

From the human's answers to the plan of 0232: "plugin/lib/init.sh's `prompt:
/peal:release` suggestion is left alone and filed as an idea".
