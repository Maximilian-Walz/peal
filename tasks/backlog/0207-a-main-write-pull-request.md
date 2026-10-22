---
plan: required
priority: high
touches: [plugin/lib/main-write.sh, plugin/lib/main-write.test.sh, plugin/lib/fake-gh, docs/security.md]
milestone: m4
---

# 0207 — A main-write pull request's auto-merge is pinned to the commit Peal built

## Intent

When Peal writes to main through a pull request, `_peal_mw_pr_manage` (`plugin/lib/main-write.sh`) turns on GitHub auto-merge for the `peal/main-write-*` pull request without `expectedHeadOid`, and `_peal_mw_wait_merged` accepts whatever merge happens. So anyone with write access can push a later commit onto that branch, and once the checks pass GitHub squash-merges it into main. Nobody reviews it: the body says there is nothing to review by hand, the pre-push shapes do not apply to a GitHub-side merge, and the control plane's merge tiers do not see it. When no caller waits (`PEAL_MAIN_WRITE_WAIT` unset: filings, revise, apply), even task 0171's head-moved check never runs; when one waits, it polls every 20s and can be too late. This has already happened once: a fix to a release pull request's CI, pushed onto its branch, merged by itself.

The human wants auto-merge bound to the exact commit Peal built, the same way the self-merge path already pins `sha` in its PUT merge:

- `enablePullRequestAutoMerge` gets `expectedHeadOid: <built sha>`, so GitHub turns auto-merge off when the head moves.
- The wait loop, on seeing `.head.sha` differ from the built sha, calls `disablePullRequestAutoMerge` and stops with an error.
- `docs/security.md` ("Nothing reaches main but a merged pull request or Peal's own narrow writes") says that a fix to a failing main-write goes through its own pull request, and the main write is built again.

Tests: a fake-gh case asserting `expectedHeadOid` is sent, and a `main-write.test.sh` case showing a moved head is refused and auto-merge disabled.

## Scope

## Done when

## Raw

> A main-write pull request's auto-merge is pinned to the commit Peal built
>
> ## Intent
>
> `_peal_mw_pr_manage` (`plugin/lib/main-write.sh`) turns on GitHub auto-merge for a `peal/main-write-*` pull request without `expectedHeadOid`, and `_peal_mw_wait_merged` accepts any merge. Anyone with write access who pushes a later commit onto that branch gets it squash-merged into main once the checks pass. The body says "nothing to review by hand", and neither the pre-push shapes nor the control plane's merge tiers apply. When no caller waits (`PEAL_MAIN_WRITE_WAIT` unset: filings, revise, apply), even 0171's head-moved check does not run. This has already happened once: a fix to a release pull request's CI, pushed onto its branch, merged by itself.
>
> ## Scope
>
> - Pass `expectedHeadOid: <built sha>` to `enablePullRequestAutoMerge`, so that GitHub turns auto-merge off when the head moves. The self-merge path already pins the sha.
> - In the wait loop, when `.head.sha` differs: `disablePullRequestAutoMerge` and stop with an error.
> - `docs/security.md` ("Nothing reaches main but a merged pull request…") says that a fix to a failing main-write goes through its own pull request and the main write is built again.
>
> ## Done when
>
> - A fake-gh case asserts `expectedHeadOid` is sent; a main-write.test.sh case shows a moved head is refused and auto-merge disabled.
>
> ### Merged: Security: a main-write pull request's auto-merge is not pinned to the commit Peal built. `_peal_mw_pr_manage` (plugin/lib/main-write.sh) calls `enablePullRequestAutoMerge` without `expectedHeadOid`. Someone with write access can push onto a `peal/main-write-*` branch after auto-merge is on. If the checks pass and GitHub merges before the next poll of `_peal_mw_wait_merged` (task 0171 added the head-moved check; it polls every 20s), or when no caller waits at all (PEAL_MAIN_WRITE_WAIT unset: filings, revise, apply), the pushed content squash-merges onto main with nobody reviewing it. Fix: pass `expectedHeadOid: $sha` to `enablePullRequestAutoMerge`, so GitHub turns auto-merge off when the head changes. The self-merge path already pins it (`sha` in the PUT merge). Add a fake-gh case and a main-write.test.sh case for it.

## Notes

- Open question: the wait loop already has 0171's head-moved check; the planner should confirm whether it only needs `disablePullRequestAutoMerge` added, or whether its error path changes too.
- Open question: if GitHub merges between a head move and the next poll, `expectedHeadOid` is the only guard. Should the wait loop also check that the merge commit's tree matches the built tree, for a merge done some other way (by hand, say)?
- Open question: whether a pull request found again for an existing `peal/main-write-*` branch (rather than one just opened) needs the same pin when auto-merge is re-enabled.
- Context: `docs/security.md`, "Nothing reaches main but a merged pull request or Peal's own narrow writes"; `docs/design.md` on main writes through pull requests.

---

## Outcome

<!-- Written at close, replacing this comment. -->
