---
milestone: m6
plan: required
size: M
depends: []
priority: high
touches: [.github/workflows/release.yml, .belfry.yml, docs/guides/releases.md, docs/guides/belfry.md, docs/reference/configuration.md, plugin/commands/release.md, docs/security.md]
model: opus
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

Human's answers to the plan (2026-10-26):
- Identity: a GitHub App token minted per run (`actions/create-github-app-token`,
  secrets `PEAL_RELEASE_APP_ID` / `PEAL_RELEASE_APP_KEY`), the App not a ruleset bypass
  actor; no fallback to `github.token`. A real run whose secrets are missing fails up
  front; the dry run needs none.
- Environment: the job uses `environment: release`; the docs tell the human to create it,
  restricted to main.
- Only main: a real run refuses any ref but `main`; other refs dry-run only.
- Result lines: `version:` and `url:` printed in the last step's log and in
  `$GITHUB_STEP_SUMMARY`.
- No version: a real run with an empty version and `NOTHING since …` fails ("nothing
  calls for a release; name a version"); a dry run ends green.
- Rerun: no resume logic; the guide says how to finish by hand.
- Confirm: the version typed into the Release button is the consent; `dry_run` is a
  manual preview.
- Pattern: Belfry's input pattern kept verbatim; the workflow also accepts `1.2.3` and
  pre-release suffixes on a manual dispatch.
- `.belfry.yml` keeps `title: Release` and `single: true`.
- Committer: the App's own bot (`<app-slug>[bot]`, its noreply email from the bot user's
  id), on the bump/pin commits and the annotated tag, so the named identity is the one
  that pushes.
- Security doc: yes, one short paragraph in docs/security.md's CI section.
- Template: `plugin/lib/init.sh`'s `prompt: /peal:release` suggestion is left alone and
  filed as an idea; docs/guides/belfry.md:196-198 gets a sentence pointing to Peal's
  own workflow.
- Post-merge: the static checks plus the human's own dispatch after merge are the proof;
  the steps go into the pull request body as Human steps.
- Budget: the human left it to the session; ship's own 2 h merge budget is kept (no
  override in the workflow: one number, in ship), job `timeout-minutes: 300`.

## Plan

Approach:
- `.github/workflows/release.yml` (new): `on: workflow_dispatch` with inputs `version`
  (string, default "") and `dry_run` (boolean, default false); `concurrency: { group:
  release, cancel-in-progress: false }`; top-level `permissions: contents: read`; one
  job, `timeout-minutes: 300`, `environment: release` (for the real run; the dry run
  must not need its secrets — use the environment only where the secrets are read, e.g.
  a separate write job gated on the propose job, or state why one job suffices).
  Checkout pinned by SHA like ci.yml, `fetch-depth: 0`, `persist-credentials: false`.
  Inputs reach shell only through `env:` (never `${{ inputs.* }}` / `${{ secrets.* }}`
  inside `run:`); the shell checks the version against
  `^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$`.
  Propose: `plugin/bin/peal ship propose`; version from the input else `PROPOSE`; on
  `NOTHING` with no version: dry run exits 0, real run fails. `peal ship notes <v>` to
  the log and `$GITHUB_STEP_SUMMARY`. Dry run ends there with `version: vX.Y.Z (dry
  run)`. Real run: refuse unless `github.ref == 'refs/heads/main'`; mint the App token
  (`actions/create-github-app-token@64ab729a6294000f5aa4a4bc0b73d1f32bc45510 # v3.3.0`),
  fail up front if the secrets are missing; pass it via step-level env only (`GH_TOKEN`;
  git through `GIT_CONFIG_COUNT`/`KEY`/`VALUE` credential helper reading `$GH_TOKEN`,
  nothing written to `.git/config`); commit identity the App's bot. Steps `bump`, `tag`,
  `publish`, `pin`, then `wait` looped while it prints `WAIT:` when `peal config
  release.wait-ci` is `true`. Exit 3 from bump/pin fails the run. Last step prints
  `version: vX.Y.Z` and `url: <release>` (url from publish's output) to the log and the
  step summary. Every `uses:` pinned by 40-hex SHA + `# vX.Y.Z`.
- `.belfry.yml`: the `release` action becomes `title: Release`, `workflow: release.yml`,
  `inputs: { version: { ask: true, pattern: 'v[0-9]+\.[0-9]+\.[0-9]+' } }`, `triggers:
  [button]`, `release: true`, `single: true`; comment says the asked version is the
  confirmation.
- Docs: `docs/guides/releases.md` a new "Under Belfry" section (the workflow, inputs, dry
  run, the App and the `release` environment the human sets up, how to finish a failed
  run by hand); `docs/guides/belfry.md:157-160` point to the workflow, `:196-198` a
  sentence that the prompt form needs gh outside a sandbox and pointing to Peal's own
  workflow; `docs/reference/configuration.md:49` `release.wait-ci` covers the workflow;
  `plugin/commands/release.md:11-12` Belfry dispatches the release workflow instead;
  `docs/security.md` one paragraph in the CI section (lines 429-447).
- File an idea: `peal init --stage belfry` (`plugin/lib/init.sh:423-434`) still suggests
  `prompt: /peal:release`; a generic release workflow template for projects under Belfry.

Verification: `tools/pins.sh`, `tools/test-all.sh`, `tools/lint.sh` pass; the workflow
and `.belfry.yml` parse as YAML (`actionlint` if installed); no `${{ inputs/secrets }}`
inside `run:`; the propose/notes/version-check shell run against a scratch repo with a
local bare origin (empty version picks PROPOSE, NOTHING stops a real run, a malformed
version is refused, dry run prints `version:` and notes). After merge, by the human: a
dry-run dispatch, the Release button, `belfry status`.

Ranges: tasks/doing/0232-peal-release-as-a-workflow.md:1-70, .belfry.yml:22-35,
.belfry.yml:55-108, .github/workflows/ci.yml:1-35, .github/workflows/ci.yml:233-239,
.peal/config.yml:18-31, plugin/commands/release.md:6-30, plugin/commands/release.md:65-133,
plugin/lib/ship.sh:28-68, plugin/lib/ship.sh:286-300, plugin/lib/ship.sh:600-717,
plugin/lib/ship.sh:759-869, plugin/lib/ship.sh:919-1053, plugin/lib/main-write.sh:1-41,
plugin/lib/main-write.sh:136-233, plugin/lib/github.sh:104-124,
plugin/templates/decisions.yml:1-57, plugin/lib/init.sh:423-434, tools/pins.sh:1-60,
tools/ci-changes.sh:8-9, docs/design.md:471-478, docs/security.md:124-147,
docs/security.md:406-447, docs/security.md:449-465, docs/guides/releases.md:1-69,
docs/guides/belfry.md:134-168, docs/guides/belfry.md:194-199,
docs/reference/configuration.md:48-67, docs/reference/cli.md:743-778,
docs/milestones/m6.md:1-35
