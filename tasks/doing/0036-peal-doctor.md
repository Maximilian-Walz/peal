---
milestone: m2
plan: required
size: M
touches: [plugin/lib/doctor.sh, plugin/lib/doctor.test.sh, plugin/lib/fake-gh, plugin/bin/peal, docs/design.md, README.md]
---

# 0036 — peal doctor: what is broken, one fix per problem

## Intent

When Peal does not work in a project, nobody should have to guess why. `peal doctor`
checks the installation and says, per problem, one sentence and one fix, and exits
non-zero when something is broken, so a session or CI can call it.

## Scope

- `peal doctor` checks: the plugin version against the launcher's, `core.hooksPath`,
  `gh auth status` for the issues storage, the config against its schema, a stale
  worktree or claim, the Belfry contract's commands answering.

## Done when

- `peal doctor [CHECK...]` prints ok/FAIL/skip lines with one fix per problem, exits 0 healthy,
  1 on any problem, 2 on usage errors.
- Harnesses cover each broken case and the healthy one (one per storage).

## Raw

Filed as issue #36 (https://github.com/Maximilian-Walz/peal/issues/36); its text is carried over into the sections above.

## Notes

Planning answers from the human (all took the planner's proposed default):

- A1 version: both checks. (a) `.peal/peal` byte-identical to `$PEAL_ROOT/templates/launcher`;
  (b) only once (a) holds, `env -u PEAL_ROOT .peal/peal --version` equals the running version.
- A2 stale: claims that could be released but are still there (verdict `ok`/`deferred`),
  landed claims with dirty or unpushed work, and worktrees git lists as prunable. Not
  remote-only live claims, close sentinels or `refs/reaped/*`.
- A3: every finding is a problem, exit 1 (no warn level).
- A4 CI: `peal doctor [CHECK...]` selects checks; no `--ci` flag, no CI detection.
- A5 config: the value checks live in doctor only; `peal_config_load` and `peal check` untouched.
- A6 belfry: run only `list`, `board`, `offer`, and only when the command is
  `.peal/peal list|board|offer ...`, its words split (never `bash -c`), through the launcher
  only when it is identical to the template; anything else `skip`, not run. No line in
  docs/security.md.
- A7: doctor never fetches; a claim that landed but was never fetched here passing silently
  is accepted.
- A8: `gh auth status` for the issues storage only.
- A9 output: `ok`/`FAIL`/`skip` lines on stdout, each `FAIL` followed by `  fix: ...`, a last
  `doctor: N problem(s)` line; exit 0 healthy, 1 problems, 2 usage / no git repo / no `.peal/`.
- A10: one healthy harness case per storage (files and issues).
- A11/A12: a `peal doctor` subsection in docs/design.md after "Setting up a project", plus the
  README lib list; fixes are worded `.peal/peal ...`.

Departures during the build (the review asked for them here):

- `plugin/lib/fake-gh` gained a `gh auth status` handler (succeeds unless `$FAKE_GH/no-auth`
  exists), so the gh check's issues cases have a shim; outside the planned files, added to
  `touches`.
- `.belfry.yml` is parsed from its top-level `tasks:` block only: yaml-parse.awk refuses the
  whole file on any section outside Peal's subset (this repository's own `docs:` list of
  maps), which made a working contract fail.
- The config load's stderr goes through a temp file, not `$(...)`, so `PEAL_CONFIG` survives
  in the calling shell.

## Plan

**Approach.** New `plugin/lib/doctor.sh`: one function per check, all reporting through one
helper (`ok`, `FAIL` + `fix:`, `skip` + reason). `plugin/bin/peal` sources it, adds a `doctor`
case and a usage entry, and loads the config itself (not through `with_store`), so doctor reports
a bad config instead of exiting 2. Order: `config` first (when it fails, the checks that need it
say `skip ...: the config does not load`), then `version`, `hooks`, `gh`, `claims` (skipped when
`gh` failed on the issues storage), `belfry`. Local refs only, no fetching; `gh auth status` and
the Belfry runs use a timeout (30 s).

- **config**: `peal_config_load`'s refusal (config-merge.awk) becomes the sentence, fix "edit
  `.peal/config.yml` line N"; then values: `storage.kind` in files|issues, `main-writes` in
  push|pr|auto, `sizes` S/M/L positive integers, `stages` only tasks|guardrails|milestones|belfry,
  `release.wait-ci` true|false, `models.*` not empty.
- **version**: (a) byte-compare, fix `.peal/peal init --stage tasks` and commit; (b) resolved
  version, fixes: install the plugin (none found), or start a Claude Code session /
  `.peal/peal hooks install` (another version). Skip (a) when there is no launcher and `tasks`
  is not a recorded stage.
- **hooks**: only when `guardrails` is in `stages`. `core.hooksPath` unset, foreign (install
  chains to the current hooks), stub missing/not executable, stub differs from
  `templates/githook`: fix `.peal/peal hooks install`. Uses `peal_hooks_installed`,
  `_peal_hooks_dir`.
- **gh**: only for `storage.kind: issues`. `gh` missing: install the GitHub CLI; `gh auth
  status` fails: `gh auth login`.
- **claims**: `peal_store_claim_worktrees` + `peal_release_verdict`, local refs. Verdict
  ok/deferred: fix `.peal/peal release ID`; dirty/unpushed on a landed task: commit and push,
  or discard, in PATH, then release; `git worktree list --porcelain` `prunable`: `git worktree prune`.
- **belfry**: skip without `.belfry.yml` or when its backend is not `commands`. Parse
  `tasks.commands` with yaml-parse.awk (confirm it takes `.peal/peal offer "{pool}" --top 10`);
  fill `{pool}` from `pool:`; split words with shell-words.awk; `.peal/peal list|board|offer`
  runs through the launcher (`PEAL_ROOT` unset, timeout) when version (a) passed, else through
  `$PEAL_ROOT/bin/peal` with the same arguments; anything else `skip belfry.<cmd>: not Peal's
  command, not run`. Write commands never run. Shapes: `list` lines `ID state slug ...`,
  `board` lines start with `{`, `offer` only `CANDIDATE`/`MORE`. Non-zero exit, timeout or bad
  shape is a problem; fix `.peal/peal init --stage belfry`, or run the command by hand.

**Files.** Create `plugin/lib/doctor.sh`, `plugin/lib/doctor.test.sh`; modify `plugin/bin/peal`,
`docs/design.md` (subsection after "Setting up a project": checks, output, exit codes),
`README.md` (lib list, status line).

**Verification.** `plugin/lib/doctor.test.sh` under `for_each_awk`, scratch repos via
`task-fixtures.sh`, the fake plugin cache of `plugin/templates/launcher.test.sh`. Healthy: files
project with all four stages; issues project with a `gh` shim. Broken, each asserting exit 1, the
`FAIL <check>` line and its `fix:`: config unknown key, `storage.kind: nope`, `sizes.S: x`;
launcher edited, resolving to another version, finding no Peal; hooksPath unset, foreign, stub
missing, stub stale; gh missing, `auth status` fails; claim landed and present, landed but dirty,
prunable worktree; belfry `list` fails, `board` prints a non-JSON line, non-Peal command skipped
(a marker file must not appear). Structural: several problems (count line, exit 1); `peal doctor
hooks` runs only that; `peal doctor bogus` exits 2; outside a git repo exits 2; broken config
makes dependents skip; guardrails not staged means hooks skip, exit 0. Then `tools/test-all.sh
plugin/lib/doctor.test.sh plugin/bin/peal.test.sh`, `tools/lint.sh`, and
`PEAL_ROOT=$PWD/plugin plugin/bin/peal doctor` here as a smoke test.

**Ranges relied on.** tasks/doing/0036-peal-doctor.md:1-34; docs/milestones/m2.md:1-32;
docs/design.md:56-77, 335-389, 517-575, 640-666, 938-1018; docs/security.md:28-81;
README.md:57-100; plugin/bin/peal:1-62, 256-258, 285-304, 343-357, 391-454;
plugin/templates/launcher:1-187; plugin/lib/githooks.sh:1-112; plugin/lib/config.sh:1-46;
plugin/lib/config-merge.awk:1-85; plugin/lib/config-defaults.yml:1-45;
plugin/lib/claim.sh:19-30, 303-418; plugin/lib/session.sh:8-47, 94-140;
plugin/lib/backlog.sh:55-58; plugin/lib/store-files.sh:1021-1030;
plugin/lib/store-issues.sh:967-971; plugin/lib/init.sh:1-60, 402-466, 588-598;
plugin/lib/yaml-parse.awk:1-15; plugin/lib/test-lib.sh:1-93; tools/test-all.sh:1-40;
plugin/templates/launcher.test.sh.

---

## Outcome

