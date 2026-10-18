---
milestone: m3
plan: required
size: M
depends: [0117]
touches: [plugin/lib/ship.sh, plugin/lib/version-field.awk, plugin/lib/githooks.sh, plugin/lib/*.test.sh, plugin/lib/config-defaults.yml, plugin/bin/peal, plugin/commands/release.md, plugin/templates/decisions.yml, .peal/config.yml, tools/pins.test.sh, docs/reference/*.md, docs/design.md, docs/security.md, docs/guides/releases.md]
---

# 0126 — Release sets the template's Peal SHA after the tag

## Intent

Task 0117 lets `peal ship bump` set the tag in the Get Peal step of
`plugin/templates/decisions.yml`, but the SHA on that line is still set by hand once the
tag exists, and `tools/pins.test.sh` fails until it is. A release commit cannot hold its
own SHA. Add a narrow write after `peal ship tag` that sets the SHA of the tag's commit
on that line, as its own gated commit.

## Scope

- A write after `peal ship tag` and its pre-push gate shape (subject, diff re-derived).
- Docs and tests as for the bump.

## Done when

- After a release, the template's SHA is the tag's commit without a hand edit, and
  `tools/pins.test.sh` stays green.

## Raw

> Follow-up of task 0117 (option D): a narrow write after peal ship tag that sets the template's Peal SHA.

## Notes

- 2026-10-18, the human's answers on the plan:
  - A1: the setting is `release.commit-files`, the command `peal ship pin VERSION`.
  - A2: marked lines (`"PATH: \"TEXT\""`) only; the bare `PATH: FIELD` form is refused.
  - A3: a SHA is an object name exactly as long as `git rev-parse` prints for the tag's
    commit, with no `[0-9A-Za-z]` right before or after it; short SHAs never match.
  - A4: the commit subject is `chore(release): pin <tag>`, checked by the gate before
    the bump case.
  - A5: in `/peal:release` the pin step comes after publish and before wait.
  - A6: the gate checks the tag locally only (no network in pre-push); `peal ship pin`
    checks the remote. The limit is written down in `docs/security.md`.
  - A7: `tools/pins.test.sh`'s failure message names `peal ship pin` instead of a hand
    edit.
  - A8/A9: pre-release tags are accepted, as bump does; pin does not require the
    marked line's `# vX.Y.Z` to match the tag (the settings stay independent).
  - A10: the tagged commit itself still pins the previous SHA, so `pins.test.sh` on a
    checkout of the tag with tags present fails its SHA check; documented, not worked
    around.

## Plan

**Setting.** A new list `release.commit-files`, items in the marked-line form of
`release.version-files` only, with the same PATH and TEXT checks. The marker parsing of
`peal_version_files` (`plugin/lib/ship.sh:65-92`) becomes a shared helper; the
commit-files variant refuses the bare FIELD form. Default `[]` in
`plugin/lib/config-defaults.yml`; Peal's `.peal/config.yml` lists the Get Peal marker of
`plugin/templates/decisions.yml`.

**Edit.** `plugin/lib/version-field.awk` gets a SHA token mode beside `format=line`:
exactly one marked line (the `marked()` logic, `version-field.awk:156-174`, parameterised
by token pattern and boundary class), holding exactly one full-length hex object name
with no alphanumeric neighbour; only that token is replaced, anything else exits 2 with
a message. Wrapper `peal_commit_edit PATH "TEXT" SHA FILE` beside `peal_version_edit`
(`ship.sh:187-208`).

**Command.** `peal ship pin VERSION`, built like `peal_ship_bump` (`ship.sh:590-660`):
`_peal_ship_settings`, the tag present locally and on the remote (`ls-remote`) or
"peal ship tag first", the tag's commit reachable from `<remote>/<main>`, each
commit-file at `<remote>/<main>` edited to `<tag>^{commit}`, written with
`peal_push_main` under `PEAL_MAIN_WRITE_WAIT=merged`, subject `chore(release): pin <tag>`;
status 3 as for bump. All files already at the SHA: "already at <short sha>", exit 0.
Empty setting: "nothing to pin", exit 0. A `pin` case in `peal_ship`
(`ship.sh:868-881`), the usage line in `plugin/bin/peal:278-302`.

**Gate.** In `_peal_pre_push_direct` (`plugin/lib/githooks.sh:242-245`) a
`'chore(release): pin '*` case before `'chore(release): '*`, to `_peal_pre_push_pin`:
the subject names a release tag (the check of `githooks.sh:323-327`), `refs/tags/<tag>`
exists locally (else "git fetch --tags"), the tag's commit is an ancestor of the pushed
commit's parent, and the diff modifies only commit-files, each byte for byte
`peal_commit_edit` of its parent copy with the tag's commit. The header table at
`githooks.sh:161-166` gets the row.

**`/peal:release`.** `plugin/commands/release.md` §3: after publish, before wait, run
`peal ship pin <version>` when `peal config release.commit-files` prints anything;
status 3 reported as the bump's; §5 report.

**Docs.** `docs/reference/cli.md` (`### peal ship pin`, `ship tag` cross-reference),
`docs/reference/configuration.md:49,58-63`, `docs/design.md:435-450`,
`docs/security.md:107-124,265-270` (SHA set by the release; the gate's local-tag
limit), the comment at `plugin/templates/decisions.yml:41-45`, `tools/pins.test.sh:88,93`
messages, optionally `docs/guides/releases.md`.

**Verification.**
- `plugin/lib/ship.test.sh` after 299-331: pin of a fixture SHA after bump and tag (only
  the token changes, to `git rev-parse <tag>^{commit}`); rerun "already at"; refusals
  leaving main unchanged (no tag, marker on no or two lines, no/two SHAs, 41-hex run,
  empty or backslashed marker, FIELD form); empty setting "nothing to pin".
- `plugin/lib/githooks.test.sh` after 363-381: ship pin's commit and the same hand edit
  pass; refused: wrong SHA, pin also changing version or another file, tag missing
  locally, tag not an ancestor of the parent, pin subject without version; bump cases
  still pass, `chore(release): pin vX` not routed to bump.
- `plugin/lib/hostile.test.sh:659-677`: hostile markers in `release.commit-files` write
  nothing.
- Scratch clone: simulate a release of the real template (bump to 0.3.0, tag, pin);
  `bash tools/pins.test.sh` and `tools/pins.sh` green, the SHA check included.
- `PEAL_ROOT=$PWD/plugin plugin/bin/peal config release.commit-files` parses Peal's
  setting; harnesses under every awk (`for_each_awk`); `tools/lint.sh`,
  `tools/docs.test.sh`.

Ranges: `plugin/lib/ship.sh:65-104,187-254,579-732,868-881`,
`plugin/lib/version-field.awk:1-35,156-198`, `plugin/lib/githooks.sh:144-171,227-250,313-375`,
`plugin/templates/decisions.yml:37-49`, `tools/pins.test.sh:78-101`,
`plugin/commands/release.md:50-93`, `.peal/config.yml:14-18,54-61`,
`plugin/lib/config-defaults.yml:39-48`, `plugin/bin/peal:278-302`,
`docs/reference/cli.md:561-616`, `docs/reference/configuration.md:46-63`,
`docs/design.md:435-450`, `docs/security.md:107-124,259-276`,
`docs/guides/releases.md:1-65`, `plugin/lib/ship.test.sh:299-331`,
`plugin/lib/githooks.test.sh:320-382`, `plugin/lib/hostile.test.sh:659-677`,
`tasks/done/0117-release-bumps-template-peal-tag.md:42-160`.
