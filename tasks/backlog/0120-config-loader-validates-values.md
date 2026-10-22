---
plan: required
---

# 0120 — The config loader refuses invalid values, not only peal doctor

## Intent

From 0036's Outcome: the checks of config values live in `peal doctor` only.
`peal_config_load` and `peal check` still accept, for example, `storage.kind: nope`, so a
bad value surfaces only when a command later trips over it. Move (or share) the value
checks so the loader refuses an invalid value with the same message doctor gives.

## Scope

## Done when

## Raw

> The config value checks live in doctor only. `peal_config_load` and `peal check` still
> accept, for example, `storage.kind: nope`. Moving the checks into the loader would be a
> task of its own. (0036's Outcome, filed by the m2 review, 0046)

## Notes

2026-10-22: Security review finding 10: the loader should validate storage.issues.repo (^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$) and main, remote and branch-prefix (git check-ref-format --branch), since a branch's config reaches gh api paths and git ref names; more severe than its place suggests. The low-findings task of the Main decides milestone links this one.

- Open: whether every command should refuse, or only `peal check` and the gates, since a
  loader refusal stops everything, including `peal doctor` itself.
- Context: docs/reference/configuration.md.

---

## Outcome

<!-- Written at close, replacing this comment. -->
