---
milestone: m4
plan: required
depends: [0089]
part-of: 0089
---

# 0170 — worktree-setup from the main branch's config

## Intent

`peal claim` runs `worktree-setup` from the `.peal/config.yml` of the checkout where it
was typed, which may hold a stranger's branch, so a branch chooses a command that runs on
the human's machine. Read it from the main branch's tip instead, with the
`peal_config_load_ref` helper 0089 adds; the command still runs in the new worktree.

## Scope

## Done when

## Raw

> `peal close finish` runs `checks.close` from the checked-out `.peal/config.yml`, so a
> branch chooses the commands its own close runs. Like the git gates (the
> gate-settings-from-main task), it could read them from the main branch's config.

Split from 0089

## Notes

- Agreed with the human at 0089's planning (2026-10-22): add `peal_config_main_ref`
  (remote-tracking `<remote>/<main>`, else the local branch, else nothing: the
  defaults); no fetch; `_peal_claim_one` resolves `worktree-setup` from main before
  `peal_store_takeover`/`peal_store_claim` and refuses with nothing changed when main's
  config does not load; `--next` resolves it once; print one note line when the invoking
  checkout's `worktree-setup` differs from main's; `_peal_claim_setup` otherwise
  unchanged. Belfry-made worktrees stay out.
- Tests: `plugin/lib/claim.test.sh` `worktree_setup` (its config must now be published
  to main), and a case in `plugin/lib/store-issues.test.sh` (issues storage, untested
  for setup so far); refusal on both storages.
- Docs: one sentence each in `plugin/commands/setup.md` (around 221-224) and
  `docs/reference/configuration.md` that `worktree-setup` runs only once it is on main;
  `docs/security.md` and `docs/reference/cli.md` (406-407) updated.
- An issues resume takes the local `issue/ID` without a fetch, so main may be stale
  there; accepted (known ref, no fetch).
- Size estimate: S (about 50 tool calls, mostly test churn).

---

## Outcome

<!-- Written at close, replacing this comment. -->
