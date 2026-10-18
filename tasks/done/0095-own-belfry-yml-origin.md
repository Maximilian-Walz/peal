---
plan: skipped
depends: [0083]
touches: [.belfry.yml]
milestone: m3
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

- `.belfry.yml`: the `tasks.commands.create` line gains `--origin {origin}`, as
  `peal init --stage belfry` writes it.

## Done when

- The installed Peal release accepts `peal create --origin`.
- `.belfry.yml`'s create line ends in `--origin {origin}`.

## Raw

> This repository's own .belfry.yml create line gains --origin {origin} once a Peal release ships peal create --origin (task 0083). Until then .peal/peal runs the installed release, which refuses the option, so the line was left without it; Peal's own tasks filed from outsider text carry no origin mark until this lands (Belfry still runs their filing job, so it is safe but inert). Depends on the release after 0083 merges.

## Notes

- `depends` names 0083, but the real prerequisite is a release containing it being the
  installed plugin; check the installed version before starting.

---

## Outcome

This repository's `.belfry.yml` create line now ends in `--origin {origin}`, the same
line `peal init --stage belfry` writes (`plugin/lib/init.sh`). Belfry's filing job for
tasks made from outsider text now passes the mark through, so those tasks carry
`origin: outsider`.

The prerequisite held: the installed plugin, which `.peal/peal` runs, is v0.2.0. It
includes 0083, and its usage lists `create --owner OWNER --title TITLE [--origin
outsider|writer]`. The installed release was tried in a scratch clone, never in this
repository. It accepted `--origin outsider`: the command did not refuse it as unknown,
and it stopped later, at the pull request, because the clone has no GitHub remote. So
nothing was filed. The written `origin:` field itself was not observed, because 0094
covers it.

There are no docs to update: `docs/design.md` already shows the line with `--origin`,
and `docs/milestones/m3.md` already says this repository passes it. The review found
nothing. No ideas were filed.
