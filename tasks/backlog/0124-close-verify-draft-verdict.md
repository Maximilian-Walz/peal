---
plan: skipped
size: S
depends: []
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

<!-- Written at close, replacing this comment. -->
