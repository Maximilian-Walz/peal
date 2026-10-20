---
plan: skipped
size: S
depends: []
milestone: m3
---

# 0124 — `close verify` blocks on a draft pull request

## Intent

`close verify` reports READY for an open draft pull request with green checks without
looking at its draft state. When this is done it reports a `BLOCKED:draft` verdict
instead, so a draft is never taken for a pull request ready to merge.

## Scope

- `close verify`: read the pull request's draft state; a draft gives `BLOCKED:draft`.
- Its documentation and tests.

## Done when

- close.test.sh: verify on an open draft pull request with green checks reports `BLOCKED:draft`, not READY.

## Raw

Found in 0099: "`close verify` reports READY for an open draft pull request with green checks without looking at its draft state; consider a `BLOCKED:draft` verdict."

## Notes

---

## Outcome

`peal close verify` now reads the pull request's `draft` field in the same `gh` call that
already reads state, merged and mergeable. An open draft reports `BLOCKED:draft` (exit 1).
That check comes before the conflicts and checks steps, so a draft never reaches READY,
however green it is. Merged and closed pull requests are not affected: they settle before
the draft check. `peal close wait` needed no change, because it stops on any BLOCKED.

`close finish` already marks a draft ready, so a draft seen at verify time is one finish
could not mark ready, or one the human put back to draft. The instruction in
`plugin/commands/close.md` is therefore "report it and stay; the human marks it ready".
That file was not named in the Scope but holds the list of verdicts, so it was updated
with `docs/reference/cli.md` and the verdict comment in `plugin/lib/close.sh`.

Test: `verify: draft` in `plugin/lib/close.test.sh` runs with green checks and expects
`BLOCKED:draft 1`. The fixture still has `mergeable false` at that point, so the case also
pins that draft wins over conflicts. Without the fix it would read `BLOCKED:conflicts`.
close.test.sh: 1101 passed, 0 failed. The review found nothing.
