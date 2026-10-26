---
plan: required
priority: low
touches: [plugin/lib/claim.sh]
size: S
merge: auto
---

# 0215 — The release verdict uses the shared peal_remote_ref

## Intent

`peal_release_verdict` in `plugin/lib/claim.sh` (near line 510) still resolves where a branch is on the remote with its own copy of the "upstream, else the remote-tracking ref" fallback that task 0101 introduced. That rule now lives in `peal_remote_ref` (`plugin/lib/common.sh`), which close, verify and the session hooks already call. Switch the release verdict to `peal_remote_ref` too, so the rule exists in one place only.

## Scope

- `peal_release_verdict` in `plugin/lib/claim.sh` only: its inline upstream/remote-tracking fallback is replaced by a call to `peal_remote_ref`. `common.sh` and the other callers stay as they are.

## Done when

- `claim.sh` has no `@{upstream}` fallback of its own (a grep finds no `@{upstream}` in it).
- `plugin/lib/claim.test.sh` passes.

## Raw

> The release verdict uses the shared peal_remote_ref
>
> ## Intent
>
> `peal_release_verdict` (`plugin/lib/claim.sh`, near line 510) still carries its own copy of the "upstream, else the remote-tracking ref" fallback that 0101 introduced and that now lives in `peal_remote_ref` (`plugin/lib/common.sh`). Close, verify and the session hooks use the shared helper; the release verdict does not. Switch it to `peal_remote_ref`, so that the rule exists in one place.
>
> ## Done when
>
> - `claim.sh` has no `@{upstream}` fallback of its own, and the claim harness passes.
>
> ## Notes
>
> - From the m3 milestone review. Still on main.

## Notes

- From the m3 milestone review; the duplicate was still on main when filed (`claim.sh:510`).
- The human's done-when: `claim.sh` has no `@{upstream}` fallback of its own, and the claim harness passes.
- Open question: whether the inline copy differs from `peal_remote_ref` in any edge (remote name, missing ref) that the release verdict relies on; check before swapping.
- Answered (planner, checked by hand with git): missing ref and empty result behave the same (verdict `ok`); `git rev-parse -q --verify x@{upstream}` with no upstream is silent with status 1, so the helper leaks no stderr; `refs/heads/x@{upstream}` never resolves, so the inline copy's first clause was dead and the verdict always used `refs/remotes/<remote>/<branch>`.
- Human (2026-10-26): accepts that a branch whose upstream is on another remote or under another name is now judged against that real upstream; record it in the Outcome. Agreed the plan, size S, merge auto.

## Plan

- Replace `claim.sh:510-511` with `up=$(peal_remote_ref "$branch" "$(peal_config_get remote)" 2>/dev/null) || up=""`. Keep the `-n "$up"` guard and the `rev-list --count "$up..refs/heads/$branch"` check; `rev-list` takes the ref name the helper prints. The remote stays `peal_config_get remote` (the reaping and doctor callers do not set `$PEAL_REMOTE`).
- Files: `plugin/lib/claim.sh` only (maybe a header comment at 482-493).
- Verification: `plugin/lib/claim.test.sh` in full (release unpushed, reaping kept/reaped, gone remote branch with empty stderr, locked config); `grep '@{upstream}' plugin/lib/claim.sh` finds nothing; `plugin/lib/doctor.test.sh` if it covers claims.
- Ranges: `plugin/lib/claim.sh:482-585`, `plugin/lib/common.sh:168-179`, `plugin/lib/doctor.sh:254-267`, `plugin/lib/session.sh:319-337`, `plugin/lib/claim.test.sh:143-143`, `plugin/lib/claim.test.sh:375-447`, `plugin/lib/claim.test.sh:538-589`, `tasks/done/0167-close-s-push-and-read.md:84-106`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
