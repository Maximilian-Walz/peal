---
plan: required
touches: [plugin/lib/work.sh]
---

# 0134 — `peal record` accepts a Raw section added to a task filed without one

## Intent

A task filed without a `## Raw` section is stuck: its plan cannot be recorded through the CLI. Recording the text as it is fails `peal_task_check` ("no '## Raw' section"); adding a Raw section fails `peal_record`'s own check that Raw is unchanged, since it compares against the old text, which has none (`plugin/lib/work.sh:159`). It happened when 0112's plan was recorded, and the session had to commit by hand under record's own subject.

`peal record`, and `peal revise`, which makes the same pair of checks, should accept a Raw section added to a task that had none, and still refuse any change to, or removal of, an existing Raw section. The harness covers both cases.

## Scope

## Done when

## Raw

> `peal record` accepts a Raw section added to a task filed without one
>
> ## Intent
>
> A task filed without a `## Raw` section can never have its plan recorded through the CLI. Without Raw, `peal_task_check` refuses the new text ("no '## Raw' section"). With Raw added, `peal_record` refuses because the Raw section changed (`plugin/lib/work.sh:159` compares against the old text, which has none). Seen when recording 0112's plan; the session committed by hand under record's own subject.
>
> Let `peal record` (and `peal revise`, which has the same pair of checks) accept a Raw section added to a task that had none, while still refusing any change to an existing Raw section.
>
> ## Done when
>
> - `peal record ID plan` on a task without Raw, with a Raw section added, records it.
> - A changed or dropped existing Raw section is still refused, by record and by revise.
> - The harness covers both cases.
>
> ## Notes
>
> - Also worth checking: how a task got filed without Raw in the first place (the create path, or a split piece), and whether create should always write one.

## Notes

- Open question: how did a task get filed without Raw (the create path, a split piece)? Should `peal create` always write one, or refuse a body without it? Check that alongside the fix.
- Open question: what should an added Raw section hold when the task has no human words to quote (a split piece, for example)?
- `docs/reference/tasks.md` (the Raw section: "the human's words and never rewritten") and `docs/reference/cli.md` (record, revise) cover this.
- Milestone left unset. m3's goal ("claim, commit and close without workarounds") is close, but none of its acceptance criteria names this.

---

## Outcome

<!-- Written at close, replacing this comment. -->
