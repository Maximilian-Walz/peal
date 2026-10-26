---
plan: required
depends: [0232]
touches: [plugin/lib/init.sh, plugin/templates/, docs/guides/belfry.md, docs/guides/releases.md]
---

# 0238 — The Belfry template offers a workflow release action and a starter release.yml

## Intent

Under Belfry no session can release: `peal ship publish` refuses without gh's login, so a release has to run as a GitHub workflow that Belfry's release action dispatches, where gh holds the run's token. Task 0232 sets that up for Peal itself. This task makes it available to any Peal project: `peal init --stage belfry` writes the release action as `workflow: release.yml` (commented out, as the template's release action is now) in place of `prompt: /peal:release`, and offers a starter `.github/workflows/release.yml`, kept under `plugin/templates/`, that runs `peal ship` from the installed plugin. The Belfry and releases guides describe it.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
