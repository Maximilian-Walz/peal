---
milestone: m1
plan: skipped
size: S
depends: [0066]
touches: [.peal/config.yml]
---

# 0081 — Peal's config lists its plugin.json as a version file

## Intent

0066 gave `/peal:release` the setting `release.version-files`, but Peal's own `.peal/config.yml` could not list its `plugin/.claude-plugin/plugin.json` there: the installed plugin (0.1.0) refuses the unknown key, which breaks every Peal command, the commit gate included. When this is done, once the installed plugin has been refreshed from a main holding 0066, Peal's config lists the file, so the v0.2.0 release bumps the plugin's version and `claude plugin update` picks it up.

## Scope

- Only after the human has refreshed the installed plugin by hand (reinstalled, or its cache cleared) so that it knows `release.version-files`; before v0.2.0 is released.
- Add under `release:` in `.peal/config.yml`: `version-files: ["plugin/.claude-plugin/plugin.json: version"]`.
- `plugin/.claude-plugin/plugin.json` stays at 0.1.0; the v0.2.0 release bumps it.

## Done when

- `peal config release.version-files` (the installed plugin) and `PEAL_ROOT=$PWD/plugin plugin/bin/peal config release.version-files` both print `plugin/.claude-plugin/plugin.json: version`.
- A Peal command such as `peal board` still runs with the line in place.

## Raw

Left out of 0066 (the human agreed): the installed plugin rejects the key until it is refreshed, and the cache refreshes only on a version change.

---

## Outcome

Peal's `.peal/config.yml` now has a `release:` block. Its `version-files` lists
`plugin/.claude-plugin/plugin.json: version`, so `/peal:release` bumps the plugin's
version with the release, and `claude plugin update` then picks the new version up.
`plugin.json` stays at 0.1.0; the v0.2.0 release bumps it.

The precondition was met during this session. At first the installed plugin (cache
0.1.0) refused the key with `unknown setting release.version-files`. The human refreshed
the installed plugin by hand, and after that it accepted the key.

Checked: `peal config release.version-files` and `PEAL_ROOT=$PWD/plugin plugin/bin/peal
config release.version-files` both print `plugin/.claude-plugin/plugin.json: version`, and
`peal board` still runs. The reviewer found nothing.

For the next session: every clone's installed plugin has to be as new as 0066 before it
can read this config. A machine still on the old cached 0.1.0 gets the "unknown setting"
error from every Peal command until it reinstalls the plugin.
