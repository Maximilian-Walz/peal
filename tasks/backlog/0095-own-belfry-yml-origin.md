---
plan: skipped
depends: [0083]
touches: [.belfry.yml]
---

# 0095 — This repository's own .belfry.yml passes `--origin {origin}` to create

## Intent

Task 0083 taught `peal create` an `--origin outsider|writer` option and `peal init --stage
belfry` writes `--origin {origin}` on the create line, but this repository's own
`.belfry.yml` create line was left without it: `.peal/peal` runs the installed Peal
release, which refuses the unknown option until a release ships it. Once a release
carrying 0083 is installed, add `--origin {origin}` to that line, so Peal's own tasks
filed from outsider text carry the `origin: outsider` mark. Until then Belfry still runs
their filing job, so the gap is safe but the mark is inert.

## Scope

## Done when

## Raw

> This repository's own .belfry.yml create line gains --origin {origin} once a Peal release ships peal create --origin (task 0083). Until then .peal/peal runs the installed release, which refuses the option, so the line was left without it; Peal's own tasks filed from outsider text carry no origin mark until this lands (Belfry still runs their filing job, so it is safe but inert). Depends on the release after 0083 merges.

## Notes

- `depends` names 0083, but the real prerequisite is a release containing it being the
  installed plugin; check the installed version before starting.

---

## Outcome

<!-- Written at close, replacing this comment. -->
