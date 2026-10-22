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
