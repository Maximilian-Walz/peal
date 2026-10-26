---
plan: required
touches: [tools/ci-changes.sh, tools/ci-changes.test.sh, .github/workflows/ci.yml, CONTRIBUTING.md]
size: S
---

# 0252 — A release's bump and pin pull requests skip the harnesses when only their marked lines changed

## Intent

Every release opens two pull requests to main: `peal ship bump` and `peal ship pin`. Both run CI's full harnesses on macOS and Ubuntu. For v0.7.0, the bump (#355) took 12 minutes to merge and the pin (#358) 19, so the release workflow (0232) waits about half an hour on tests that cannot fail because of what changed.

`tools/ci-changes.sh` already skips the harnesses for a release's changelog entry and for a `plugin.json` diff that touches only `"version"`. Both pull requests also change the marked line of a file under `release.version-files` and `release.commit-files` (`plugin/templates/decisions.yml`, `merge-gate.yml`): the `# vX.Y.Z` comment, then the pinned SHA. That counts as a code change, so the harnesses run.

Treat a diff confined to those files' marked lines the way `plugin.json`'s version line is treated, equally strictly. The checks that do bear on the line keep running on every pull request: `tools/pins.sh` and the lint. A wrong SHA there breaks every adopting project's copy of the template.

## Scope

- `tools/ci-changes.sh` skips the harnesses for a `plugin/templates/*.yml` diff confined to Peal's fetch line, its SHA and/or `# vX.Y.Z` changed, as strictly as the plugin.json version rule.
- `tools/pins.test.sh` runs on every pull request, as a step of the `shellcheck` job.
- The descriptions of what skips (`.github/workflows/ci.yml` comment, `CONTRIBUTING.md`) follow.

## Done when

- A bump's and a pin's diff (v0.8.0's, against their parents) print `harnesses=false`; any other byte in a template, another file, or `.peal/config.yml` alongside prints `harnesses=true`.
- `tools/ci-changes.test.sh` covers the skip and run cases below; `tools/lint.sh` passes.
- `bash tools/pins.test.sh` runs in the `shellcheck` job.

## Raw

> Couldn't it be more optimized than bump + pin having to run the full CI? Does it even make sense to run the CI at all?

(from a Belfry session; the human agreed: skip the harnesses for the marked lines, keep the pin and lint checks)

## Notes

- Two pull requests remain either way. The pin needs the tag's commit, which exists only once the bump has been squash-merged.
- Open question: read the marked lines from `release.version-files`/`commit-files` in `.peal/config.yml` (generic for any project), or hard-code Peal's two templates? Reading the config is the more honest choice, but `ci-changes.sh` then trusts a config file the same pull request may change. A diff that also changes `.peal/config.yml` should run everything.
- Peal's CI runs on GitHub-hosted runners, so the cost is time to release, not runner capacity.
- 2026-10-26, the human's answers to the plan: run `tools/pins.test.sh` as a step of the `shellcheck` job (it is the only check that a template's `# vX.Y.Z` equals plugin.json's version, and the harnesses no longer run on a bump); hard-code Peal's fetch line text rather than read `.peal/config.yml` (`tools/` is not shipped; `pins.test.sh:94-103` cross-checks templates against the config); a diff changing both the SHA and the tag skips; the rule is limited to `plugin/templates/*.yml`; update the ci.yml comment and CONTRIBUTING.md, leave the `.belfry.yml` comment.
- There are three templates with the line, not two: `decisions.yml`, `merge-gate.yml`, `release.yml`.

## Plan

In `tools/ci-changes.sh`'s `case`, a branch for `plugin/templates/*.yml`, after the plugin.json pattern: `git diff --no-renames -U0 BASE HEAD -- f`, headers dropped. It skips only when all hold:
- exactly one `-` and one `+` line (empty: a mode-only change, run);
- both contain the literal `fetch -q --depth 1 https://github.com/Maximilian-Walz/peal`;
- both end in `<40 lowercase hex> # v<N>.<N>.<N>` (the form `tools/pins.sh` accepts);
- the two lines are byte-equal once that SHA and version are replaced by placeholders.
Anything else is `yes`. `.peal/config.yml` and `.github/workflows/*` stay at `*) yes`, so a diff that also changes the config runs everything. Header comment (lines 7-11) updated.

`.github/workflows/ci.yml`: `bash tools/pins.test.sh` as a step of the `shellcheck` job; the comment at 19-22 says what skips. `CONTRIBUTING.md:65-66` likewise.

Rejected: reading BASE's config (YAML parse in a CI gate, no gain in Peal's one repository); reusing the pre-push gate's rebuild (`plugin/lib/githooks.sh:434-539`, needs the PR's tag, which the `changes` job lacks).

Files: `tools/ci-changes.sh`, `tools/ci-changes.test.sh` (a fixture template with a Peal fetch line and a `uses:` line), `.github/workflows/ci.yml`, `CONTRIBUTING.md`.

Verification: `bash tools/ci-changes.test.sh`, `tools/lint.sh`.
- Skip: tag comment bumped; SHA changed; both; a full bump set (CHANGELOG + plugin.json version + template line).
- Run: another template line changed; fetch line changed beyond SHA and tag (other URL, `--depth 1` dropped); short or uppercase SHA; `# v0.9`; a second line added beside a valid change; a `uses: actions/checkout@<sha> # vX.Y.Z` re-pin in a template; the same change in `.github/workflows/*.yml` or a non-`.yml` under templates; a mode-only template change; a valid change together with `.peal/config.yml`.
- Real-world: `tools/ci-changes.sh <parent> <commit>` on v0.8.0's bump and pin commits on main prints `harnesses=false` for both.

Ranges relied on: tools/ci-changes.sh:1-38, tools/ci-changes.test.sh:1-87, .github/workflows/ci.yml:18-52, .github/workflows/ci.yml:210-239, .peal/config.yml:12, .peal/config.yml:18-28, tools/pins.sh:1-59, tools/pins.test.sh:79-112, tools/lint.sh:3, tools/lint.sh:35-36, plugin/templates/decisions.yml:46-49, plugin/templates/merge-gate.yml:37-40, plugin/templates/release.yml:75-78, plugin/lib/githooks.sh:434-539, docs/reference/configuration.md:61-67, docs/security.md:146-153, docs/design.md:512-532, CONTRIBUTING.md:65-68, .belfry.yml:94-98, .belfry.yml:162-167, tasks/backlog/0206-pins-test-sh-checks-the.md (overlap: pins.test in CI).


---

## Outcome

<!-- Written at close, replacing this comment. -->
