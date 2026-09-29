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

---

## Outcome

Built: every comment in `plugin/` that cited a design.md section for lookup content now
points at the page that holds it:

- config: `docs/reference/configuration.md`
- storage: `docs/reference/storage.md`
- CLI commands (`peal doctor`, `close`, `ship`, `milestone-review`, `decision`,
  `migrate`): `docs/reference/cli.md`, each under its command
- `/peal:next`: `docs/reference/commands.md`
- the task example: `docs/reference/tasks.md` "Frontmatter"
- `migrate.sh`: `docs/migrating.md`

The two dangling pointers were retargeted. `common.sh:17` ("Hostile input") now cites
design.md "Task files" and `docs/security.md`. `githooks.sh:2` ("Hooks") now cites
design.md "Git gates". Comments only; the touched blocks were rewrapped to the files' width.

Beyond the listed scope, and covered by the Done-when line: `decisions.sh:2`,
`migrate.sh:2`, and `ship.test.sh`'s "Races" pointer (now design.md, "Writes onto main").

Left on design.md on purpose, since they cite the why: `doctor.sh:284` ("Peal and Belfry",
the contract), `common.sh:17` and `githooks.sh:2`. The other `docs/design.md` strings in
`plugin/` are test fixtures, not citations. The reviewer confirmed every cited section
exists.

Verification: `tools/lint.sh` passes. `tools/test-all.sh` ran too long for a session to
finish, so CI is its run; nothing but comments changed.

### Reviewer findings not acted on

- "Rewrap edits uncommitted": the reviewer ran while the implementer was still
  committing. Both commits (2eab8f6, c475fb0) are on the branch and the tree is clean.
