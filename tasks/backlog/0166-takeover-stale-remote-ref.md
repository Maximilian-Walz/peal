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
