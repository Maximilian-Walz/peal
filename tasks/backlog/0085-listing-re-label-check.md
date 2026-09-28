---
milestone: m1
plan: required
touches: [plugin/lib/issues-lib.awk, docs/security.md]
---

# 0085 — Issues storage: re-label check on the listing path too

## Intent

Since 0076, a single-issue read refuses a labelled issue that someone without write
access edited after the labelling. The listing path still admits it: the listing, the
board, the offer and ship's release notes can show a title an outsider edited after
the labelling. Claiming it is refused and its body never leaks, but the title does.
Extend 0076's re-label check (`edit_admitted` in `issues-lib.awk`) to the listing path,
for example with one batched GraphQL query over the labelled issues. Then drop the
narrower known limit from `docs/security.md`.

## Scope

## Done when

## Raw

> Issues storage: the listing, board, offer and ship's release notes still admit a labelled issue whose title an outsider edited after the labelling (claiming refuses it since 0076, and no body leaks). Extend the re-label check of 0076 (edit_admitted in issues-lib.awk) to the listing path, e.g. with one batched GraphQL query over the labelled issues, and drop the narrower known limit from docs/security.md. Milestone m1. Found in 0076.

## Notes

Found in 0076. Open questions:
- What does the extra query cost per listing? It could be one batched GraphQL call, or
  paginated calls for repositories with many labelled issues.
- Should the listing hide such an issue, or mark it as waiting for a re-label?

`docs/security.md`'s "Only admitted issues reach a session" section covers this limit.

---

## Outcome

<!-- Written at close, replacing this comment. -->
