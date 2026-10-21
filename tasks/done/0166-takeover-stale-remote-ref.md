---
milestone: m3
size: S
touches: [plugin/lib/store-files.sh, plugin/lib/store-files.test.sh]
---

# 0166 — Takeover does not fail on a remote branch already gone

## Intent

`peal_store_takeover` deletes a deferred claim's remote-only branch; when the remote
already deleted it and the tracking ref is stale, the push fails and the claim is
refused. Tell "already gone" (ls-remote --exit-code status 2: prune the ref, go on) from
a real failure, as task 0121 did for the release.

## Scope

`peal_store_takeover` in `plugin/lib/store-files.sh`.

## Done when

- A deferred, remote-only claim whose branch is gone on the remote is taken over silently.
- Suite and shellcheck green.

## Raw

> Found in 0121: its plan left takeover's same stale-ref delete out of scope.

---

## Outcome

`peal_store_takeover` (`plugin/lib/store-files.sh`) now treats a failed delete push of
a deferred claim's remote branch as `peal_release_remote` does since 0121: it asks
`git ls-remote --exit-code`, and status 2 (the branch is already gone on the remote)
lets the takeover go on silently, the existing `update-ref -d` pruning the stale
tracking ref. Any other status keeps the refusal with git's reason, so a branch that
moved since the fetch (the lease fails, the branch still exists) and a network failure
still refuse the claim.

The test is in `plugin/lib/backlog.test.sh`, next to the other takeover cases, not in
`store-files.test.sh` as the frontmatter's `touches` guessed: it deletes the branch on
the bare remote behind a clone's back, then claims there and checks the `released` line,
exit 0 and an empty stderr. Against origin/main's `store-files.sh` it fails with the old
"could not delete the deferred ... (stale info)".

The reviewer noted that the status-2 check now exists twice (here and in
`peal_release_remote`); the two callers differ in lease and in how a real failure is
handled, so only that one line is shared: a helper is worth it only for a third caller.
No idea filed.
