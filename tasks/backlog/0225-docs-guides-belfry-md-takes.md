---
milestone: m9
plan: auto
size: S
depends: []
touches: [docs/guides/belfry.md, plugin/commands/comment.md, .belfry.yml, docs/security.md]
---

# 0225 — docs/guides/belfry.md takes the with-Peal lines the contract drops, and /peal:comment passes {origin} verbatim

## Intent

The control plane's `docs/contract.md` carries Peal's mapping in eight places and three of them are wrong (its #708: `/peal:brief` and `peal done` do not exist yet, `/peal:revise` named where `/peal:comment` is the headless command); it moves every "with Peal" line into Peal's own guide and keeps one link. Separately, `/peal:comment` decides the outsider mark from a header in the quoted text ("From outside (") that no document names; the control plane's #704 gives `tasks.commands.revise` an `{origin}` placeholder so the mark arrives as an argument. When this is done the guide holds the mapping, every command it names exists, and `comment.md` passes the flag verbatim.

## Scope

- `docs/guides/belfry.md`: the full contract Peal writes (`peal init --stage belfry`), with each command's Peal counterpart, phases, the prepare/done/hand_in lines marked as coming with the human-tasks milestone.
- `plugin/commands/comment.md` and `.belfry.yml`'s `revise:` line: `--origin {origin}` passed through; the header rule goes.
- `tools/docs.test.sh` checks every command the guide names exists.

## Done when

- The guide names no command that does not exist (a docs harness check) and shows the whole contract.
- `commands.test.sh` asserts `comment.md` takes the origin from its argument and not from the text.

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Waits for the control plane's #708 and #704. The 0184 (c) item ("the control plane's revise passing {origin}") is done here.
- Security: touches "hostile prose is read, never run": the outsider mark comes from an argument the control plane computed; `docs/security.md` follows.

---

## Outcome

<!-- Written at close, replacing this comment. -->
