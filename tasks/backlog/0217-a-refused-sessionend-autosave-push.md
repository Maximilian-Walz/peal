---
plan: required
milestone: m7
---

# 0217 — A refused SessionEnd autosave push is reported, not only logged

## Intent

When the SessionEnd hook's autosave push is refused, for example because the branch was rewritten, the failure is written only to the hook's log, so nobody notices it. 0168 stopped close finish from rewriting an autosave that was already pushed. The human kept the hook's own silent failure out of that task. This task makes a refused autosave push visible: the next session start, `peal check` or close names it, wherever the plan decides it belongs. It also adds the stale-tracking-ref test that 0168's plan marked optional and that was never written: an autosave pushed from a second clone, which proves the fetch.

## Scope

## Done when

## Raw

> A refused SessionEnd autosave push is reported, not only logged
>
> ## Intent
>
> When the SessionEnd hook's autosave push is refused (for example on a branch that was rewritten), the failure goes only into the hook's log, and nobody sees it. 0168 stopped close finish from rewriting a pushed autosave, but the human left the hook's own silent failure out of that task's scope. Make a refused autosave push visible: the next session start, `peal check`, or close names it. Also add the stale-tracking-ref test that 0168 marked optional and did not write.
>
> ## Done when
>
> - A harness case shows a refused autosave push named at the next session start (or wherever the plan puts it).
> - The stale-tracking-ref test exists.
>
> ## Notes
>
> - Open: where the report belongs (SessionStart, `peal check`, or close verify).
> - 0184(b) changes what the autosave adds; plan the two together if both are open.
> - From the m3 milestone review (0168's Outcome).

## Notes

- Open: where the report belongs. SessionStart, `peal check` and close verify are the candidates, and it could be more than one. A related question: how the refusal is recorded so that a later session can see it. Today the hook's log is the only trace.
- Open: once the refusal has been reported, what clears it. A later successful push, or the next close?
- 0184(b) narrows what the SessionEnd autosave adds (`plugin/lib/session.sh`). If both tasks are open, plan them together. 0184 is not a prerequisite.
- 0168's Outcome describes both gaps. Its plan's test list holds the optional stale-tracking-ref case (`plugin/lib/close.test.sh`).
- From the m3 milestone review.
- `docs/security.md` covers the autosave and the SessionStart hook. `docs/design.md` and `docs/reference/cli.md` describe the autosave rule and close finish.

---

## Outcome

<!-- Written at close, replacing this comment. -->
