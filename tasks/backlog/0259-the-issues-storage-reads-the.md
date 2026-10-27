---
milestone: m6
plan: required
---

# 0259 — The issues storage reads the last body editor from userContentEdits, not Issue.editor

## Intent

The issues storage decides who last edited an issue's body from GraphQL `Issue.editor`. Two checks rest on that: the re-label check (`edit_admitted`, which admits an issue edited after it was labelled only when the editor may write) and, since PR #400, `keeps_human_sections` (which keeps a `## Plan` as agreed only when it was not changed by a stranger). GitHub documents `Issue.editor` only as "the actor who edited the comment", not as the *last* one. If it names the first editor, a stranger who edits their own issue after a maintainer has edited it reads as edited by the maintainer: the issue is admitted after labelling, and the stranger's `## Plan` is kept as agreed.

Either verify against a real issue which editor the field names, or read the last edit for certain from `userContentEdits(last: 1) { editor { login } editedAt }`, and have both checks use that source. A fixture covers a stranger's edit after a maintainer's edit (refused, Plan not agreed), and `docs/security.md` names the field the storage reads.

## Scope

## Done when

## Raw

> The issues storage reads the last body editor from userContentEdits, not Issue.editor
>
> ## Intent
>
> The re-label check (`edit_admitted`) and, since PR #400, `keeps_human_sections` read GraphQL `Issue.editor` as the last editor of the body. GitHub documents that field only as "the actor who edited the comment". If it names the first editor, a stranger who edits their issue after a maintainer edited it would read as edited by the maintainer: admitted after labelling, and their `## Plan` kept as agreed.
>
> Verify against a real issue, or read `userContentEdits(last: 1) { editor { login } editedAt }`, which names the last edit for certain.
>
> ## Done when
>
> - Both checks take the last edit's editor from a source that names it for certain, and a fixture covers a stranger's edit after a maintainer's edit (refused, Plan not agreed).
> - `docs/security.md` says which field is read.

## Notes

- Milestone m6 is the human's call, made when the idea was filed.
- Open question: verify on a real issue first (a sandboxed session cannot reach GitHub's GraphQL; that may need the human), or switch to `userContentEdits` outright? The latter needs no verification but adds a nested connection to the batched query in `plugin/lib/store-issues.sh` (one call per 100 issues); check its cost and that `editedAt` there matches `lastEditedAt`.
- Open question: `userContentEdits` also lists the creation as an edit entry on some issues; the planner should confirm what `last: 1` returns for an issue never edited, and for one whose last edit was by `peal` itself.
- Code: `edit_admitted` and `edit_writer` in `plugin/lib/issues-lib.awk`, the edits query in `plugin/lib/store-issues.sh`, the fake in `plugin/lib/fake-gh` and `plugin/lib/issue-fixtures.sh` (`--edited-at`), and the cases in `plugin/lib/hostile.test.sh`.
- `docs/security.md` (around the editor and renamer section) covers the trust model this changes.

---

## Outcome

<!-- Written at close, replacing this comment. -->
