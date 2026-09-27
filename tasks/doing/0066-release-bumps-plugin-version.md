---
plan: required
touches: [plugin/lib/ship.sh, plugin/lib/version-field.awk, plugin/lib/githooks.sh, plugin/lib/config-defaults.yml, plugin/lib/*.test.sh, plugin/commands/release.md, plugin/bin/peal, .peal/config.yml, docs/design.md]
milestone: m1
size: L
model: opus
---

# 0066 — Releasing Peal itself bumps the plugin's version

## Intent

Claude Code caches a plugin under its version: while `plugin/.claude-plugin/plugin.json` says 0.1.0, `claude plugin update` fetches nothing new, so Peal's users (and the worker running Peal's own tasks) keep an old snapshot. When this is done, a Peal release sets that version to the release's, so an update picks it up, in one step.

## Scope

- `/peal:release` gains a project hook for files to update with the version before tagging (a config key such as `release.version-files`, each with the field to set), and Peal's own config lists `plugin/.claude-plugin/plugin.json`.
- On a protected main, the version change goes through 0061's pull-request path before the tag.

## Done when

- A harness releases a scratch project with a version file and finds the tag on a commit that has the new version.
- Peal's own config lists its plugin.json.

## Raw

From a review of how Peal's changes reach its users: the marketplace entry points at main, the cache at the version.

## Notes

Depends on 0061 for protected mains; the hook itself does not.

The human's answers while planning:
- The pre-push gate gets a new direct shape in this task: a `chore(release): <tag>` commit that only modifies listed files, its content re-derived and compared exactly.
- Formats: JSON, TOML and YAML, not JSON alone. Top-level keys only (JSON at object depth 1, TOML before the first `[table]`, YAML at column 0); dotted or nested paths are refused.
- `ship tag` refuses when a listed file on main does not hold the version.
- A bump PR still open past the budget: the release stops and reports it; rerunning `/peal:release <version>` finds the files at the version and tags.
- The planner's other defaults, all accepted: items are `"PATH: FIELD"` strings; the value is the version without the tag prefix (`0.2.0`, `0.2.0-rc.1`); a separate `ship bump` step; subject `chore(release): <tag>`; tag main's tip after the merge, once the files hold the version; release.md and design.md reworded where they say the release writes nothing; `plugin/.claude-plugin/plugin.json` stays at 0.1.0 for the v0.2.0 release to bump; `.claude-plugin/marketplace.json` untouched; allowed with the issues storage (its `main-writes` warning reworded); the version checks of `tag` (above the last release) run in `bump` before any write.
- Size L, model opus, merge default.
- While building: the installed Peal (0.1.0) refuses the unknown key `release.version-files`, so the working line in `.peal/config.yml` would break every Peal command, here and on main. The human chose: 0066 closes without that line (only its commented default); after the merge the human refreshes the installed plugin by hand, and a small follow-up adds the line before the v0.2.0 release. Done when #2 moves to that follow-up.

## Plan

**Setting.** `release.version-files: []` in `plugin/lib/config-defaults.yml`; each item a string `"PATH: FIELD"`, the shape of `checks.commit`. Peal's `.peal/config.yml` sets `release: {version-files: ["plugin/.claude-plugin/plugin.json: version"]}`, and its commented defaults block gains the line.

**Field editor.** One awk editor (`plugin/lib/version-field.awk`) shared by ship and the gate: given the format (by extension: `.json`, `.toml`, `.yml`/`.yaml`), the field and the value, it rewrites the top-level field's string value and nothing else. JSON: the key at object depth 1 holding a string. TOML: `field = "..."` before the first `[table]`. YAML: `field: ...` at column 0, plain or quoted scalar, quoting kept. Refused (status 2, nothing written): unknown extension, field missing, value not a plain string, field present more than once. No runtime jq.

**`peal ship bump VERSION`.** A new rerunnable step between the question and the tag:
- the same refusals as `ship tag` for the version (not above the last release) before anything is written;
- reads each listed file from `$PEAL_REMOTE/$PEAL_MAIN` with `git show`, edits it, and builds one commit with `peal_push_main`/`peal_write_tree`, subject `chore(release): <tag>`, `PEAL_MAIN_WRITE_WAIT=merged`, so a protected main goes through 0061's PR and returns once it merged;
- every file already at the version: prints `already at <version>` and succeeds, no commit;
- status 3 (PR still open past the budget) is passed on; no tag.
- config items are checked: a path with `..`, a leading `-` or absolute, or a field with characters outside `[A-Za-z0-9_-]` is refused.

**`ship tag`.** Refuses when a listed file on the remote main does not hold the version, with a hint to run `peal ship bump`. Tags main's tip after the merge. The notes leave the `chore(release)` commit out.

**Pre-push gate** (`plugin/lib/githooks.sh`). A new direct shape: a single-parent commit, subject `chore(release): <prefix>X.Y.Z[-pre]`, that only modifies (M, 100644) paths listed in `release.version-files`; for each, re-run the field editor on the parent's blob with the subject's version and require the new blob byte for byte.

**Commands and docs.** `plugin/commands/release.md` section 3: first `peal ship bump <version>` when `peal config release.version-files` is not empty; a refusal stops the release; an open PR stops it with the rerun hint; the report names the bump commit or PR; the description and the "writes no task file" line reworded. `plugin/bin/peal` help and `peal_ship` dispatch gain `ship bump`. `docs/design.md` "Releases", the settings block and the pre-push shapes; the issues storage's `main-writes` warning reworded.

**Verification.**
- `plugin/lib/ship.test.sh`, a `bump` case: a scratch project with `version-files` naming a JSON, a TOML and a YAML file at 0.1.0; `ship bump 0.2.0` then `ship tag 0.2.0`: `git show v0.2.0:<file>` holds 0.2.0 in each, the tag's commit is `chore(release): v0.2.0` and its diff only the version lines (Done when #1). A rerun of bump says `already at`, no commit; `tag` without `bump` refused with the hint; missing file, missing field, nested-only field, non-string value, unknown extension refused with main unchanged; the notes leave the bump commit out; a project without `version-files` releases as before.
- Protected main, main-write.test.sh's `protected` pattern: the bump goes through PR #1, merged, the tag on the merged commit; with `PEAL_MAIN_WRITE_BUDGET=0` and pending checks, status 3, no tag, and a rerun after the merge tags.
- `plugin/lib/githooks.test.sh`: a bump commit pushed directly passes; refused: an extra file, a listed file changed beyond the field, a subject version differing from the one written, a path not listed.
- `plugin/lib/config.test.sh`: the default; `init.test.sh` "every default shown" passes.
- `plugin/lib/hostile.test.sh`: `ship bump VERSION` with hostile values and hostile config items.
- Done when #2: `PEAL_ROOT=$PWD/plugin plugin/bin/peal config release.version-files` prints `plugin/.claude-plugin/plugin.json: version`.
- `tools/lint.sh` and shellcheck clean.

**Ranges relied on.**
- tasks/doing/0066-release-bumps-plugin-version.md:1-35
- docs/milestones/m1.md:1-25
- plugin/commands/release.md:1-69
- plugin/lib/ship.sh:27-48, 326-365, 499-511
- plugin/lib/ship.test.sh:28-99
- plugin/lib/main-write.sh:55-127, 137-207, 291-337
- plugin/lib/main-write.test.sh:25-52, 131-140
- plugin/lib/githooks.sh:113-270
- plugin/lib/config.sh:29-46
- plugin/lib/config-defaults.yml:17-43
- plugin/lib/config.test.sh:13-45
- plugin/lib/init.sh:81
- plugin/lib/hostile.test.sh:225-241, 431-436
- plugin/lib/github.sh:75-78
- plugin/bin/peal:206-222
- .peal/config.yml:1-55
- plugin/.claude-plugin/plugin.json:1-11
- .claude-plugin/marketplace.json:1-17
- docs/design.md:497-597, 807-852, 871-887

---

## Outcome

