---
plan: required
milestone: m4
---

# 0136 — An unknown command names the Peal that ran it and points at the refresh

## Intent

When the CLI is given a command it does not know, the error today says only "unknown command 'X'" and the usage. That sends a session looking for a missing feature when the real cause is often a stale installed plugin: Belfry's `tasks.commands.defer` ran `.peal/peal depend 0129 0123` and got exit 2, although `peal depend` has existed since 0064, because the launcher picked the installed plugin, still 0.2.0 in the cache and older than 0064 (main's `plugin.json` also still says 0.2.0).

On an unknown command, the CLI should say which Peal ran it: its root and its version, next to the usage. When the repository's own `plugin/` or its config expects a newer Peal than the one running, it should say that as well and point at the refresh recipe 0115 wrote.

## Scope

## Done when

## Raw

> An unknown command names the Peal that ran it and points at the refresh
>
> ## Intent
>
> Belfry's `tasks.commands.defer` ran `.peal/peal depend 0129 0123` and got "unknown command 'depend'" (exit 2). `peal depend` has existed since 0064. The launcher ran the installed plugin, which is still 0.2.0 in the cache: it predates 0064, and main's `plugin.json` still says 0.2.0. So the error sent the session looking for a missing feature when the real cause was a stale installation.
>
> When the CLI meets an unknown command, say which Peal ran it (root and version). When the repository's own `plugin/` or config expects a newer Peal, say so too, and point at the refresh recipe from 0115.
>
> ## Done when
>
> - `peal nosuchcommand` names the running root and version, along with the usage.
> - A harness case with an older installed root shows the refresh hint.
>
> ## Notes
>
> - Human step today, outside this task: refresh the installed plugin on this machine (0115's recipe), or release, so that `depend` runs.

## Notes

2026-10-22: Usability review F4: the short --help and the 'did you mean' belong in the same change as this message; see the small usability fixes task of Ready for newcomers.

2026-10-21: 2026-10-21, from a release session's friction: `/peal:release 0.5.0` ran `peal ship bump` with an installed plugin at v0.2.0 while main was at v0.4.0+. The old CLI refused main's own `release.version-files` entry (the quoted-marker form from 0117/0127) and stopped with status 2, and nothing told the session its plugin was stale. The workaround, with the human's approval, was `PEAL_ROOT=$PWD/plugin plugin/bin/peal` on a checkout equal to origin/main. So staleness also shows up as config syntax the running CLI does not know, not only as an unknown command. The planner should weigh a warning at session start or in `peal ship` whenever the installed version is older than main's `plugin.json`, or when a config value fails to parse. This fits next to 0120, where the config loader refuses invalid values.

- The human's own "Done when" (in Raw) is the starting point for the planner: the running root and version printed with the usage; a harness case with an older installed root showing the refresh hint.
- Open question: what counts as "expects a newer Peal"? The checkout's `plugin/.claude-plugin/plugin.json` version only exists in Peal's own repository; other projects may pin a version or SHA in `.peal/config.yml` (see the deferred 0130, config pins the template's SHA). With main's `plugin.json` still at 0.2.0, a version comparison alone would not have caught this case: the comparison may need something beyond the version number, or a release first.
- The launcher and `peal_write_root` already carry version comparators (0115; 0125 is filed to pin the copies together); reuse rather than add a third copy.
- The refresh recipe lives in `CONTRIBUTING.md`, "Refreshing the installed plugin from main" (0115). A hint shown in other projects may need a recipe that is not in a contributor document.
- The unknown-command error is raised in `plugin/bin/peal` (`peal_err "unknown command ..."`).
- Human step outside this task: refresh the installed plugin on this machine (0115's recipe), or release, so that `depend` runs.
- Context: `docs/design.md` ("Finding Peal's scripts"), `docs/reference/cli.md`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
