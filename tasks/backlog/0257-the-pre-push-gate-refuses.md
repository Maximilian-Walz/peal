---
milestone: m6
plan: required
priority: high
touches: [plugin/lib/githooks.sh, plugin/lib/githooks.test.sh, docs/security.md]
---

# 0257 — The pre-push gate refuses a storage push that rewrites a task holding `merge: auto`

## Intent

0234 (PR #407) closed one route to a plan changed under consent: `peal merge-gate` now refuses a pull request that changes any byte of a backlog or doing task keeping its agreed `merge`. The other route stays open. The pre-push content check (`_peal_pre_push_content` in `plugin/lib/githooks.sh`) refuses only three things on a storage push: `merge` added or changed, `origin` dropped, and a Plan or Outcome going from empty to filled. A `revise` or `apply` push straight onto main (`main-writes: direct`) can therefore still rewrite a `## Plan`, `## Scope` or `## Done when` that is already filled in a task holding `merge: auto`. The task's own pull request then merges by itself under consent the human gave for the old text.

Under a storage subject, pre-push applies the merge gate's rule: it refuses a changed blob of a task that holds `merge` both before and after the push, unless the same commit drops `merge`. Then the bullet in `docs/security.md` says truthfully which routes are closed.

## Scope

## Done when

## Raw

> The pre-push gate refuses a storage push that rewrites a task holding `merge: auto`
>
> ## Intent
>
> PR #407 (0234) makes `peal merge-gate` refuse any byte change to a backlog or doing task that keeps an agreed `merge`. The pre-push content check (`_peal_pre_push_content`, `plugin/lib/githooks.sh`) refuses only three things: `merge` added or changed, `origin` dropped, and a Plan or Outcome going from empty to filled. So a `revise` or `apply` push onto main (`main-writes: direct`) can still rewrite an already-filled `## Plan`, `## Scope` or `## Done when` of a task holding `merge: auto`. The task's own pull request then merges by itself under consent the human gave for the old text.
>
> Under a storage subject, have pre-push apply the merge gate's rule: refuse a changed blob of a task that holds `merge` before and after the push, unless the same commit drops `merge`.
>
> ## Done when
>
> - `githooks.test.sh` has a refused case for a rewritten Plan, Scope and Done when of a task holding `merge`, and an allowed case for a commit that drops `merge`.
> - The "Closed by 0234" bullet in `docs/security.md` no longer claims more than the code does: it names the pre-push route as closed by this task, or as still open.

## Notes

- The human set the milestone (m6) and the priority (high) when filing.
- Context: `docs/security.md`, the bullet "A changed plan under an agreed `merge`" (the "Closed by 0234" text, with the tests in `plugin/lib/merge-gate.test.sh`); `docs/design.md` on the git gates.
- Open question: "unless the same commit drops `merge`" — per commit or per push? A push of several commits where a later one drops `merge` while an earlier one rewrites the Plan: should it pass? The merge gate judges the whole pull request, so per push may be the matching rule.
- Open question: does the rule also cover a task moving out of backlog/doing (e.g. to done at close, or retire), or only blobs that stay in backlog or doing, as the merge gate does?
- Open question: the existing "Plan going from empty to filled" check probably overlaps the new rule for tasks holding `merge`; the planner decides whether to keep both or fold one into the other.

---

## Outcome

<!-- Written at close, replacing this comment. -->
