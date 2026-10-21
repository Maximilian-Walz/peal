---
plan: skipped
depends: [0150]
touches: [.peal/config.yml]
milestone: m3
---

# 0157 — Turn on pr.security for this repository

## Intent

Set `pr.security: docs/security.md` in this repository's `.peal/config.yml`, so `/peal:close` asks every session here for a `Security:` line naming the boundary of `docs/security.md` its change touches, or `none`. It has to wait until a release carries the `pr.security` key: sessions run the installed plugin, and one older than 0150 refuses the unknown key, which would break every Peal command until the plugin is updated.

## Scope

- `.peal/config.yml`: add `pr.security: docs/security.md`.

## Done when

- `.peal/config.yml` sets `pr.security: docs/security.md`, and `peal config` prints it.
- The installed plugin's commands (`peal work`, `peal close begin`) run with the key set, and `peal close begin` asks for a Security line.

## Raw

> Turn on `pr.security: docs/security.md` in this repository's .peal/config.yml once a release carries the key. Depends on 0150. Found in 0150: an installed plugin older than 0150 refuses the unknown key, so it waits for the release.

## Notes

- Waits on a release that carries 0150, not only on 0150's merge. Check the installed plugin's version before claiming.
- docs/reference/configuration.md (`pr.security`), docs/security.md.

---

## Outcome

`.peal/config.yml` now sets `pr.security: docs/security.md`. From now on `/peal:close` in this repository asks each session for a `Security:` line, naming the boundary of `docs/security.md` the change touches, or `none`. `peal close finish` refuses to run without that line.

The precondition held when this task was claimed. 0150's merge is in the v0.4.0 and v0.5.0 tags. With the key set, the installed plugin ran `peal config`, `peal doctor` and `peal work` without refusing it. This task's own `peal close begin` already asked for the Security line.

The review found nothing. `peal doctor` reports two FAILs in this worktree, and both appear without this change too. One is a version mismatch: the session ran 0.4.0 while 0.5.0 is installed. The other is stale git hooks. A fresh session fixes both, and so does `.peal/peal hooks install`.
