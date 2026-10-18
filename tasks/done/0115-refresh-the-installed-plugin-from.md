---
milestone: m3
plan: required
touches: [plugin/templates/launcher, plugin/templates/githook, plugin/templates/launcher.test.sh, plugin/lib/session.sh, plugin/lib/githooks.sh, plugin/bin/peal.test.sh, .peal/peal, docs/design.md, docs/security.md, CONTRIBUTING.md]
size: M
---

# 0115 — Refresh the installed plugin from main in one step; a stale peal-root does not pin old code

## Intent

Peal runs on itself from the installed plugin, built from `main`. Because merges to main do not change the plugin's version, `/plugin` update keeps the cached copy of that version even when it predates tasks merged since. And after a forced reinstall, `.git/peal-root` (written by the stale plugin's SessionStart hook) still points the launcher and the git gates at the old root. Refreshing today takes three manual steps: delete the cache, reinstall, rewrite `peal-root`.

The task makes it one step for a session that needs the latest main. Two routes are on the table: a version that changes with every merge (a prerelease suffix, or the commit embedded in `plugin.json`) so the cache refetches, or the launcher and SessionStart noticing that the recorded root is older than the installed one and moving to the installed one. In either case SessionStart rewrites `peal-root` when the running plugin is newer than the one recorded. The launcher resolves the root in `plugin/templates/launcher`; SessionStart writes it in `plugin/lib/session.sh`. Whatever steps remain get a short refresh recipe in the docs (the contributor guide or `docs/guides/`). The human's own done-when: a harness shows that a `peal-root` recorded by an older plugin does not win over a newer installed plugin, and the refresh recipe is in the docs.

## Scope

- Route B: the launcher and the git-hook stub (one shared finding block) take the highest-version verified Peal root among the recorded `.git/peal-root` and the cache entries; ties or incomparable versions fall back to today's order (recorded root, then newest mtime). The set of roots allowed to run is unchanged.
- SessionStart (`peal_record_root`) and `peal hooks install` never downgrade `peal-root`: they leave a record that names a verified root of a higher version than the running plugin, through one shared helper.
- This repository's `.peal/peal` regenerated from the new template.
- Docs: the new order in `docs/design.md`, the 0040 answer and the newest-wins limits in `docs/security.md`, the refresh recipe in `CONTRIBUTING.md` "Running on itself".
- Out of scope: per-merge versions (route A1), automatic refresh of stale stubs, deleting `peal-root`.

## Done when

- `plugin/templates/launcher.test.sh`, launcher and stub: a recorded 0.1.0 with a cached, listed 0.2.0 runs 0.2.0; a recorded 0.2.0 with a newer-mtime cached 0.1.0 runs the recorded one; equal versions across marketplaces: recorded, then mtime; an unlisted recorded root is skipped; an `.orphaned_at` cache dir is skipped; every existing row stays green.
- `plugin/bin/peal.test.sh`: a newer running plugin overwrites the record; an older one leaves a verified newer record alone; an older one overwrites a newer record that is unlisted, gone or invalid.
- `plugin/lib/githooks.test.sh`: the same rule for `hooks install`.
- `cmp .peal/peal plugin/templates/launcher` is identical.
- The refresh recipe is in `CONTRIBUTING.md`, its commands tried in a scratch `CLAUDE_CONFIG_DIR`; `tools/docs.test.sh` and `tools/lint.sh` pass.

## Raw

> The installed plugin can be refreshed from main in one step, and a stale peal-root does not pin old code
>
> ## Intent
>
> Peal runs on itself from the installed plugin, which is built from `main`. Main changes without a version bump, so `/plugin` update keeps the cached copy of the same version, even when that copy predates the merged tasks. After a forced reinstall, `.git/peal-root`, written by the SessionStart hook of the stale plugin, still points the launcher and the git gates at the old root. Refreshing took three manual steps: delete the cache, reinstall, rewrite `peal-root`. When this is done, a session that needs the latest main gets it in one step: either the cache refetches because the version changes with every merge, or the launcher and SessionStart see that the recorded root is older than the installed one and move to the installed one. The steps that remain are written down in the docs.
>
> ## Scope
>
> - Choose between a version per merge (for example a prerelease suffix, or the commit embedded in `plugin.json`) and the launcher preferring the newest installed root over an older recorded one. The launcher's resolution is in `plugin/templates/launcher`, and SessionStart writes the root in `plugin/lib/session.sh`.
> - SessionStart rewrites `peal-root` when the plugin now running is newer than the recorded one.
> - A short refresh recipe in the docs (the contributor guide or docs/guides/).
>
> ## Done when
>
> - Harness: a `peal-root` recorded by an older plugin does not win over a newer installed plugin.
> - The refresh recipe is in the docs.
>
> ## Raw
>
> > Belfry friction, 2026-09-29 (job eb444c4db4e59762): task 0108 needed the installed plugin refreshed from a main that had 0107. `/plugin` update kept the old 0.2.0 cache, and after a forced reinstall `.git/peal-root` still pinned the launcher and gates to 0.1.0. Workaround: the human deleted the cache, reinstalled and rewrote `.git/peal-root` by hand.
>
> ## Notes
>
> - Related: 0066 (a release bumps the plugin's version), 0088 (launcher drift warning).
> - Open question: does preferring a newer root weaken 0040's guarantees for the launcher? Check this against docs/security.md.
> - Milestone: m3, Smooth sessions.

## Notes

- Related: 0066 (a release bumps the plugin's version: a version per merge has to fit with it), 0088 (launcher drift warning), 0040 (safe hooks and launcher).
- Open question (the human's): does preferring a newer installed root weaken 0040's guarantees for the launcher? Check against `docs/security.md`, which covers 0040.
- Open question: what "newer" means when comparing roots: the plugin version, an embedded commit, or something else. With equal versions (the case that caused this), a version comparison alone cannot tell them apart.
- Context: `docs/design.md` (Peal runs on itself from the installed plugin), `docs/reference/configuration.md`.
- Milestone m3 because the idea names it.
- 2026-10-18, the human, at planning: "one step" means route B plus a recipe in the docs; per-merge versions (A1) are a separate idea. The newest verified root wins even over a deliberate project-scope pin of an older Peal (the limit documented in security.md). `peal hooks install` follows the same no-downgrade rule through a shared helper. Versions compare as numeric dot fields with a prerelease below its release; anything else is incomparable. The cache scan skips `.orphaned_at` directories. Candidates are not limited to the recorded root's marketplace (documented). The recipe goes in CONTRIBUTING.md, including re-running `.peal/peal hooks install`; no automatic stub refresh. Keeping or deleting `peal-root` was left to the session: kept as the tie-break (deleting it touches init, doctor, githooks, many harnesses, and it still covers roots outside the cache).

## Plan

Route B, "prefer the newest verified root".

1. `plugin/templates/launcher` and identically `plugin/templates/githook` (`launcher.test.sh:24` requires the blocks byte-identical): `_peal_find` gathers the recorded root (if `_peal_check recorded` passes) and every cache entry that passes `_peal_check cache` and has no `.orphaned_at`, and takes the highest `plugin.json` version. Comparator: portable awk over numeric dot fields, a `-prerelease` below its release; not `sort -V` (macOS). Ties or incomparable versions: recorded root first, then newest mtime (today's order). `_peal_check` exposes the version it already reads (e.g. `_peal_version`) instead of parsing twice. Header comment updated.
2. `plugin/lib/session.sh` `peal_record_root`: leave the record when it names a verified root (exists, names peal, listed in `installed_plugins.json` when that file exists) whose version is higher than the running plugin's; otherwise write as today. One shared helper.
3. `plugin/lib/githooks.sh:51` `peal_hooks_install` writes `peal-root` through the same helper.
4. Regenerate `.peal/peal` with `PEAL_ROOT=$PWD/plugin plugin/bin/peal init --stage tasks` (as 0098).
5. Docs: `docs/design.md` "Finding Peal's scripts" (595-611) the new order and peal-root as tie-break; `docs/security.md` first boundary (30-55): no weakening of 0040, the set of runnable roots is unchanged, only the choice among verified roots; limits: project-scope pins and other marketplaces' higher versions win; `CONTRIBUTING.md` "Running on itself" (62-68): the refresh recipe (forced reinstall of the pinned version, restart, `.peal/peal hooks install` in existing clones), its commands tried in a scratch `CLAUDE_CONFIG_DIR` as `tools/install.test.sh` does, only what worked written down.

Verification: as `## Done when`; the existing end-to-end block of `launcher.test.sh` (188-203) still passes.

Ranges: plugin/templates/launcher:1-187, plugin/templates/githook:1-30, plugin/templates/launcher.test.sh:21-24, plugin/templates/launcher.test.sh:105-205, plugin/lib/session.sh:1-47, plugin/bin/peal:300-310, plugin/bin/peal:377-392, plugin/bin/peal.test.sh:1-45, plugin/lib/githooks.sh:27-113, plugin/lib/doctor.sh:112-190, plugin/lib/init.sh:269, plugin/lib/init.sh:327, plugin/.claude-plugin/plugin.json:1-11, .claude-plugin/marketplace.json:1-17, .peal/config.yml:15, tools/install.test.sh:1-81, docs/security.md:28-86, docs/security.md:97-104, docs/design.md:595-611, CONTRIBUTING.md:62-68, tasks/done/0098-refresh-committed-launcher.md:42-62. External: Claude Code plugin docs, "Versions and updates" (https://code.claude.com/docs/en/plugins/loading).

Model default; size M; merge default (security boundary).

---

## Outcome

Built route B, as agreed at planning.

- **Launcher and git-hook stub** (`plugin/templates/launcher`, `plugin/templates/githook`, one byte-identical finding block): `_peal_find` now takes the highest `plugin.json` version among the recorded `.git/peal-root` (when it passes `_peal_check recorded`) and every cache entry that passes `_peal_check cache` and has no `.orphaned_at`. Ties and incomparable versions fall back to the old order: recorded root, then newest mtime. The comparator is portable awk (numeric dot fields, a prerelease below its release, anything else incomparable and never winning). `_peal_check` now sets `_peal_version` instead of the version being parsed twice. The set of roots allowed to run is unchanged.
- **The record never downgrades:** `peal_write_root` in `plugin/lib/session.sh` is the one helper SessionStart (`peal_record_root`) and `peal hooks install` (`plugin/lib/githooks.sh`) write `peal-root` through. It keeps a record that names a verified root of a higher version than the running plugin, and writes as before otherwise (record older, unlisted, gone or invalid).
- **`.peal/peal`** regenerated from the new template (`cmp` identical).
- **Docs:** `docs/design.md` "Finding Peal's scripts" has the new order, with `peal-root` kept as the tie-break. `docs/security.md` answers the human's open question: 0040 is not weakened, because only the choice among already-verified roots changes; it states the accepted limits (the newest verified root wins over a deliberate older project-scope pin, and over another marketplace's higher version). `CONTRIBUTING.md` "Refreshing the installed plugin from main" has the recipe: forced reinstall of the pinned version, restart, and `.peal/peal hooks install` in existing clones.

Decided at planning (see Notes): per-merge versions (route A1) are not done here, since they reverse 0066; `peal-root` stays as the tie-break rather than being deleted, because it covers roots outside the cache and deleting it would spread over init, doctor, githooks and many harnesses.

Departures from the plan, made by the implementer and accepted at review:
- `peal_write_root` carries its own shell copy of the version comparator (`_peal_vcmp`, `plugin/lib/session.sh`). The templates can source nothing, so the copy cannot be shared. Nothing pins the two copies together yet: filed as an idea (pin the comparator copies).
- Its "verified" check also requires the recorded root to lie inside the plugin cache, matching the launcher's own check. This is stricter than the plan.
- Its listing check is a quoted-path substring match against `installed_plugins.json` (`grep -F`), not a parse with a version match. It decides only whether a record is kept, never what runs: a kept record that the launcher refuses is skipped with a stderr note, and the launcher falls back to the cache.

For the next session:
- Hook stubs and `.peal/peal` copies installed before this change keep the old order (recorded root first) until `.peal/peal hooks install` is re-run from the updated plugin. The recipe says so.
- The recipe was tried in a scratch `CLAUDE_CONFIG_DIR`, with this checkout as a local-path marketplace. `claude plugin marketplace update` against the real GitHub marketplace was not tried (no network in the sandbox), and `CONTRIBUTING.md` says so.
- Verification: `launcher.test.sh` 99 passed, `peal.test.sh` 21, `githooks.test.sh` 411, `tools/docs.test.sh` 26, `tools/lint.sh` clean.

### Reviewer findings not acted on

- The listing check is weaker than the launcher's path-and-version match. Kept as is, because it only governs keeping a record, and the launcher still verifies what runs.
