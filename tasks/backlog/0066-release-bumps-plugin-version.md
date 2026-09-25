---
plan: required
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

---

## Outcome

