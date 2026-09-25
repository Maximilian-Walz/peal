---
milestone: m1
plan: required
part-of: 0039
touches: [plugin/agents/*.md, plugin/commands/*.md, plugin/commands/commands.test.sh]
---

# 0063 — Outsider text reaches prompts only as quoted data

## Intent

Where text from issues, comments or pull requests reaches a command or agent prompt, it
must arrive as quoted data, never as instructions: only the human's answers direct a
session.

## Scope

## Done when

## Raw

> [...] and into prompts. On a public repository some of that text comes from strangers.
> None of it may be executed, written where it does not belong, or reach a prompt as
> anything but quoted data.

Split from 0039

## Notes

- 0039's planner proposed: a short fixed paragraph in each of `plugin/commands/*.md`
  and `plugin/agents/*.md` that reads issue, comment or PR text (work, close, setup,
  milestone-review, drift; planner, reviewer), and a check in
  `plugin/commands/commands.test.sh` that each such prompt carries it.
- Unclear: the exact list of prompts that read outsider text; the wording.
- Size estimate: S or M.

---

## Outcome

<!-- Written at close, replacing this comment. -->
