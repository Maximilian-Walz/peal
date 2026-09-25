---
milestone: m2
plan: required
---

# 0036 — peal doctor: what is broken, one fix per problem

## Intent

When Peal does not work in a project, nobody should have to guess why. `peal doctor`
checks the installation and says, per problem, one sentence and one fix, and exits
non-zero when something is broken, so a session or CI can call it.

## Scope

- `peal doctor` checks: the plugin version against the launcher's, `core.hooksPath`,
  `gh auth status` for the issues storage, the config against its schema, a stale
  worktree or claim, the Belfry contract's commands answering.

## Done when

- Harnesses cover each broken case and the healthy one.

## Raw

Filed as issue #36 (https://github.com/Maximilian-Walz/peal/issues/36); its text is carried over into the sections above.

## Notes

---

## Outcome

