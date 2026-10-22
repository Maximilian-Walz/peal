---
plan: auto
size: S
depends: []
touches: [plugin/lib/work.sh, plugin/agents/planner.md, .peal/config.yml, docs/reference/configuration.md]
milestone: m7
---

# 0188 — The planner reads the section of a context document a context entry names, not the whole document

## Intent

The planner is 12 % of spend, about $1.60 a plan: a median plan reads 28 times (1,366 reads and 815 searches over 81 plans), 118 k characters of tool results and 188 k cache-write tokens. The six context documents (`context:` in `.peal/config.yml`) total 139 KB: `docs/design.md` (50 KB) was read 107 times in chunks, `docs/reference/cli.md` (40 KB) 42 times, `docs/security.md` (27 KB) 41 times. `plugin/agents/planner.md` says "read each that bears on the task" and `peal brief` (`plugin/lib/work.sh`) only names the files. When this is done a `context:` entry can name a section and the brief tells the planner to read headings first. A saving of perhaps 30 % of planner spend (about $40 over the sample).

## Scope

- `context:` entries accept `path#Heading`; `peal brief planner` and `peal brief reviewer` print the entry with its section and tell the role to read the headings first and the named section before any other part.
- Peal's own `.peal/config.yml` uses it, and `docs/design.md` loses the migration tables in the docs task of Ready for newcomers (they are history, not planning context).
- `docs/reference/configuration.md` documents the form.

## Done when

- A test: an entry `docs/design.md#Architecture` appears in the brief with its section.
- The config checker accepts the form and refuses a heading that does not exist in the file.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Performance review finding 4. Related: 0135 (the planner gets the issues a task cites; it also found a 19.5 minute hung WebFetch) and the planner-brief idea to carry dependencies' Outcomes: plan together if the plan finds it cheaper.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
