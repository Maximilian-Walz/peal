---
plan: required
touches: [tools/ci-changes.sh]
---

# 0252 — A release's bump and pin pull requests skip the harnesses when only their marked lines changed

## Intent

Every release opens two pull requests to main: `peal ship bump` and `peal ship pin`. Both run CI's full harnesses on macOS and Ubuntu. For v0.7.0, the bump (#355) took 12 minutes to merge and the pin (#358) 19, so the release workflow (0232) waits about half an hour on tests that cannot fail because of what changed.

`tools/ci-changes.sh` already skips the harnesses for a release's changelog entry and for a `plugin.json` diff that touches only `"version"`. Both pull requests also change the marked line of a file under `release.version-files` and `release.commit-files` (`plugin/templates/decisions.yml`, `merge-gate.yml`): the `# vX.Y.Z` comment, then the pinned SHA. That counts as a code change, so the harnesses run.

Treat a diff confined to those files' marked lines the way `plugin.json`'s version line is treated, equally strictly. The checks that do bear on the line keep running on every pull request: `tools/pins.sh` and the lint. A wrong SHA there breaks every adopting project's copy of the template.

## Scope

## Done when

## Raw

> Couldn't it be more optimized than bump + pin having to run the full CI? Does it even make sense to run the CI at all?

(from a Belfry session; the human agreed: skip the harnesses for the marked lines, keep the pin and lint checks)

## Notes

- Two pull requests remain either way. The pin needs the tag's commit, which exists only once the bump has been squash-merged.
- Open question: read the marked lines from `release.version-files`/`commit-files` in `.peal/config.yml` (generic for any project), or hard-code Peal's two templates? Reading the config is the more honest choice, but `ci-changes.sh` then trusts a config file the same pull request may change. A diff that also changes `.peal/config.yml` should run everything.
- Peal's CI runs on GitHub-hosted runners, so the cost is time to release, not runner capacity.

---

## Outcome

<!-- Written at close, replacing this comment. -->
