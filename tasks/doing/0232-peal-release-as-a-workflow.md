---
milestone: m6
plan: required
size: M
depends: []
priority: high
touches: [.github/workflows/release.yml, .belfry.yml, docs/reference/configuration.md, docs/guides/]
---

# 0232 — Peal's release runs as a GitHub workflow that Belfry's Release button dispatches

## Intent

Peal's `.belfry.yml` release action runs `/peal:release` in a Belfry session, and that
cannot work. Under Belfry, a session's commands run in a sandbox. Only a plain `git
push`, `git fetch` or `git pull` leaves it, with the worker's SSH key. `peal ship` does
its own fetch, push and `gh release` calls inside one process, so all of them stay in
the sandbox, without a key or a `gh` login, and the first fetch fails. This happened with
v0.7.0: the session stopped, filed friction, and the release was run by hand. Belfry
releases itself through a GitHub workflow its release action dispatches (`workflow:
release.yml`, docs/contract.md, Workflows), where no session and no sandbox are
involved. Once this is done, Peal releases the same way: the Release button on Belfry's
Releases tab asks for the version and dispatches the workflow, and the run's end lands in
Belfry's inbox with the release's link.

## Scope

- `.github/workflows/release.yml`, `workflow_dispatch` only, with inputs `version`
  (empty: what `peal ship propose` proposes) and `dry_run` (print the proposal and the
  notes, and tag nothing). One release at a time, never cancelled. Least permissions:
  the run's token stays out of the checkout and goes only to the steps that push. It
  runs `plugin/bin/peal ship` from the checkout: `propose`, `notes`, `bump`, `tag`,
  `publish`, `pin`, and `wait` when `release.wait-ci` is set. The steps print result
  lines Belfry reads: `version: vX.Y.Z`, `url: <release>`.
- `.belfry.yml`: the release action becomes `workflow: release.yml` with
  `inputs: { version: { ask: true, pattern: 'v[0-9]+\.[0-9]+\.[0-9]+' } }`, `release:
  true` and `triggers: [button]`, in place of `prompt: /peal:release`.
- The docs that describe releasing under Belfry (`docs/guides/`, the configuration
  reference), and `plugin/commands/release.md` where it says a Belfry action runs it.
- For the plan to decide: `bump` and `pin` write to main through `main-writes`. With the
  run's `GITHUB_TOKEN`, a direct push may be refused, and a pull request that token opens
  starts no CI, so its auto-merge would wait forever. Decide which identity the workflow
  writes with (the run's token where main takes a push, or an App token) and say it in the
  workflow.

## Done when

- A dry-run dispatch on any branch prints the proposed version and the notes, and tags
  nothing.
- Dispatching the workflow from Belfry's Release button with a version makes the bump
  commit, the tag, the GitHub release and the pin, and the run ends with `version:` and
  `url:` lines that Belfry's inbox item shows.
- `.belfry.yml` validates under Belfry (`belfry status` shows the release action as a
  workflow action), and `tools/test-all.sh` passes.

## Raw

> file option 2

The option, as written in the Belfry session that ran v0.7.0 by hand: "Do what Belfry
does now: a GitHub Actions workflow in peal that runs the `peal ship` steps, and
`release: { workflow: release.yml }` in its `.belfry.yml`. Nothing leaves the sandbox."

## Notes

The v0.7.0 release was made from an unsandboxed session after the Belfry release job
stopped at the first `git fetch`. The other way, granting `peal` as a host command
(`policy.host_commands` with `belfry up --allow-host peal`), was turned down. It would
lend the worker's SSH key and `gh` login to a script that reads its settings from the
clone.
