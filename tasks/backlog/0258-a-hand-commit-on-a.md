---
plan: required
touches: [plugin/lib/githooks.sh, plugin/lib/githooks.test.sh, docs/security.md]
---

# 0258 — A hand commit on a claim branch cannot add `merge` to a task file

## Intent

`docs/security.md` ("`merge: auto` is the human's") promises that no text a session writes adds `merge`. `peal record`, `peal revise` and issue edits hold that through `peal_merge_added`, but a session can bypass them: edit the claim copy of its task file by hand and commit it with plain `git commit`. The commit-msg gate's task-file fast path in `plugin/lib/githooks.sh` checks no `merge` key, and the merge gate lets the file's move into `done/` through. This happened: 0215's plan commit added the field, and the done files 0209 and 0128 on main carry it.

Since 0177 the board reads `merge` only from main's copy, so a claim copy's field grants nothing today. The gap is that the code does not hold what the security document states.

Close it in one of two places: the commit-msg gate refuses a commit on a claim branch that adds or changes `merge` in a task file compared with the commit's parent (dropping it stays allowed, as the reviewer's withdraw needs), or the merge gate refuses a `merge` key in a `done/` file that main's copy of the task did not hold. A `githooks.test.sh` case shows the hand commit refused, and `docs/security.md` states the rule, or the limit if one remains.

## Scope

## Done when

## Raw

> A hand commit on a claim branch cannot add `merge` to a task file
>
> ## Intent
>
> `peal record` refuses a text that adds `merge` (`peal_merge_added`, `plugin/lib/work.sh`), but a session can edit the claim copy and commit it with plain `git commit`: the commit-msg gate's task-file fast path (`plugin/lib/githooks.sh`) checks no `merge` key, and the merge gate lets the move into `done/` through. 0215's plan commit did exactly that, and the done files 0209 and 0128 on main carry the field. Since 0177 the board reads `merge` only from main's copy, so the field grants nothing today. But `docs/security.md` says no text a session writes adds `merge`, and the code does not hold that.
>
> Have the commit-msg gate refuse a commit on a claim branch that adds or changes `merge` in a task file compared with its parent (dropping it stays allowed), or have the merge gate refuse a `merge` key in a `done/` file that main's copy did not hold.
>
> ## Done when
>
> - A `githooks.test.sh` case shows the hand commit refused.
> - `docs/security.md` states the rule, or the limit if one remains.

## Notes

- Open question: which gate, or both? The commit-msg gate is local and `--no-verify` skips it; the merge gate (`plugin/lib/merge-gate.sh`, `merge-gate.awk`) runs on the pull request and already parses frontmatter before and after with `guard=1`, so it may be the one that actually holds. The planner should weigh which the security document can honestly claim.
- Open question: the human's agreement to a plan legitimately writes `merge: auto` (`docs/security.md`, "`merge: auto` is the human's"). Does that path ever land through a commit on a claim branch? If so the gate must tell it from a hand edit.
- Open question: do the existing done files 0209 and 0128 (and 0215 once done) need their stray `merge` cleaned, or does a gate comparing against main's copy simply leave them alone?
- `peal_merge_added` lives in `plugin/lib/tasks.sh` per `docs/security.md`; the idea names `plugin/lib/work.sh` as its caller.
- Context: `docs/security.md` ("Nothing reaches main but a merged pull request or Peal's own narrow writes", "`merge: auto` is the human's").

---

## Outcome

<!-- Written at close, replacing this comment. -->
