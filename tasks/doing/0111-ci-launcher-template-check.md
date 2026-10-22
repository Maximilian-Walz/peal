---
plan: required
milestone: m4
size: S
touches: [tools/lint.sh, tools/lint.test.sh, CONTRIBUTING.md, docs/security.md]
---

# 0111 — CI checks the committed launcher against its template

## Intent

The committed `.peal/peal` fell behind `plugin/templates/launcher` unnoticed until a
smoke run found it (task 0098 refreshed it). CI should fail when the two differ, so the
launcher cannot drift again. Only the launcher comparison of `peal doctor version`
belongs in CI: its other check, the installed plugin's version against the running one,
has no meaning on a CI runner.

## Scope

- A `lint: launcher` step in `tools/lint.sh` (and its header comment): `cmp -s .peal/peal
  plugin/templates/launcher`, failing when they differ or `.peal/peal` is missing.
- Harness cases in `tools/lint.test.sh`.
- One line in `CONTRIBUTING.md` (what lint runs) and one sentence in `docs/security.md`
  (CI catches drift between the two in-tree copies; it does not guard against a branch
  replacing both).
- Not in scope: `plugin/`, `peal doctor`, `.github/workflows/ci.yml`, the git hook stubs,
  `docs/design.md`.

## Done when

- `tools/lint.sh` exits non-zero and names the fix when `.peal/peal` is not byte-identical
  to `plugin/templates/launcher`, or is missing.
- It is silent about the launcher when they match.
- `tools/lint.test.sh` proves both.
- CI's `shellcheck` job runs it.

## Raw

> CI runs the launcher check of `peal doctor version` (committed .peal/peal byte-identical to plugin/templates/launcher), so the committed launcher cannot fall behind the template again. Found in 0098, whose Notes raised it as an open question; the full `doctor version` also compares the installed plugin version, which CI cannot, so the check needs just the launcher comparison.

## Notes

- Found in task 0098, where it was an open question.
- Open question: a plain `cmp` step in CI, or a launcher-only mode of `peal doctor`
  (which would touch `plugin/`)?
- 2026-10-22, the human's answers while planning:
  - Where: `tools/lint.sh` (CI, local and close), not a `ci.yml` step nor a `peal doctor`
    mode.
  - At close: intended; a task that changes `plugin/templates/launcher` refreshes
    `.peal/peal` in the same PR.
  - Missing `.peal/peal`: fail.
  - `docs/security.md`: add the one sentence.
  - CI job keeps the name `shellcheck`; `ci.yml` is not touched.
  - `docs/design.md`: no change. Hook stub: not compared. Milestone: stays m4.

## Plan

Add a step to `tools/lint.sh` after `tools/pins.sh` and before `peal check`: print
`lint: launcher`, run `cmp -s .peal/peal plugin/templates/launcher`, and when they differ
or `.peal/peal` is missing print to stderr `lint: .peal/peal differs from
plugin/templates/launcher; refresh it with PEAL_ROOT=$PWD/plugin plugin/bin/peal init
--stage tasks and commit it` and set `status=1`. Name the step in the header comment.
`--list` still exits before it.

Files: `tools/lint.sh`, `tools/lint.test.sh`, `CONTRIBUTING.md` (lines 50-52),
`docs/security.md` (lines 90-98).

Verification:
- `tools/lint.test.sh`, in a scratch git repo running the full `bash tools/lint.sh` and
  asserting only on the launcher lines and the exit status: (a) identical, no `differs`
  line; (b) one byte appended to `.peal/peal`, the line and a non-zero exit; (c) no
  `.peal/peal`, the line and a non-zero exit. The existing `--list` cases stay green.
- In the real tree `tools/lint.sh` exits 0 and `tools/docs.test.sh` passes; CI's
  `shellcheck` job is green.
- By hand: append a byte to `.peal/peal`, `tools/lint.sh` fails; revert.

Ranges relied on:
- tasks/done/0088-launcher-drift-warning.md:41-127
- docs/milestones/m4.md:1-20
- .github/workflows/ci.yml:18-35, 216-222
- tools/lint.sh:1-38
- tools/lint.test.sh:1-48
- tools/ci-changes.sh:1-38
- plugin/lib/session.sh:178-184
- plugin/lib/doctor.sh:116-156
- plugin/lib/init.sh:269
- .belfry.yml:52-133
- .peal/config.yml:15
- docs/security.md:90-98
- docs/design.md:368-370
- CONTRIBUTING.md:47-52
