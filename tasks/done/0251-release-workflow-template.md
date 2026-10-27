---
milestone:
plan: required
size: S
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

## Notes

- 2026-10-26: Task 0238 (#403), merged just before this claim, delivered the whole scope:
  the `workflow: release.yml` suggestion in plugin/lib/init.sh (init.test.sh asserts that
  `prompt: /peal:release` is gone), plugin/templates/release.yml pinned and bumped through
  .peal/config.yml (tools/pins.sh passes), `--release-workflow` and /peal:setup offering it,
  and docs/guides/belfry.md and releases.md. The human chose to close 0251 as a duplicate of
  0238, with nothing built.

## Plan

Nothing to build: close as a duplicate of 0238.

## Raw

From the human's answers to the plan of 0232: "plugin/lib/init.sh's `prompt:
/peal:release` suggestion is left alone and filed as an idea".

---

## Outcome

Nothing was built. This task duplicates 0238 (#403), which merged just before 0251 was
claimed and delivered its whole scope. In plugin/lib/init.sh, the belfry stage now suggests
the release action as `workflow: release.yml` (commented out), and init.test.sh asserts that
`prompt: /peal:release` is gone. plugin/templates/release.yml is the starter workflow. It is
pinned and bumped through `.peal/config.yml`, and tools/pins.sh passes. `peal init --stage
belfry --release-workflow` writes it, and /peal:setup offers it. docs/guides/belfry.md and
docs/guides/releases.md describe it. On a scratch repository, `peal init --stage belfry
--release-workflow` from main wrote `.belfry.yml` with `workflow: release.yml` and
`.github/workflows/release.yml`. actionlint is not installed on this worker, so the template
was not linted here; 0238's CI linted it. The human chose to close 0251 as a duplicate of
0238. The diff is only the task file, so the review was skipped.
