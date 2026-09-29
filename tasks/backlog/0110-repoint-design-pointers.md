---
milestone: m2
plan: skipped
size: S
depends: [0105]
---

# 0110 — Repoint plugin/ comments at the reference

## Intent

`docs/design.md` was pruned to the why in 0105; the lookup moved to `docs/reference/`.
Comments in `plugin/` that cite a design.md section for what is now in the reference
point at the wrong page. Repoint each to the reference page (or keep design.md where the
why is meant), so a reader lands on the answer.

## Scope

- `plugin/lib/config-defaults.yml:1`, `plugin/lib/doctor.sh:2`, `plugin/lib/store.sh:2`,
  `plugin/lib/close.sh:2`, `plugin/lib/ship.sh:2`, `plugin/lib/review.sh:2`,
  `plugin/lib/next.sh:2`, `plugin/bin/peal:98`, `plugin/commands/next.md:56,86`,
  `plugin/lib/frontmatter.test.sh:14`.
- Two dangling ones, `plugin/lib/common.sh:17` and `plugin/lib/githooks.sh:2`, name a
  section design.md no longer has or never had; fix them the same way.
- Comments only; no behaviour changes.

## Done when

- No comment in `plugin/` cites a design.md section whose content moved to
  `docs/reference/`; `tools/test-all.sh` and `tools/lint.sh` pass.

## Raw

> Filed by 0105's implementer: the stale design.md pointers in plugin/ its scope left
> untouched.
