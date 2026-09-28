---
plan: required
---

# 0088 — Warn when the committed launcher differs from the installed one

## Intent

The committed `.peal/peal` is repository content: a branch can replace it, and whatever
runs it (a session, a control plane's contract) then runs the branch's script. No check
inside the launcher can guard against its own replacement. Peal could warn, e.g. at
SessionStart or in `peal check`, when `.peal/peal` differs from the installed plugin's
`templates/launcher`. Filed from 0040's planning, where the human chose to record the
limit in `docs/security.md` and file this.

## Scope

## Done when

## Raw

> A9: The committed launcher .peal/peal is itself repository content: a PR can replace it, and Belfry's contract runs it. No check inside the launcher can protect against that. — "Record limit + idea": record the limit in docs/security.md and file an idea for a warning when .peal/peal differs from the installed template.

## Notes

- Open: where the warning lives (SessionStart, `peal check`, or both), and whether a
  `commit-msg` refusal of a change to `.peal/peal` outside `chore(peal)` is wanted too.
- Context: `docs/design.md` (Distribution).
- Queued in 0040's Outcome (2026-09-25) as "not yet filed" pending a protected-main
  filing path; filed now by the m1 milestone review (0045), which found it never was.

---

## Outcome

<!-- Written at close, replacing this comment. -->
