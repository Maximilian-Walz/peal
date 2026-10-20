---
milestone: m3
plan: required
---

# 0145 — Keep gh's telemetry off for the gh commands agents run from Peal's command markdown

## Intent

Task 0143 made `plugin/bin/peal` export `GH_TELEMETRY=0` (unless the user set it), so every gh Peal starts no longer posts gh's usage event to cafe.github.com. The gh commands an agent runs itself as the command markdown tells it to (`gh pr create` and `gh pr checks` in close.md, the gh calls in setup.md and next.md) do not go through `bin/peal`. They still send that event, and a network filter may deny it. Make those calls telemetry-free too: prefix them with `GH_TELEMETRY=0`, route them through peal subcommands, or accept the behaviour and document it.

## Scope

## Done when

## Raw

> Run the gh commands agents issue from Peal's command markdown with gh's telemetry off. Found in 0143: plugin/bin/peal now exports GH_TELEMETRY=0 (unless set) for every gh Peal starts, but the gh calls an agent runs itself from plugin/commands/*.md (close.md's gh pr create / gh pr checks, setup.md, next.md) bypass bin/peal and still post gh's usage event to cafe.github.com, which a network filter may deny. Either prefix them with GH_TELEMETRY=0, route them through peal subcommands, or accept and document it.

## Notes

- Split off 0143, which is in m3; its Outcome has the evidence that cafe.github.com is gh's telemetry (gh 2.102.0).
- Open question: which of the three ways? A prefix in the markdown is cheap but easy to forget in new commands. Routing through peal keeps a single place.
- Context: `docs/security.md` §"`gh` holds the token".

---

## Outcome

<!-- Written at close, replacing this comment. -->
