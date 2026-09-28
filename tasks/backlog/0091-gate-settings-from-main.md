---
plan: required
touches: [plugin/lib/config.sh, plugin/lib/githooks.sh]
---

# 0091 — Gate settings from the main branch, not the work tree

## Intent

The git gates take their settings (`checks.commit`, `main`, `tasks`, `milestones`) from the
checked-out `.peal/config.yml`, so a stranger's branch can choose which commands the
commit-msg gate runs, or move `main` so pre-push no longer protects it. `peal githook`
should read `.peal/config.yml` from the main branch's tip instead (remote-tracking ref,
then the local branch, then Peal's defaults), with the remote and main branch names
recorded in git config at `hooks install` so a branch cannot redirect the lookup. Split
from 0040, whose hooks and launcher no longer run what the repository ships.

## Scope

## Done when

## Raw

> Gate settings from the main branch, not the work tree (split from 0040, milestone m1). `peal githook` loads `.peal/config.yml` from the main branch's tip (`git show <ref>:.peal/config.yml`, ref `refs/remotes/<remote>/<main>`, falling back to `refs/heads/<main>`, then Peal's defaults), with `peal.main`/`peal.remote` recorded in git config at `hooks install` so a branch cannot redirect the lookup; new `peal_config_load_ref` in config.sh; removes the "Known limit" comment in githooks.sh. A branch then cannot choose which `checks.commit` commands run nor move `main`. Human answers from 0040's planning: the commands themselves still run the checked-out tree (accepted, documented limit); when main has no `.peal/config.yml` yet, use Peal's defaults. Harness: a branch-only `checks.commit` does not run; a branch's `main:` change cannot open a push to real main. Uninstall also removes `peal.main`/`peal.remote`. `checks.close` in `peal close finish` is a separate idea.

## Notes

- Settled in 0040's planning: the commands still run the checked-out tree (a documented
  limit in `docs/security.md`); with no `.peal/config.yml` on main, Peal's defaults apply.
- Open: with the defaults, the first `/peal:setup` commit with a custom tasks directory
  would be refused by the `chore(peal)` path check until merged. Is that acceptable?
- Open: 0040 records the limit "gate settings come from the work tree" in
  `docs/security.md`; this task removes it again.
- Context: `docs/design.md` (Git gates).
- Queued in 0040's Outcome (2026-09-25) with `milestone: m1`, as "not yet filed" pending
  a protected-main filing path. Filed now by the m1 milestone review (0045), which found
  it never was. Filed here with no milestone rather than m1: this review closes m1 in
  the same task, and a milestone that goes `done` before this queued idea is flushed (at
  0045's own close) would refuse the filing (`task-check.awk`: "milestone m1 is done").
  It splits from an m1 task and is security-relevant (`checks.commit` still trusts the
  work tree); the human may want it in m2 instead of the open backlog.

---

## Outcome

<!-- Written at close, replacing this comment. -->
