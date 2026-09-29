---
milestone: m2
plan: required
depends: [0031]
part-of: 0031
---

# 0105 — docs/reference/ and design.md pruned to the why

## Intent

A reader looking something up finds it in `docs/reference/`: the commands, the `peal`
CLI, the configuration keys, the task frontmatter and the storage settings, complete and
terse, with a short "Words" list so the docs use the same words as the commands.
`docs/design.md` keeps the why and loses what moved to the reference. The docs check
that 0031 builds (`tools/docs.test.sh`) grows completeness checks: every key in
`plugin/lib/config-defaults.yml` is in the config reference and back, every subcommand in
`peal --help` is in the CLI reference, every `plugin/commands/*.md` is in the commands
reference.

## Scope

## Done when

## Raw

> - `docs/reference/`: commands, the `peal` CLI, configuration keys, task frontmatter,
>   storage settings; complete and terse, the place to look things up.
> - `docs/design.md`: the why, kept, pruned of what moved to the reference.
> - One voice: short sentences, the same words for the same things as the commands use.

Split from 0031

## Notes

- Agreed in 0031's planning: no word-level enforcement of banned synonyms; a "Words"
  list in the reference instead.
- design.md's examples are the hard part of "every example is exercised": the agreed
  level is the middle one (marked blocks run or load through `<!-- docs-check: run -->`
  / `<!-- docs-check: config -->`, everything else name- and link-validated).
- Size: M, maybe L (design.md is about 1180 lines).

---

## Outcome

<!-- Written at close, replacing this comment. -->
