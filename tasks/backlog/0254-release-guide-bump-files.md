---
plan: skipped
touches: [docs/guides/releases.md]
---

# 0254 — The releases guide says a release makes bump and pin commits only for the files it names

## Intent

0238's end-to-end check, run on a fresh private repository after #403 merged: the starter `release.yml` works. That means `peal init --stage tasks`, `--stage belfry --release-workflow`, the YAML anchor `*get-peal` in both jobs, the dry run, and a real release (tag, GitHub release by the App's bot, `version:`/`url:` lines). Once the project named `release.version-files`, `release.commit-files` and `release.changelog`, the bump and pin commits were pushed by the App as well.

On a fresh project, though, the first real release makes no bump or pin commit: the log says "nothing to bump" and "nothing to pin", because neither `release.version-files` nor `release.commit-files` is set. #403's human step expected a pin commit to appear, and a reader of "Under Belfry" in `docs/guides/releases.md` may expect the same. One sentence there should say that the bump and pin commits come only from the files `.peal/config.yml` names (`release.version-files`, `release.changelog`, `release.commit-files`), and that a project naming none gets just the tag and the release.

## Scope

## Done when

## Raw

> okay, please handle the test report

(from a Belfry session that ran 0238's human steps; the guide's App permissions already list all six, so only this gap is left)

## Notes

- Also seen: `peal init --stage belfry` prints "skipped the check: belfry check is not available yet" when `belfry` is not on `PATH`. This is expected; once it was on `PATH`, `belfry check` said ok.
- The PR description of #403 listed the App permissions as "Contents write, Issues read". The template's token step also requests `pull-requests: write` and `actions`, `checks` and `statuses: read`. The merged guide already lists all six, so there is nothing to fix there.

---

## Outcome

<!-- Written at close, replacing this comment. -->
