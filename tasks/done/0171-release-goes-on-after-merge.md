---
plan: auto
size: S
depends: []
priority: high
touches: [plugin/commands/release.md, plugin/lib/ship.sh]
---

# 0171 — A release goes on once its version pull request merges

## Intent

On 2026-10-22 the v0.6.0 release stopped after its first step and never finished on its
own. `peal ship bump` opened the version pull request (#308) and waited its budget, 540
s, which is shorter than this repository's CI; it returned status 3, and the release
stopped as `/peal:release` says, asking for a rerun once the pull request merged. The
pull request's CI then failed on a runner problem; the human sent it back, the resumed
session fixed CI and ended its turn, again saying to rerun the release. #308 merged by
itself 30 s later, and nothing reran it: no tag, no GitHub release, until the human
noticed and the tag, release and pin were made by hand. The same wait stopped `ship pin`
(#311, 540 s). When this is done, a release whose bump or pin pull request is still open
waits for it to merge (or fail) and goes on, and a session resumed to fix that pull
request's CI finishes the release once it merges.

## Scope

- `peal ship bump` and `peal ship pin`: wait for the pull request's CI the way close
  does (`wait_ci` under Belfry, `peal close wait`'s way outside it), then for the merge
  its auto-merge makes, instead of a fixed 540 s budget; status 3 only when CI failed or
  the pull request is left open with no auto-merge.
- `/peal:release`: on a failed CI of its own pull request, fix it there (as on a
  send-back), wait again and go on from the step that stopped; a session resumed on that
  pull request reruns from that step once it merged (`already at <version>` makes the
  bump a no-op), rather than ending with "run it again".

## Done when

- A test of `ship bump` against a fake pull request that merges after its CI returns 0 and
  the release goes on; one whose CI fails returns 3 naming the failing check.
- `plugin/commands/release.md` says to finish the release after fixing its pull request,
  and a resumed release session (the send-back case) tags and publishes once the pull
  request merged.

## Raw

> hm, I don't see any session or job running or queued for the tagging. That is weird. Do
> we need to fix anything?

## Notes

The v0.6.0 tag (8a94fe2), its GitHub release and the pin pull request #311 were made
by hand with `peal ship tag`, `publish` and `pin`. The runner problem that failed #308's
CI (a Microsoft apt source answering 403) was fixed in that pull request.

---

## Outcome

Built: `peal ship bump` and `peal ship pin` now wait for their pull request's checks and
for the merge its auto-merge makes. The default budget is 7200 s (`PEAL_SHIP_MERGE_BUDGET`
in `plugin/lib/ship.sh`). `PEAL_MAIN_WRITE_BUDGET` still overrides it, and other main
writes keep their 540 s. The check watching lives in `_peal_mw_wait_merged`
(`plugin/lib/main-write.sh`). When a check has failed and none is still pending, it
returns 1 and names the failing checks. bump and pin turn that into status 3, leaving the
pull request open with auto-merge on. Only `ship.sh` sets `PEAL_MAIN_WRITE_WAIT=merged`,
so no other caller is affected. Status 3 now means one of two things: the checks failed
(named), or the budget ran out. The path with no auto-merge (`_peal_mw_merge_self`)
already handled failure and only picks up the longer budget.

`plugin/commands/release.md` steps 1 and 3 now say to run bump and pin in the background,
because a tool call is capped at 10 minutes. On a failed check, the session fixes it on
that pull request (waiting with `wait_ci` under Belfry), reruns the step (`already at`
counts as success) and goes on to tag and publish. A session resumed on that pull request
does the same and no longer ends with "run it again".

Decided: the script waits itself instead of calling `wait_ci`, because a script cannot
call an MCP tool. Under Belfry, `wait_ci` is what the session uses while it fixes the pull
request. This departs from the Scope's wording but keeps its intent.

Tests: the new `bump_auto_merge` in `plugin/lib/ship.test.sh` covers a fake pull request
that merges after green checks (returns 0) and one whose check fails (returns 3 and names
`build`). `plugin/lib/fake-gh` check runs now carry a name. ship.test.sh passed 567/0.
The other suites rest on the commit's project checks. `docs/reference/cli.md` documents
the new wait and status 3.

Next session: the frontmatter `touches` lists only `release.md` and `ship.sh`, but the
diff also touches `main-write.sh`, `fake-gh`, `ship.test.sh` and `cli.md`, all in service
of the Scope.

Security fix after review: the earlier prompt told the session to push a fix onto the
failing bump or pin pull request, which has auto-merge on, so a push would land on main
unreviewed. Now `release.md` forbids any push onto a `peal/main-write-*` branch: the cause
is fixed in a pull request of its own, then `peal ship bump`/`pin` is rerun. In code, a
rerun no longer reuses an open write pull request whose head is not the commit Peal built
on the current main (it closes it and builds afresh), `_peal_mw_wait_merged` turns
auto-merge off and returns 1 when the head moved off the built commit, and a failing
commit status is named by its context. Tests in `ship.test.sh` (`bump_auto_merge`,
`bump_pushed_onto`).

### Reviewer findings not acted on

- The gap between the Scope's "`wait_ci` under Belfry" and the script polling GitHub itself
  was explained only in the implementer's notes: it is recorded above under Decided.
