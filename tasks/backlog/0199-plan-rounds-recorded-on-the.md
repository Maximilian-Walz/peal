---
plan: auto
size: S
depends: []
touches: [plugin/lib/work.sh, plugin/commands/work.md, plugin/lib/config-defaults.yml, docs/reference/cli.md]
milestone: m7
---

# 0199 — Plan rounds recorded on the claim, so a control plane can show round 2 of 3

## Intent

A control plane's plan card wants to say "round k of n" and offer Send back (Belfry's #691 and #663). Peal's `work.md` has no notion of a round: a changed plan is "revise it and ask again". When this is done `peal record ID plan --round K` keeps the count (in the claim's frontmatter or the git directory), a setting such as `plan.rounds: 3` caps it, and after the cap the session stops and asks whether to split or defer. This is what the control plane's plan card, as its issue 42 path delivers it, needs from Peal's side, and nothing in Peal's backlog provides it.

## Scope

- `peal record` takes `--round K`; the round is on the claim and readable through the board or `peal work`.
- `plan.rounds` in the config (default 3) and the stop in `work.md` when the cap is reached.
- The contract line: whichever field carries the round is named so Belfry can read it (file the Belfry side with the plan's choice).

## Done when

- A test records three rounds and the fourth is refused with the split-or-defer question.
- The round is readable without parsing prose.

## Raw

> yes, go ahead with all of it and file those proposals.

## Notes

2026-10-22: Re-plan 2026-10-22: the control plane's #691 (its plan card in the inbox) reads the round from the board; name the field that carries it in the Outcome and keep the name stable, since the control plane reads it.

- Usability review P8. Do not let the round number be anything a session can use to bypass the human's agreement.
- Security: none beyond the consent rule (`merge` is not touched).

---

## Outcome

<!-- Written at close, replacing this comment. -->
