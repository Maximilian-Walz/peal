---
milestone: m3
plan: required
touches: [plugin/templates/launcher, plugin/lib/session.sh]
---

# 0115 — Refresh the installed plugin from main in one step; a stale peal-root does not pin old code

## Intent

Peal runs on itself from the installed plugin, built from `main`. Because merges to main do not change the plugin's version, `/plugin` update keeps the cached copy of that version even when it predates tasks merged since. And after a forced reinstall, `.git/peal-root` (written by the stale plugin's SessionStart hook) still points the launcher and the git gates at the old root. Refreshing today takes three manual steps: delete the cache, reinstall, rewrite `peal-root`.

The task makes it one step for a session that needs the latest main. Two routes are on the table: a version that changes with every merge (a prerelease suffix, or the commit embedded in `plugin.json`) so the cache refetches, or the launcher and SessionStart noticing that the recorded root is older than the installed one and moving to the installed one. In either case SessionStart rewrites `peal-root` when the running plugin is newer than the one recorded. The launcher resolves the root in `plugin/templates/launcher`; SessionStart writes it in `plugin/lib/session.sh`. Whatever steps remain get a short refresh recipe in the docs (the contributor guide or `docs/guides/`). The human's own done-when: a harness shows that a `peal-root` recorded by an older plugin does not win over a newer installed plugin, and the refresh recipe is in the docs.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
