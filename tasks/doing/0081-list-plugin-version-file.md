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
