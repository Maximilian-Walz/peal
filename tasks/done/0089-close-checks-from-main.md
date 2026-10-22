---
plan: required
milestone: m4
size: M
touches: [plugin/lib/config.sh, plugin/lib/config.test.sh, plugin/lib/close.sh, plugin/lib/close.test.sh, docs/security.md, docs/design.md, docs/reference/*.md, plugin/commands/close.md]
---

# 0089 — checks.close from the main branch's config

## Intent

`peal close finish` runs `checks.close` from the checked-out `.peal/config.yml`, so a
branch chooses the commands its own close runs. Like the git gates (the
gate-settings-from-main task), it could read them from the main branch's config. Kept
out of 0040 and its split piece because it is not a git hook.

## Scope

`peal close finish` reads `checks.close` from the main branch's tip instead of the work
tree; the commands still run on the branch's tree. A new helper `peal_config_load_ref`
(the name and behaviour 0091 planned) reads a ref's `.peal/config.yml`. Every other
setting close reads stays with the work tree. `worktree-setup` from main is split into
0170 (depends on this one).

## Done when

- A branch that commits `checks.close: []` in its own config is still refused by finish
  while main's check fails, nothing moved or filed (both storages).
- A close check only the branch adds does not run.
- When the branch's `checks.close` differs from main's, finish prints one note naming both.
- Main's check runs in the branch's tree (sees a file only the branch has).
- An invalid or unknown-key `.peal/config.yml` on main makes finish refuse, naming the
  ref, before anything changes; no `.peal/config.yml` on main means no close check.
- `config.test.sh` covers `peal_config_load_ref`: a ref's file, no file (defaults),
  invalid file (status 2 naming `REF:.peal/config.yml`), the work tree's file ignored.
- `docs/security.md` says `checks.close` comes from main, names the tests, and records
  the remaining limit: the main ref is named by the work tree's `remote:`/`main:` (0091).
  `design.md`, `configuration.md` and `cli.md` agree.
- `tools/lint.sh`, shellcheck and the harnesses pass.

## Raw

> `checks.close` in `peal close finish` is a separate idea.

## Notes

Revised 2026-10-22: split: 0170 holds the rest

- Open: depends in practice on the helper the gate-settings-from-main task adds
  (`peal_config_load_ref`); not recorded as `depends` since that task had no number until
  this review filed it as gate-settings-from-main.
- Context: `docs/design.md`.
- Queued in 0040's Outcome (2026-09-25) as "not yet filed" pending a protected-main
  filing path; filed now by the m1 milestone review (0045), which found it never was.
- Human, 2026-10-22, at planning: add `peal_config_load_ref` here (0091 then depends on
  0089 and reuses it); leave the main-name hole (work tree's `remote:`/`main:`) to 0091,
  recorded as a limit in `docs/security.md`; main's config not loading: refuse before
  anything changes, naming the ref; no config on main: Peal's defaults; read the known
  ref, no fetch; print one note line when branch and main differ, then run main's; only
  `checks.close` among close's settings moves (not `pr.security`, `remote`, `main`).
- Human, 2026-10-22: include `worktree-setup` from main, but split it into its own task
  (S, depends on 0089): `peal_config_main_ref`, claim resolves `worktree-setup` from main
  before claiming and refuses when main's config does not load, the same differ note,
  tests in `claim.test.sh` and `store-issues.test.sh`, one sentence each in
  `plugin/commands/setup.md` and `configuration.md` that it runs only once on main.
  Belfry-made worktrees out.

## Plan

Agreed 2026-10-22.

- `plugin/lib/config.sh`: factor the parse-and-merge step (defaults, `yaml-parse.awk` on
  the project text, `config-merge.awk`) out of `peal_config_load`; add
  `peal_config_load_ref REF`, which fills `PEAL_CONFIG` from `git show
  REF:.peal/config.yml`: no file there gives the defaults, a file that does not parse or
  has an unknown key returns 2 with a message naming `REF:.peal/config.yml`.
- `plugin/lib/close.sh` `_peal_close_checks`: read the list in a subshell,
  `checks=$(peal_config_load_ref "$PEAL_MAIN_REF" && peal_config_get checks.close)`, so
  the work tree's `PEAL_CONFIG` stays for the rest of finish. No fetch. Print
  `close: the close checks come from <ref>`; when the work tree's `checks.close` differs,
  print one note naming both, then run main's. Main's config not loading refuses before
  anything changes (the checks run before the idea flush). Update the comments at
  `close.sh:471-472` and the finish contract (`close.sh:487-503`).
- Tests: `plugin/lib/close.test.sh` `finish_cases` on both storages for every close item
  of Done when; `plugin/lib/config.test.sh` for the helper, by sourcing the libs.
- Docs: `docs/security.md` limits (64-68) and "What this milestone leaves open"
  (375-382), plus the main-name limit; `docs/reference/configuration.md:38` ("read from
  the main branch's tip"); `docs/reference/cli.md:507`; a sentence in `docs/design.md`
  near 411-413 or 466; `plugin/commands/close.md:138` only if it names the work tree.
- Verification: the harnesses, `tools/lint.sh`, shellcheck.

Ranges: `plugin/lib/config.sh:1-47`, `plugin/lib/close.sh:21-39`,
`plugin/lib/close.sh:471-542`, `plugin/lib/githooks.sh:132-149`,
`plugin/lib/githooks.sh:185-194`, `plugin/lib/githooks.sh:616-639`,
`plugin/lib/close.test.sh:28-120`, `plugin/lib/close.test.sh:234-265`,
`plugin/lib/config.test.sh:1-85`, `docs/security.md:62-84`, `docs/security.md:375-382`,
`docs/design.md:411-413`, `docs/design.md:455-467`,
`docs/reference/configuration.md:23-39`, `docs/reference/cli.md:500-514`,
`plugin/commands/close.md:133-140`, `tasks/backlog/0091-gate-settings-from-main.md:1-49`,
`docs/milestones/m4.md:1-21`.

---

## Outcome

Built as planned. `peal close finish` now reads `checks.close` from the main branch's tip
(`PEAL_MAIN_REF`, as `peal_branch_base` sets it; no fetch) and runs those commands from
the top of the branch's work tree. A branch can no longer drop or add close checks by
editing its own `.peal/config.yml`.

- `plugin/lib/config.sh`: the defaults-plus-project merge is now `_peal_config_merge`,
  shared by `peal_config_load` and the new `peal_config_load_ref REF`. The new helper reads
  `REF:.peal/config.yml` with `git show`, falls back to Peal's defaults when the file is
  absent, and returns 2 naming `REF:.peal/config.yml` when the file does not parse, has
  an unknown key, or the ref does not exist. 0091 can reuse it.
- `plugin/lib/close.sh` `_peal_close_checks`: it reads main's list in a subshell, so the
  work tree's `PEAL_CONFIG` stays for every other setting finish reads (`pr.security`,
  `remote`, `main` unchanged, as decided at planning). It prints `close: the close checks
  come from <ref>`, and one note naming both lists when the branch's list differs. It
  returns 2 when main's config does not load. The checks still run before the idea flush,
  so a refusal changes nothing.
- Tests: `close.test.sh` `main_checks_cases` (both storages) and `config.test.sh` (the
  helper: ref's file, no file, invalid file, work tree ignored, unknown ref). Docs:
  `security.md` (the new limit entry, naming the tests and the remaining main-ref-name
  hole for 0091), `design.md`, `configuration.md`, `cli.md`. `plugin/commands/close.md`
  needed no change: it names no source for the list.

Verified on the tip after merging origin/main: `config.test.sh` 96/0, `close.test.sh`
1449/0, `docs.test.sh` 37/0, `tools/lint.sh` (shellcheck on 76 scripts, pins, launcher,
`peal check`) clean. The full `tools/test-all.sh` exceeds a session's 600s command limit;
CI runs it.

For the next session: most of the code came in through a session-end `wip:` autosave
(dd18897), which skipped the commit gate's checks. The reviewer re-ran the build and the
tests on the tip instead. 0170 (`worktree-setup` from main) and 0091 (gate settings and
the main ref's name from main) remain; both build on `peal_config_load_ref`.

The reviewer had no findings. One line break in `docs/security.md` was joined after the
review.
