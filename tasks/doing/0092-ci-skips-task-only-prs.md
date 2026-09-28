---
plan: required
priority: high
touches: [.github/workflows/ci.yml, tools/ci-changes.sh, tools/ci-changes.test.sh]
---

# 0092 — CI skips the harnesses for pull requests that change only task files and docs

## Intent

Every pull request runs the full CI: shellcheck, the macOS harnesses and the sharded Linux harnesses, even when it changes one task file (a filing, a revise, a defer, a priority change) or only a version string (a release's `chore(release)` bump). Fifteen task-file PRs in one afternoon each ran it all, and a release waited on a full run for a one-line `plugin.json` change. The harness jobs are required checks, so `paths-ignore` on the trigger would leave such PRs blocked; instead a first job decides from the changed files, and the harness jobs skip (a skipped required check counts as passed) when nothing they test changed.

## Scope

- A `changes` job decides from the changed files (`tools/ci-changes.sh BASE HEAD`): the harnesses may skip only when every change is a task file (`tasks/`), a milestone's text (`docs/milestones/`), or `plugin.json`'s version line. Anything else, or any doubt (no base, a base git lacks, a failed diff), runs them.
- The macOS harnesses become a plain job named `harnesses (macos-latest)`, so a skip reports under the required check's name (a skipped matrix job would not); the Linux shards skip on the same output, and the gate `harnesses (ubuntu-latest)` passes on every shard green or on a deliberate skip, never on a failed `changes`.
- `concurrency` cancels a superseded run of the same pull request or of main.
- shellcheck keeps running on every change: it takes seconds.

## Done when

- `tools/ci-changes.test.sh` covers task files, a milestone, a version bump, `plugin.json` beyond its version, a mixed change, a look-alike path, no base, an all-zero base, an unknown base and an empty change.
- A task-file-only pull request passes its three required checks with the harnesses skipped; this task's own pull request runs them all.

## Raw

> Why does the full CI run for every of the small stale task PRs you created earlier? That seems wasteful and improvable!

## Notes

- Plan agreed with the human in the session that filed it (2026-09-28): they asked for this to be done at once, after about thirty full CI runs for task-file changes in one afternoon.

- Candidates for "nothing the harnesses test": `tasks/**`, `docs/milestones/**`, Markdown outside `plugin/`; a change to `release.version-files` that only sets the version (the bump PR). Unsure: `docs/**` that harnesses read, `CLAUDE.md`, `.peal/config.yml` (the hooks read it).
- The gate job (`needs: linux`, `if: always()`) must still report, and pass, when the harnesses skipped.
- Pushes to main may keep the full run, or skip the same way; the Scorecard workflow is separate.
