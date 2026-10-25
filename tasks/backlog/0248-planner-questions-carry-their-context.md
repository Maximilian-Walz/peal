---
plan: skipped
---

# 0248 — Planner questions carry their context and each option's trade-off

## Intent

The questions the planner hands the human (asked through `AskUserQuestion` by
`/peal:work`) are short and to the point, which the human likes, but they arrive
without enough context to answer without rereading the task and the model's last
message. Example: "Should case 2 cover only the snapshot branch, where an index
existed, or also the no-index branch?" with options "Snapshot only (recommended)" and
"Both branches", each with a one-line description of what it does, not what it costs.

Make each question answerable on its own, still briefly:

- a sentence saying what the question is about and where the work stands;
- for each option, its pro and/or con, so the trade-off between the options is plain
  rather than only what each option does.

Possibly both. This matters most under Belfry, where the questions reach the human's
inbox out of any context and are answered "out of nowhere".

## Scope

## Done when

## Raw

> This is a typical way the planner asks a question:
> """
> # Restore path
> Should case 2 cover only the snapshot branch, where an index existed, or also the no-index branch?
> * *Snapshot only (recommended):* Only that branch keeps a snapshot and names its path.
> * *Both branches:* Also make the rm -f of the index fail.
> """
>
> I like that it is straight to the point but I think it is missing some context. Of course I could read the whole ticket again and the last message of the model but I think I'd like to have maybe a sentence of what this is about and where we are or maybe for each option a pro and / or a con for the option. Something that makes me the tradeoff clearer. Maybe also both these things.
> If used trough belfry this gets even more important, since the questions come there really out of context in the inbox and the human has to answer them "out of nowhere". If belfry's question tool needs some changes to better support this (a place for more context or a place for pros and cons / some formatting, color for them) this should be filed there as well.

## Notes

- The current rules push the other way: `plugin/agents/planner.md` (step 7, *Human
  questions*) says "the plan above carries the context they share, so no question
  repeats it", and `plugin/commands/work.md` ("Questions are short") says the shared
  context is said once in the message right before asking, never in a question. This
  task revisits that balance: the plan shown before the questions is long, and under
  Belfry the inbox shows it above the questions but the human still lacks the gist.
- Other places that ask the human through `AskUserQuestion` (the `STATUS: QUESTION`
  path of the implementer in `/peal:work`, and other commands) may want the same rule;
  open question whether this task covers them or only the planner's questions.
- Open question: where the one-sentence context goes. `AskUserQuestion` has only a
  `header`, the `question` and each option's `label`/`description`; the context
  sentence would sit in the question itself (lengthening it past "one or two
  sentences") and the pros/cons in each option's `description`.
- The Belfry half (a place in its question tool for context, or for pros and cons with
  their own formatting) was filed as an idea in Belfry's project, as the human asked;
  Peal must keep working without it (Peal never needs Belfry, `docs/design.md`).

---

## Outcome

<!-- Written at close, replacing this comment. -->
