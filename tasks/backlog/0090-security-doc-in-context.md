---
plan: skipped
touches: [.peal/config.yml]
milestone: m3
---

# 0090 — Add docs/security.md to the project's context documents

## Intent

`.peal/config.yml`'s `context:` list (read by the planner, reviewer and `/peal:idea`) is
`[docs/design.md, README.md]`; `docs/security.md`, the threat model built in 0038, is not
on it. 0038's Outcome flagged this directly: "a milestone review may want it there once
0039-0041 land." They have (0039, 0040, 0041, and their split pieces 0062, 0063, 0065,
0076, 0085 are all done, closing milestone m1). A session touching a security-relevant
boundary should have `docs/security.md` in its brief without having to know to read it.

## Scope

## Done when

## Raw

> For the next session: `docs/security.md` is not in `.peal/config.yml`'s `context:`
> list, so briefs do not point at it; a milestone review may want it there once 0039-0041
> land. — 0038's Outcome

## Notes

- Found by the m1 milestone review (0045), which could not make the change itself: its
  task scope limits it to `peal milestone-state` on the milestone's file only.
- Likely a one-line addition to `.peal/config.yml`'s `context:` list.

---

## Outcome

<!-- Written at close, replacing this comment. -->
