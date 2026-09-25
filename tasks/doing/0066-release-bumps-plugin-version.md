---
plan: required
touches: [plugin/.claude-plugin/plugin.json, plugin/commands/release.md]
milestone: m1
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

Planning, first round (the plan is not agreed yet). The planner proposed a rerunnable `peal ship bump VERSION` before `ship tag`, a `release.version-files` setting of `"PATH: FIELD"` items, and 0061's main-write path for the commit. The human answered:
- The pre-push gate gets a new direct shape in this task: a `chore(release): <tag>` commit that only modifies listed files, its content re-derived and compared exactly.
- Formats: JSON, TOML and YAML, not JSON alone.
- `ship tag` refuses when a listed file on main does not hold the version.
- Bump PR still open past the budget: the human asked which is cleaner. The proposal is to stop and rerun `/peal:release <version>` (the bump is a no-op once the files hold the version). Not confirmed yet.
Still open: top-level keys only versus dotted paths for TOML and YAML; the planner's other defaults (value without prefix, subject `chore(release): <tag>`, tag main's tip after the merge, plugin.json left for the v0.2.0 release, marketplace.json untouched, allowed with issues storage, version checks before any write); size (L with three formats), model opus, merge default.

---

## Outcome

