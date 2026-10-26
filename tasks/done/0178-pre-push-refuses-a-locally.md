---
plan: auto
size: S
depends: []
touches: [plugin/lib/githooks.sh, plugin/lib/githooks.test.sh, docs/security.md]
milestone: m6
priority: high
---

# 0178 — pre-push refuses a locally made merge onto main whose parent sits under any refs/remotes/*

## Intent

The pre-push gate lets a merge commit on main's first-parent line through when each other parent is an ancestor of any `refs/remotes/*` ref (`_peal_pre_push_merge` in `plugin/lib/githooks.sh`). The existing test "allowed: a merge of a pushed branch" shows that a local `git merge` of a pushed task branch followed by a push of main is accepted by design. The docs say a merge parent is never "content made up", but a remote-tracking ref is a local file: `git update-ref refs/remotes/origin/x <sha>`, or `git remote add other ...; git fetch other`, makes any commit "pushed first". A merged pull request is made on the server and runs no pre-push, so nothing legitimate needs this path. When this is done a merge made on the machine cannot reach main through the gate.

## Scope

- `_peal_pre_push_merge` refuses every locally made merge onto main, or accepts one only behind an explicit setting; if any acceptance is kept it checks the parent against `git ls-remote` of the configured remote, never against local `refs/remotes/*`.
- The test that allows a merge of a pushed branch is replaced by one that refuses it; a test with a fabricated remote-tracking ref refuses too.
- `docs/security.md` says that the gate is a guard against honest mistakes and that branch protection on main is what prevents this (see the Main decides milestone's task on that).

## Done when

- A test pushes main after a local merge of a pushed branch and the gate refuses it.
- A test fabricates `refs/remotes/origin/x` with `git update-ref` and the gate still refuses.
- `docs/security.md` no longer says the merge parent must have been pushed first.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Security review finding 3 (HIGH; design verified, fabricated ref reasoned, not run).
- Security: touches the git gates boundary ("nothing reaches main but a merged pull request or Peal's own narrow writes"); `docs/security.md` is updated here.

---

## Outcome

The pre-push gate now refuses every merge made on this machine that would land on main's first-parent line. The refusal reads "<sha> is a merge made here onto main; a merge reaches main as a pull request, made on the server". There is no setting to allow one: Peal's own writes to main are all single-parent commits, and a merged pull request is made on the server, where no pre-push runs. So nothing legitimate needed the old path, and `_peal_pre_push_merge` (the check "is the parent under any refs/remotes/*") is deleted, not kept behind a flag.

Tests (`plugin/lib/githooks.test.sh`, 492 passed): the old "allowed: a merge of a pushed branch" is now "refused". A new test fabricates `refs/remotes/origin/x` with `git update-ref` and is refused too. `docs/security.md` and the gate's header comment no longer say a merge of a branch pushed first is let through. They now say the gate guards against honest mistakes, and that branch protection on main is what stops a deliberate push.

At review I also reworded the refusal for a direct commit, from "is no merge" (which now hinted a merge would pass) to "is none of Peal's own writes". This was a separate commit.

Found and left: when the remote has no main yet, the gate's walk still uses `--not --remotes`, so it trusts local remote-tracking refs on the first push of main. This is queued as the idea "pre-push's first push of main trusts local remote-tracking refs".
