---
plan: required
touches: [plugin/lib/githooks.sh]
---

# 0249 — pre-push's first push of main trusts local remote-tracking refs

## Intent

When the remote has no main branch yet, `_peal_pre_push` decides which commits to check with `git rev-list ... --not --remotes`. That trusts the local `refs/remotes/*`, which are local files that anyone can fake with `git update-ref`. Task 0178 removed the same weakness for merges. Only the first push of main is affected. The fix would either base the walk on `git ls-remote` of the remote being pushed to, or refuse a first push of main that adds anything besides Peal's own writes.

## Scope

## Done when

## Raw

> pre-push: when the remote has no main yet, _peal_pre_push walks `git rev-list ... --not --remotes`, which trusts local refs/remotes/* (a local file, fabricable with git update-ref), the same weakness task 0178 removed for merges; only the first push of main is affected. Base the walk on `git ls-remote` of the pushed remote, or refuse a first push of main that adds more than Peal's own writes. Found by the reviewer of 0178.

## Notes

- Open question: which of the two fixes to use. A first push of main normally carries the project's whole history, so refusing everything but Peal's own writes may block a legitimate first push.
- `docs/security.md`, the section "Nothing reaches main but a merged pull request or Peal's own narrow writes".

---

## Outcome

<!-- Written at close, replacing this comment. -->
