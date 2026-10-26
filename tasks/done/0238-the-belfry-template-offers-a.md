---
plan: required
depends: [0232]
touches: [plugin/lib/init.sh, plugin/lib/init.test.sh, plugin/templates/release.yml, plugin/commands/setup.md, docs/guides/belfry.md, docs/guides/releases.md, docs/reference/cli.md, docs/security.md, .peal/config.yml, .belfry.yml]
size: M
model: opus
---

# 0238 — The Belfry template offers a workflow release action and a starter release.yml

## Intent

Under Belfry no session can release: `peal ship publish` refuses without gh's login, so a release has to run as a GitHub workflow that Belfry's release action dispatches, where gh holds the run's token. Task 0232 sets that up for Peal itself. This task makes it available to any Peal project: `peal init --stage belfry` writes the release action as `workflow: release.yml` (commented out, as the template's release action is now) in place of `prompt: /peal:release`, and offers a starter `.github/workflows/release.yml`, kept under `plugin/templates/`, that runs `peal ship` from the installed plugin. The Belfry and releases guides describe it.

## Scope

- `plugin/lib/init.sh`'s Belfry template: the commented-out release action as a workflow action (`workflow: release.yml`), and a `--release-workflow` flag that writes the starter.
- A starter `plugin/templates/release.yml`, its pin followed by releases.
- `docs/guides/belfry.md`, `docs/guides/releases.md`, `docs/reference/cli.md`, `docs/security.md`, `plugin/commands/setup.md`; `.peal/config.yml` and `.belfry.yml` as the pin test and guard lists require.

## Done when

- `peal init --stage belfry` writes the workflow release action (commented out) and prints the offer of the starter workflow; with `--release-workflow` it writes `.github/workflows/release.yml` from the template, refuses over a different existing file, and `--remove belfry` removes it while unchanged; asserted by `init.test.sh`.
- `tools/pins.test.sh`, `tools/docs.test.sh`, `tools/lint.sh` and `tools/test-all.sh` pass; the propose job's shell is run by hand against a local scratch project.
- The starter workflow, dispatched with a version, runs `peal ship` through to the release on a fresh project: proven after merge by the human on a scratch repository (Human steps in the pull request).

## Raw

> The Belfry template offers a workflow release action and a starter release.yml
>
> ## Intent
>
> Under Belfry no session releases: `peal ship publish` refuses without gh's login, and a release runs as a GitHub workflow that Belfry's release action dispatches, where gh has the run's token. Task 0232 does that for Peal itself. Once this is done any Peal project gets the same: `peal init --stage belfry` offers a release action `workflow: release.yml` in place of `prompt: /peal:release`, and a starter `.github/workflows/release.yml` running `peal ship` from the installed plugin.
>
> ## Scope
>
> - `plugin/lib/init.sh`'s Belfry template: the commented-out release action as a workflow action.
> - A starter `release.yml` under `plugin/templates/`, written or offered by the belfry stage.
> - `docs/guides/belfry.md` and `docs/guides/releases.md`.
>
> ## Done when
>
> - `peal init --stage belfry` writes the workflow release action (commented out) and offers the starter workflow, asserted by `init.test.sh`.
> - The starter workflow, dispatched with a version, runs `peal ship` through to the release on a fresh project.
>
> ## Raw
>
> > Release: Belfry releases through a GitHub workflow its release action dispatches (`workflow: release.yml`), where gh has the run's token; no session releases. [...] one idea is filed for a generic `workflow:` release action and starter `release.yml` in the template.
>
> (The human's answer to 0203's plan.)
>
> ## Notes
>
> - Depends on 0232; build on what it learns about the identity the workflow writes main with. plan: auto, size M.
> - Related: the setup-writes-every-workflow decision filed in the same triage.

## Notes

- The human's draft gives Scope and Done when (quoted in Raw); the planner takes them from there.
- plan is `required` rather than the draft's `auto`: the work adds a file under `plugin/templates/`, one of `plan.required-paths`.
- Open: does the belfry stage write the starter workflow, or only offer it (print it / ask)? The draft says "written or offered". Relates to the setup-writes-every-workflow decision filed in the same triage.
- Open: how the starter workflow installs Peal's plugin on the runner, and which identity it writes main with (tag, version files) when main is protected; 0232 should answer the latter.
- Open: the "fresh project" end-to-end check needs a real GitHub repository; how it is proven (a scratch repo, a dry run) is the planner's call.
- Context: `docs/guides/belfry.md`, `docs/guides/releases.md`, `plugin/lib/ship.sh`, `plugin/commands/release.md`; task 0232 (Peal's own release workflow).
- Human's answers to the plan (2026-10-26):
  - Offer: a `--release-workflow` flag writes the starter; the plain stage prints an offer line; `/peal:setup` asks.
  - Remove: `--remove belfry` removes the starter while it equals the template; an edited one is kept with a note.
  - Pattern: the action's version pattern is rendered from `release.tag-prefix`; left out when the prefix is empty or holds regex characters.
  - Secrets: keep `PEAL_RELEASE_APP_ID` / `PEAL_RELEASE_APP_KEY`.
  - Read token: the propose job may use the run's read-only `GITHUB_TOKEN` (contents, issues, pull-requests read), step env only; `docs/security.md` says so.
  - Main: read at run time (`peal config main`), the file stays byte-equal to the template.
  - Scope: changing `.peal/config.yml`, `.belfry.yml`, `docs/security.md`, `docs/reference/cli.md`, `plugin/commands/setup.md` and `init.test.sh` is agreed.
  - E2E: proven after merge by the human on a scratch repository; the session runs the propose shell locally.
  - Pin lag: the guide gives the same `git ls-remote` instruction as the other templates; freshness is left to 0237.
  - Duplicates: 0242 (of 0238) and 0240 (of 0237) are left and named in the Outcome.
  - Peal's own `.github/workflows/release.yml` stays as it is.

## Plan

**Template `plugin/templates/release.yml`.** 0232's shape: dispatch only (`version`, `dry_run`), concurrency group `release` never cancelled, top-level `permissions: contents: read`, two jobs.
- `propose`: no environment, no secret. A "Get Peal" step gets Peal pinned by SHA in the line form `pins.sh`/`pins.test.sh` expect (the same fetch line as `decisions.yml` and `merge-gate.yml`), `peal="$RUNNER_TEMP/peal/plugin/bin/peal"`. Read-only `github.token` reaches propose/notes through step env (`GH_TOKEN`, `GIT_CONFIG_*` credential helper); job permissions contents/issues/pull-requests read. Main read at run time with `$peal config main`; a real run refuses any ref but `refs/heads/<main>`.
- `release`: `needs: propose`, `if: !inputs.dry_run`, `environment: release`; App token from `PEAL_RELEASE_APP_ID`/`PEAL_RELEASE_APP_KEY` with Peal's permissions plus `permission-issues: read`; the App's bot commits and tags; `bump`, `tag`, `publish`, `pin`, the `wait` loop when `release.wait-ci` is set; prints the `version:`/`url:` lines. Inputs and secrets reach the shell only through `env`, `persist-credentials: false`, every `uses:` pinned by SHA.
- Its pin line is added to `.peal/config.yml` `release.version-files` and `release.commit-files` (required by `tools/pins.test.sh:94-105`).

**`plugin/lib/init.sh`.** `_peal_init_belfry_text` (429-434): the commented `release:` action becomes `workflow: release.yml` with an asked `version` input (pattern from `release.tag-prefix`), `triggers: [button]`, `single: true`, `release: true`, a comment that the asked version is the confirmation and that `.github/workflows/release.yml` must exist. The stage prints one offer line; `--release-workflow` (belfry stage only, refused elsewhere) writes the starter through `_peal_init_put`, status 1 over a different existing file. `--remove belfry` removes it only while equal to the template, else keeps it with a note.

**`plugin/commands/setup.md`** step 2 asks whether the human wants the release action; on yes it uncomments it and reruns the stage with `--release-workflow`.

**Docs.** `docs/guides/belfry.md` Actions section (195-203) and its run block (14-37) if the output gains a line; `docs/guides/releases.md` "Under Belfry" rewritten for any project (adopt the starter, the App, the `release` environment restricted to main, the read token, the version pattern vs `release.tag-prefix`, the `git ls-remote` pin instruction); `docs/reference/cli.md:30-37` the flag; `docs/security.md:466-487` the starter with the templates and its read token; `.belfry.yml` adds `plugin/templates/release.yml` to the `&never` list.

**Verification.** `init.test.sh`: contract text (workflow form, no `prompt: /peal:release`), offer line without flag and no file written, flag writes a file equal to the template and a second run reports `unchanged`, refusal over a different file, remove unchanged vs edited, flag refused on other stages, existing exact-output checks (92-93, 115-116) updated. `tools/pins.sh` clean, `tools/pins.test.sh` (three templates), `tools/docs.test.sh`, `tools/lint.sh`, `tools/test-all.sh`. The template parses as YAML, no `${{ inputs.* }}`/`${{ secrets.* }}` in `run:`, `actionlint` if installed. The propose shell by hand against a `peal init --stage tasks` scratch repo with a bare local origin: empty version proposes, NOTHING fails a real run / greens a dry run, malformed version refused, non-main ref refused for a real run, a non-default tag prefix gives the right tag.

Ranges: `tasks/done/0232-peal-release-as-a-workflow.md:73-195`, `.github/workflows/release.yml:1-216`, `plugin/templates/merge-gate.yml:1-44`, `plugin/templates/decisions.yml:40-56`, `plugin/lib/init.sh:1-22`, `plugin/lib/init.sh:31-45`, `plugin/lib/init.sh:382-469`, `plugin/lib/init.sh:596-671`, `plugin/lib/init.test.sh:88-125`, `plugin/lib/init.test.sh:175-186`, `plugin/lib/ship.sh:669-681`, `plugin/lib/ship.sh:764-776`, `plugin/lib/ship.sh:817-833`, `plugin/lib/ship.sh:919-935`, `plugin/lib/ship.sh:991-1003`, `plugin/lib/config-defaults.yml:43-55`, `plugin/templates/launcher:17-23`, `.peal/config.yml:9-26`, `.belfry.yml:22-40`, `.belfry.yml:61-99`, `tools/pins.sh:1-59`, `tools/pins.test.sh:79-110`, `plugin/commands/setup.md:133-147`, `docs/guides/belfry.md:9-37`, `docs/guides/belfry.md:157-169`, `docs/guides/belfry.md:195-221`, `docs/guides/releases.md:1-121`, `docs/reference/cli.md:25-41`, `docs/security.md:460-489`, `docs/design.md:471-478`.

---

## Outcome

Built: any Peal project under Belfry can now release through a GitHub workflow, as Peal itself does since 0232.

- `plugin/templates/release.yml` (new): the starter release workflow. It has the shape of 0232's: dispatch only (`version`, `dry_run`), a `release` concurrency group, a secret-free `propose` job and a `release` job in the `release` environment with the App token (`PEAL_RELEASE_APP_ID`/`PEAL_RELEASE_APP_KEY`). It differs from Peal's own (left unchanged, as agreed) in four ways:
  - It runs Peal from `$RUNNER_TEMP/peal`, fetched pinned by SHA (v0.8.0). The "Get Peal" step is one YAML anchor (`&get-peal`) aliased in the release job, so there is one marked pin line for `peal ship pin` and `tools/pins.sh`.
  - `propose` has contents/issues/pull-requests read and the run's `github.token` in that step's env only, for private repositories and the issues storage.
  - The main branch is read at run time with `peal config main`. A real run refuses any other ref, and the release job runs only when propose named a version.
  - The App token adds `permission-issues: read`.
- `plugin/lib/init.sh`: the belfry stage's commented release action is now the workflow form (`workflow: release.yml`, an asked `version` whose pattern follows `release.tag-prefix`, `triggers: [button]`, `single: true`, `release: true`). The pattern is left out unless the prefix matches `[A-Za-z0-9_/-]+`.
  - While `.github/workflows/release.yml` is missing, the stage prints an offer line. `--release-workflow` writes it, byte-equal to the template, and refuses with status 1 over a different file. `--remove belfry` removes it while unchanged and keeps an edited one.
- `plugin/commands/setup.md`: step 2 asks about the release action. It runs `--release-workflow` before the human uncomments, because the stage refuses a `.belfry.yml` edited since it wrote it.
- Docs: the Belfry guide (Actions), the releases guide ("Under Belfry", rewritten for any project), the CLI reference (the flag), `docs/security.md` (the starter among the templates, its read token) and `docs/design.md` (the releases row, the templates paragraph).
- `.peal/config.yml`: version-files and commit-files gain the template's pin line. `.belfry.yml`: `&never` gains the template.

Verified:
- `init.test.sh`: 345/0.
- `pins.test.sh`, `docs.test.sh` and `lint.sh` pass, and so does `test-all.sh` (38 harnesses).
- The propose shell was run by hand against a scratch project with a bare local origin, covering the empty version, NOTHING, a malformed version, a non-main ref, and `main: trunk` with `tag-prefix: rel-`.
- The end-to-end dispatch on a fresh GitHub repository is left to the human after merge, as agreed (Human steps).

For the next session:
- If GitHub ever rejects the anchor/alias, the fallback is passing the SHA through a job output.
- Backlog task 0252 (release pull requests skip the harnesses) should know that a release now also changes the pin line of `plugin/templates/release.yml`.
- `tools/pins.test.sh:104` still says "at least decisions.yml and merge-gate.yml" (≥2). This is harmless.
- Duplicates, left as the human chose: 0242 duplicates this task, 0240 duplicates 0237. Both are for retiring.

### Reviewer findings not acted on

- The action's pattern rejects pre-releases that the workflow's own check accepts: this matches the agreed plan (a release version from the button), so it is left as is.
