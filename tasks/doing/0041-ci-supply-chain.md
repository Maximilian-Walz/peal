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

