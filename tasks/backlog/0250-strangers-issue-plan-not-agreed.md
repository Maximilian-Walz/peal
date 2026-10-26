---
milestone: m6
plan: required
depends: []
part-of: 0180
---

# 0250 — An outsider's labelled issue with ## Plan does not read as PLAN agreed

## Intent

On the issues storage `origin` is never set, so `plan` comes from labels and a filled `## Plan` in the body reads as `agreed`; the re-label check covers edits after labelling, not a plan that was already in the body when the maintainer labelled the issue. Under plain Claude Code `/peal:work` then starts the implementer on the stranger's plan. When this is done a stranger's text in an issue does not turn into an agreed plan.

## Scope

## Done when

## Raw

> - Issues storage: an issue whose `author_association` is not owner, member or collaborator counts as `origin: outsider` in `_peal_issues_text` so `peal work` forces `PLAN required`, or its `## Plan` and `## Outcome` are stripped from the body unless the task is a writer's.
> - A test: an issue by a stranger whose body holds `## Plan` reads as `PLAN required`, not `agreed`.

Split from 0180

## Notes

- The origin's planner proposed this approach, agreed by the human as the direction of the split (the open questions below are still to settle with this piece's planner):
  - A stranger's issue is one whose opener is not `writer()` (`plugin/lib/issues-lib.awk`). `_peal_issues_text` (`plugin/lib/issues-text.awk`) empties its `## Plan` and `## Outcome` unless the body was last edited by a writer other than the author (`edit_writer`); `peal record` with the human's login is such an edit, so a recorded plan survives. The edits row already comes from `_peal_issues_edits_batch` in `_peal_issues_admitted`; keep it rather than a new GraphQL call.
  - Rendering the issue as `origin: outsider` alone does not help: `_peal_work_here` (`plugin/lib/work.sh:63-76`) still promotes a filled Plan to `agreed`. Stripping the Plan unconditionally breaks `peal record`, which writes the agreed plan into the body, and `peal work` re-reads it.
- Absorbs 0122: `peal comment --origin outsider` on the issues storage is dropped silently today (`peal_store_comment` in `plugin/lib/store-issues.sh` ignores `PEAL_COMMENT_0180`); refuse it up front as `create` does since 0094 (`plugin/lib/backlog.sh:157-164`). Retire 0122 into this task when it is claimed.
- Open questions for this piece's planner: IssueProof (does a plan count as agreed when the body was last edited by any writer, or never on a stranger's issue?), IssueOrigin (should the text also render `origin: outsider`, changing `docs/reference/tasks.md:52`?), Take0122 (is the comment still posted when the flag is refused? default: refuse before posting).
- `docs/security.md` should say this limit is closed, with the tests. Size: about 60-70 tool calls, M.

---

## Outcome

<!-- Written at close, replacing this comment. -->
