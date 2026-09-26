---
plan: required
touches: [plugin/templates/decisions.yml]
---

# 0069 — Pin actions/checkout in the decisions workflow template

## Intent

The workflow template Peal hands to projects, `plugin/templates/decisions.yml`, still
uses `actions/checkout@v4` by tag. Pin it by commit SHA, as 0041 did for Peal's own CI:
once a project copies it into its `.github/workflows`, that project's Dependabot keeps the
pin current.

## Scope

## Done when

## Raw

> Pin actions/checkout by SHA in plugin/templates/decisions.yml, the workflow template Peal hands to projects: once copied into a project's .github/workflows, that project's Dependabot keeps the pin current. Found closing 0041, which pinned only Peal's own CI.

## Notes

- Nothing in Peal's own repository keeps the template's pin current (Dependabot scans
  only `.github/workflows/`): does the pin go stale in the template between releases, and
  is that acceptable, or does something (a check, a Dependabot directory entry) keep it
  current?
- Whether it belongs to m1 ("a CI whose supply chain is pinned") is the planner's or a
  milestone review's call; filed without a milestone.
- `docs/security.md`, the CI boundary.

---

## Outcome

<!-- Written at close, replacing this comment. -->
