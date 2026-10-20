---
plan: required
depends: [0150]
touches: [plugin/agents/reviewer.md]
---

# 0158 — The reviewer proposes the boundary for the Security line

## Intent

When a project sets `pr.security`, the reviewer subagent, which runs before `peal close finish`, names in its report the boundary of the threat model it sees the diff touching, or `none`. The session's `--security` line then agrees with it, or the Outcome says why it differs. Today the session alone writes the line, guided only by `close.md`.

## Scope

## Done when

## Raw

> The reviewer proposes or checks the Security line against the diff (planned as a follow-up at 0150's planning, option (b): when `pr.security` is set, the reviewer's report proposes the boundary the diff touches, and the session's line must agree with it or the Outcome says why).

## Notes

- Decided at 0150's planning: no reviewer change in 0150; this is the follow-up.
- Open: is the agreement checked by a script (finish comparing a reviewer line, like `merge-auto`) or left to the prompt? A script check that parses the threat model's guard bullets was rejected at 0150: Peal does not own that format.
- docs/security.md, plugin/agents/reviewer.md, plugin/commands/close.md.

---

## Outcome

<!-- Written at close, replacing this comment. -->
