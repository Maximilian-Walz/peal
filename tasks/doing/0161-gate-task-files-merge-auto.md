---
milestone: m6
plan: required
size: M
depends: []
priority: high
model: opus
touches: [plugin/lib/merge-gate*, plugin/bin/peal, plugin/lib/hostile.test.sh, plugin/templates/merge-gate.yml, tools/pins.test.sh, .peal/config.yml, .belfry.yml, .github/workflows/ci.yml, docs/security.md, docs/reference/cli.md, docs/guides/belfry.md, docs/design.md, CONTRIBUTING.md]
---

# 0161 — Gate a task-files-only pull request from setting `merge: auto` on another task

## Intent

Found in 0149. The `task files` auto-merge tier lets a pull request that touches only `tasks/**` merge by itself, and the `agreed tasks` rule merges any task marked `merge: auto`. A task-files pull request can therefore write `merge: auto` into another task's frontmatter, which the human only means to write when agreeing a plan. Accepted for now; find a gate (a check, a Belfry rule or a harness) so that `merge: auto` cannot arrive through a pull request that auto-merges on its paths.

## Done when

- A pull request that adds or changes `merge: auto` in a task file does not merge without the human, or the gap is documented with its reason in docs/security.md.

## Raw

> Found in 0149: the task-files loophole (a task-files PR setting `merge: auto` on another task) is accepted for now; file an idea for a gate. (The human's answer at planning.)

## Notes

Revised 2026-10-22: Widened by the security review (finding 7)

- Widened by the security review (finding 7): the direct revise and comment pushes are the same gap by another route, so the gate must cover both (see the revise-shape task of Safe under Belfry), and the board must not read `merge` from a claim copy (the consent task of the same milestone). Moved into Safe under Belfry, priority high.

Human's answers at planning, 2026-10-23:

- Hard block: yes, the gate is a failing required check, not merely withheld auto-merge.
- Generic: ship it now, for adopting projects (a `peal` subcommand plus a CI template), and use it in this repository too.
- Split with 0180: 0161 covers the pull request route only; `docs/security.md` names 0180 for the direct push route.
- Setup step: adopting projects copy the template by hand, consistent with `decisions.yml`, guided by `docs/guides/belfry.md`; a follow-up idea looks at setup in general (whether one setup should write every workflow).
- Plan agreed as revised (size M, model opus, merge default).

## Plan

**Approach.** `peal merge-gate BASE HEAD` (`plugin/lib/merge-gate.sh`, `plugin/lib/merge-gate.awk` on `yaml-lib.awk`), dispatched from `plugin/bin/peal` and listed in `--help`. It reads git objects only:

1. Loads BASE's settings for BASE and HEAD's for HEAD (`peal_config_load_ref`); either failing to load fails closed.
2. HEAD's `storage.kind: issues`: prints `merge-gate: issues storage, nothing to check`, status 0.
3. Lists task files with `git ls-tree` at both refs under each side's tasks folder; candidates are HEAD files under `backlog/` or `doing/` whose blob is new or differs from the same path at BASE (unchanged blobs pass).
4. Each candidate's blob goes through `merge-gate.awk`: whether the frontmatter parsed and the raw value of any `merge` key (not `task-scan.awk`'s normalised one).
5. Refused (status 1, each file named): unparseable frontmatter; any `merge` key unless BASE has a task of the same id outside `done/` with the same raw `merge` value.
6. Passes: `merge` removed, close into `done/`, new `done/` file, no change.
7. Fails closed (status 2): BASE empty, all zeros, unknown or not a commit; a ref beginning with `-` (`peal_refuse`); git failing.

**Parser provenance.** Adopting projects: the workflow fetches Peal pinned by SHA; changing it needs a `.github/**` change, which never auto-merges. Peal's own CI runs BASE's `plugin/` (a worktree of BASE in `$RUNNER_TEMP`), HEAD's only while BASE lacks `plugin/lib/merge-gate.sh` (one-time bootstrap, documented in `docs/security.md`).

**Wiring.** `plugin/templates/merge-gate.yml`, modelled on `decisions.yml`: `pull_request`, `contents: read`, checkout with history, Peal fetched at a pinned release SHA, one job named `peal merge-gate` that the project makes required and lists in its Belfry `auto_merge` checks. Added to `.peal/config.yml` `release.version-files`/`commit-files`; `tools/pins.test.sh` checks every `plugin/templates/*.yml` with a Peal fetch line. Peal's own CI: a step in the `changes` job of `.github/workflows/ci.yml`, `pull_request` only; a failed `changes` fails the required `harnesses (ubuntu-latest)`.

**Files.** New `plugin/lib/merge-gate.sh`, `merge-gate.awk`, `merge-gate.test.sh`, `plugin/templates/merge-gate.yml`; `plugin/bin/peal`; `plugin/lib/hostile.test.sh` (`cover merge-gate` and cases); `tools/pins.test.sh`; `.peal/config.yml` (release lists, `plan.required-paths` for `plugin/lib/merge-gate*`); `.belfry.yml` (`never_auto_merge`: the new lib files and template); `.github/workflows/ci.yml`; `docs/reference/cli.md` (`## \`peal merge-gate\``); `docs/security.md` (Auto-merge tiers: the gate, guard, harness; open limits: 0180 for the push route, the bootstrap, `pull_request` vs `pull_request_target`); `docs/guides/belfry.md` (auto-merge and `merge: auto`: copy the template, make the check required, list it in `auto_merge` checks, keep `.github/**` human-merged); `docs/design.md` ("In CI"); `CONTRIBUTING.md` (templates list).

**Verification.** `plugin/lib/merge-gate.test.sh` with temp git repos, under every awk (`for_each_awk`). Refused: `merge: auto` added in backlog, in doing; `"auto"`, `'auto'`; `merge: yes`; new backlog file with `merge`; done task moved back to backlog; slug rename adding it; changed file with unparseable frontmatter; tasks folder moved in HEAD's config with `merge` under the new folder. Passes: no change; unrelated edit; task with `merge: auto` on BASE moved backlog→doing; `merge` removed; close shape (doing without → done with `merge: auto`); new done file with it; unchanged old malformed file; issues storage. Fails closed: empty BASE, all-zero BASE, unknown ref, ref starting with `-`, BASE config that does not parse. Also `hostile.test.sh` coverage, `tools/pins.test.sh`, `tools/docs.test.sh`, `tools/lint.sh`. The CI step itself is proven by this task's own pull request (bootstrap path).

**Decisions of the planner** (shown to the human, not overruled): name `merge-gate` (own subcommand, not `peal check`); raw `merge` key; changed blobs only; each side's own settings; `pull_request`, not `pull_request_target` (no writable tokens to fork code; the workflow-edit route needs `.github/**`, human-merged); own CI runs BASE's plugin with one-time bootstrap; template pinned and kept current by `peal ship`; gate files in `never_auto_merge` and `plan.required-paths`; statuses 0 pass, 1 refused, 2 doubt/misuse.

**Cross-task.** 0180 keeps the direct-push route (its "absorbs the PR route of 0161" becomes "links it"). 0177: if its plan writes consent into main's task copy through a pull request, this gate blocks that.

**Ranges.** tasks/backlog/0180-shape-only-revise-and-comment.md:14-35; docs/security.md:257-286, 376-418; docs/design.md:455-458; docs/guides/belfry.md:38-53; docs/guides/setting-up.md:24-36; docs/reference/cli.md:1-10, 64-69, 590-594; docs/reference/tasks.md:53; .github/workflows/ci.yml:18-36, 193-214; .belfry.yml:51-85, 94-150; .peal/config.yml:10-23; plugin/templates/decisions.yml:1-57; tools/pins.test.sh:78-99; tools/ci-changes.sh:14-21; plugin/bin/peal:116-120, 364-374, 480-563; plugin/lib/config.sh:31-46; plugin/lib/store-files.sh:51-71; plugin/lib/task-scan.awk:29-48, 87-90, 111-127; plugin/lib/yaml-lib.awk:1-18, 152-155; plugin/lib/common.sh:132-136; plugin/lib/hostile.test.sh:680-695, 925-946; tools/docs.test.sh:488-493; CONTRIBUTING.md:42-45.
