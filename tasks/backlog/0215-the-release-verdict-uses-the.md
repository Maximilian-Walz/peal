---
plan: required
priority: low
touches: [plugin/lib/claim.sh]
---

# 0215 — The release verdict uses the shared peal_remote_ref

## Intent

`peal_release_verdict` in `plugin/lib/claim.sh` (near line 510) still resolves where a branch is on the remote with its own copy of the "upstream, else the remote-tracking ref" fallback that task 0101 introduced. That rule now lives in `peal_remote_ref` (`plugin/lib/common.sh`), which close, verify and the session hooks already call. Switch the release verdict to `peal_remote_ref` too, so the rule exists in one place only.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
