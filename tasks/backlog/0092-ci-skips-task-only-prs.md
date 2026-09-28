---
plan: required
priority: high
touches: [.github/workflows/ci.yml]
---

# 0092 — CI skips the harnesses for pull requests that change only task files and docs

## Intent

Every pull request runs the full CI: shellcheck, the macOS harnesses and the sharded Linux harnesses, even when it changes one task file (a filing, a revise, a defer, a priority change) or only a version string (a release's `chore(release)` bump). Fifteen task-file PRs in one afternoon each ran it all, and a release waited on a full run for a one-line `plugin.json` change. The harness jobs are required checks, so `paths-ignore` on the trigger would leave such PRs blocked; instead a first job decides from the changed files, and the harness jobs skip (a skipped required check counts as passed) when nothing they test changed.

## Scope

## Done when

## Raw

> Why does the full CI run for every of the small stale task PRs you created earlier? That seems wasteful and improvable!

## Notes

- Candidates for "nothing the harnesses test": `tasks/**`, `docs/milestones/**`, Markdown outside `plugin/`; a change to `release.version-files` that only sets the version (the bump PR). Unsure: `docs/**` that harnesses read, `CLAUDE.md`, `.peal/config.yml` (the hooks read it).
- The gate job (`needs: linux`, `if: always()`) must still report, and pass, when the harnesses skipped.
- Pushes to main may keep the full run, or skip the same way; the Scorecard workflow is separate.
