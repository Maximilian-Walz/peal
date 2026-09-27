---
milestone: m1
plan: skipped
touches: [.github/**]
---

# 0041 — CI and supply chain: pinned actions, Dependabot, minimal permissions, Scorecard

## Intent

Peal's CI runs third-party actions. Pin them, keep the pins current, give each job only
the permissions it needs, and let OpenSSF Scorecard watch the rest.

## Scope

- Every GitHub Action pinned by commit SHA, with Dependabot (`.github/dependabot.yml`,
  github-actions) keeping the pins current; workflow permissions at the minimum per job.
- The README documents installing from a release tag (`ref: vX`) for users who want a
  fixed version; `source: ./plugin` stays.
- OpenSSF Scorecard as a weekly workflow.

## Done when

- Every `uses:` is a SHA, Dependabot and Scorecard are configured, and each job's
  permissions are minimal.

## Raw

Filed as issue #41 (https://github.com/Maximilian-Walz/peal/issues/41); its text is carried over into the sections above and below.

## Notes

Human steps, not for the session: signed release tags (a signing key) and a ruleset
protecting `main` are repository settings; the PR lists them under "Human steps".

---

## Outcome

Built: every `uses:` in `.github/workflows/` is pinned to a commit SHA with its tag in a
comment (`ci.yml`'s two `actions/checkout` at v4.4.0; the new `scorecard.yml`'s checkout,
`ossf/scorecard-action`, `upload-artifact` and `codeql-action/upload-sarif`), each pin
checked against the tag's commit on GitHub, annotated tags dereferenced.
`.github/dependabot.yml` updates the github-actions ecosystem weekly.
`.github/workflows/scorecard.yml` runs OpenSSF Scorecard weekly (and on
`workflow_dispatch`), adapted from the upstream template: top-level `read-all`, the one
job narrowed to `security-events: write` and `id-token: write`, which Scorecard needs to
upload SARIF and publish results. `ci.yml` keeps its top-level `contents: read`, already
the minimum for both jobs. The README has a "Getting started" section with the
marketplace block `peal init` writes and, for a fixed version, the same block with
`"ref": "vX"`; `source: ./plugin` is unchanged. `docs/security.md`'s CI boundary now names
the pins, Dependabot and Scorecard.

Decided: `ci.yml` stays on checkout v4 while `scorecard.yml` uses the upstream template's
v7; pinning is not upgrading, and Dependabot bumps each over time.

Left: `plugin/templates/decisions.yml`, the workflow template Peal hands to projects,
still uses `actions/checkout@v4`; it is not Peal's own CI, so it is out of this task's
Intent. Filed as the idea pin-template-checkout.

Next session: the first Scorecard run needs the repository public (or code scanning
enabled) for the SARIF upload and published results. Signed release tags and a ruleset
protecting `main` remain the human's (see the pull request's Human steps).
