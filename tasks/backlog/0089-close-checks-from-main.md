---
plan: required
---

# 0089 — checks.close from the main branch's config

## Intent

`peal close finish` runs `checks.close` from the checked-out `.peal/config.yml`, so a
branch chooses the commands its own close runs. Like the git gates (the
gate-settings-from-main task), it could read them from the main branch's config. Kept
out of 0040 and its split piece because it is not a git hook.

## Scope

## Done when

## Raw

> `checks.close` in `peal close finish` is a separate idea.

## Notes

- Open: depends in practice on the helper the gate-settings-from-main task adds
  (`peal_config_load_ref`); not recorded as `depends` since that task had no number until
  this review filed it as gate-settings-from-main.
- Context: `docs/design.md`.
- Queued in 0040's Outcome (2026-09-25) as "not yet filed" pending a protected-main
  filing path; filed now by the m1 milestone review (0045), which found it never was.

---

## Outcome

<!-- Written at close, replacing this comment. -->
