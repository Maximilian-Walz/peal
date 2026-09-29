---
plan: required
touches: [plugin/lib/ship.sh, docs/reference/configuration.md]
---

# 0117 — Release bumps the template's Peal tag

## Intent

Let `release.version-files` reach more than a top-level field of a JSON, TOML or YAML
file: a nested YAML field or a marked line. Then `peal ship bump` can set the Peal tag in
the Get Peal step of `plugin/templates/decisions.yml` at release time. Today that pin is
updated by hand after each release, and `tools/pins.test.sh` fails the first pull request
that runs the harnesses until someone does it. A release commit still cannot set a SHA
for itself, so this only shortens the lag for the tag, not for the SHA.

## Scope

## Done when

## Raw

> Extend release.version-files to reach a nested YAML field or a marked line, so peal ship bump can set the Peal tag in plugin/templates/decisions.yml's Get Peal step at release time. Today tools/pins.test.sh (task 0069) fails the first harness-running PR after each release until the template's Peal SHA and tag are updated by hand; a SHA still cannot be set by the release commit itself, so this narrows the lag only for the tag. Touches plugin/lib/ship.sh, docs/reference/configuration.md, the chore(release) gate.

## Notes

- Filed from task 0069, which pinned the template's Peal fetch to v0.2.0's commit.
- Open question: the pin is a SHA with the tag in a comment. If the release sets only the
  tag, the SHA and the tag disagree until the SHA is updated by hand. Is a tag-only bump
  worth that, or should the pin take another form (for example the tag plus a check of
  the SHA)?
- The chore(release) gate lets the bump commit touch only version files and the
  changelog (`docs/design.md`); `docs/reference/configuration.md` documents
  `release.version-files`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
