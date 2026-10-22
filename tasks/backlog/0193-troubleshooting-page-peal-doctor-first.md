---
plan: auto
size: M
depends: []
touches: [docs/troubleshooting.md, docs/faq.md, CONTRIBUTING.md, README.md]
milestone: m8
---

# 0193 — Troubleshooting page (peal doctor first) and an FAQ

## Intent

There is no troubleshooting in the docs at all: `peal doctor` exists for exactly this and is named in the bug template, the CLI reference and the design, but not once in the README, getting-started or the guides. The failures a newcomer will hit are known: the setup branch not merged yet ("a task cannot begin"), `gh` not logged in, the installed plugin stale (the refresh recipe is in CONTRIBUTING, which users do not read), `EnterWorktree` missing (`work.md` has the fallback `cd <path> && claude "/peal:work <id>"`, the docs do not), a foreign `core.hooksPath`, a sandbox that blocks pushes. There is no FAQ either; questions the docs answer only implicitly: does anything merge by itself, does it work without GitHub (ideas and claims yes, close no), can two tasks run at once (yes, worktrees), can I keep my CLAUDE.md (yes), can I work a task myself without subagents, Windows, what happens to teammates when I commit `.claude/settings.json`. When this is done a newcomer who is stuck finds the page.

## Scope

- `docs/troubleshooting.md`: `peal doctor` first, then each failure with the exact message and the fix; the plugin refresh recipe moves here from CONTRIBUTING (CONTRIBUTING links it); quote the unknown-command message of 0136 once it lands.
- `docs/faq.md` (or a README section) with the questions above; answers say what is true today, including that closing needs GitHub.
- The README and getting-started link both.

## Done when

- Both pages exist and are linked from the README and getting-started.
- Their examples pass `tools/docs.test.sh`.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Documentation review, sections 3 and 8.3. Write the page now with today's messages; 0136 updates one entry.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
