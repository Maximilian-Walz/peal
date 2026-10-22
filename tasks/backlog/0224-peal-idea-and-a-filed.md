---
milestone: m9
plan: auto
size: S
depends: []
touches: [plugin/commands/idea.md, plugin/lib/store-files.sh, docs/guides/belfry.md]
---

# 0224 — /peal:idea and a filed idea's milestone follow one rule under the control plane

## Intent

Two rules decide a newly filed idea's milestone under the control plane (its #706): `/peal:idea` sets `milestone:` itself (the current milestone, on direct evidence) and sends the whole text to `task_create`, while the control plane asks the filing session to propose a milestone and files a `move` card when `apply_kinds` names `move`; now that Peal's contract names it, both run on one task. When this is done Peal follows the rule #706 states: either `task_create` carries the milestone and the card is the human's override, or the create command never takes `milestone` from the text and the proposal is the one decision.

## Scope

- `plugin/commands/idea.md` (the control-plane branch) and, if the rule says so, `peal create`'s handling of `milestone:` in stdin text (as the control plane's #486 keeps `merge`, `origin` and `owner` out).
- `docs/guides/belfry.md` and `docs/reference/tasks.md` follow.

## Done when

- A harness case for whichever side the rule puts on Peal.
- Filing an idea under the control plane leads to exactly one milestone decision (checked once live, noted in the Outcome).

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Waits for the control plane's #706. 0173 (fields as labels on the issues storage) is the sibling for the issues storage. The control plane's #486 keeps `merge`, `origin` and `owner` out of a create's standard input; the same rule may cover `milestone`.
- Security: the milestone stays the human's decision either way.

---

## Outcome

<!-- Written at close, replacing this comment. -->
