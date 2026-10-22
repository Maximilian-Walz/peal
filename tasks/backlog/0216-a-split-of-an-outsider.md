---
plan: required
priority: high
touches: [plugin/commands/split.md, docs/security.md]
---

# 0216 — A split of an outsider's task keeps origin: outsider on every piece

## Intent

When `/peal:split` (`plugin/commands/split.md`) splits a task, it copies the original's Raw into each piece verbatim and files the pieces with `peal create --part-of`, but nothing carries the original's `origin: outsider` over. A piece of an outsider's task then loses the mark that keeps it under the human's eye: its job can run unattended, its pull request can merge by itself, and since 0164 a piece with `plan: auto` is planned and built on the planner's word alone. The mark should follow the text: `peal create --part-of` itself writes `origin: outsider` onto every piece whose original carries it, instead of trusting split.md to do so.

Ideas queued from an outsider's task's session have the same gap (their text comes from outside, yet they carry no mark); whether they get the mark too is to be decided. `docs/security.md` ("Hostile prose is read, never run") should name this path, or state the limit while it is open.

## Scope

## Done when

## Raw

> A split of an outsider's task keeps origin: outsider on every piece
>
> ## Intent
>
> `/peal:split` (`plugin/commands/split.md`) copies the original task's Raw word for word into each piece and files the pieces with `peal create --part-of`, but nothing carries `origin: outsider` over. So a piece of an outsider's task is no longer marked as external: its job can run unattended, its pull request can merge by itself, and since 0164 a piece with `plan: auto` is planned and built on the planner's word alone. Queued ideas filed from an outsider's task's session are the same: their text comes from outside, but they carry no mark.
>
> ## Scope
>
> - `peal create --part-of` writes `origin: outsider` onto every piece whose origin has it, rather than leaving it to split.md.
> - Decide whether queued ideas from an outsider's task get the mark too.
> - `docs/security.md` ("Hostile prose is read, never run") names this path, or the limit until it is closed.
>
> ## Done when
>
> - A hostile.test.sh case: a part-of filing from an outsider's task carries `origin: outsider`.

## Notes

- Open question: should queued ideas from an outsider's task's session carry `origin: outsider`? Marking every one may be too broad (the session's own findings are not outsider text); not marking lets outside text launder itself through an idea.
- Open question: `--part-of` piece filed with `origin: outsider` should presumably also pass the same `## Plan` / `## Outcome` refusal that `peal create --origin outsider` applies (`peal_text_human_section`), so a split cannot carry a pre-filled Plan into a piece.
- On the issues storage `create --origin outsider` is refused; how a part-of piece of an outsider's issue is marked there needs an answer too.
- `docs/security.md`, "Hostile prose is read, never run": currently says `peal create --origin outsider` and `peal apply` `file` proposals are the only two ways an outsider's text is filed; a split is a third.
- The human set the priority high.

---

## Outcome

<!-- Written at close, replacing this comment. -->
