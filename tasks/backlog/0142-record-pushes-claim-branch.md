---
plan: required
milestone: m9
---

# 0142 — Files storage: peal record pushes the claim branch

## Intent

In the files storage, `peal record` commits the recorded plan or notes onto the task's claim branch but does not push it. Since task 0056, the board reads a claimed task's recorded fields (size, plan, touches, merge) from its claim branch, but a board in another clone only sees the remote branch, so it gets those fields only after the next push (SessionEnd autosave, close). Have `peal record` push the claim branch after committing, so other clones see the recorded fields at once.

## Scope

## Done when

## Raw

> peal record pushes the claim branch after committing (files storage), so a board in another clone sees a claimed task's recorded touches/size/plan/merge at once instead of after the next push (SessionEnd autosave, close). Found in 0056, agreed by the human as a follow-up there.

## Notes

Open questions: what `peal record` does when the push fails or the session has no network (sandboxed sessions push only through specific commands); whether the push should reuse the SessionEnd autosave's push path.

docs/design.md (the files storage's read model and the `touches` field) describes where a claimed task's fields come from since 0056.

---

## Outcome

<!-- Written at close, replacing this comment. -->
