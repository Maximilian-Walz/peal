---
milestone:
plan: skipped
depends: [0074]
priority: high
---

# 0082 — Peal's own `.belfry.yml` gets the `create:` key

## Intent

0074 added `peal init --stage belfry`'s `create:` line for a project's own
`.belfry.yml`, but left Peal's own contract file untouched: Belfry's server only accepts
`tasks.commands.create` from the release after its #264, and refuses the whole contract
(keeping the last valid one) until then. Once that release is deployed, add the
`create:` line to this repository's own `.belfry.yml` by hand, the same line
`peal init --stage belfry` now writes for the files storage.

## Scope

- This repository's `.belfry.yml` only: one line, `create: .peal/peal create --owner
  {owner} --title {title}`, in the same place `_peal_init_belfry_text` (0074) puts it.

## Done when

- Peal's own `.belfry.yml` holds the `create:` line, matching what `peal init --stage
  belfry` would write for the files storage today.

## Raw

0074's plan (human's answer, 2026-09-27): "Peal's own `.belfry.yml` does not get the
`create:` key here; a follow-up task, depending on 0074, adds it once Belfry's release
after #264 is deployed."

## Notes

Revised 2026-09-28: priority high: goes into Peal's next patch release (daily-use fixes after m1)

- Wait for Belfry's release after its #264 to be deployed before merging this: before
  that, its server refuses the contract with the new key and keeps the last valid one.
  No task id names that release; check with Belfry, or that a project's own generated
  `.belfry.yml` already gets `create:` from `peal init --stage belfry` without complaint.

---

## Outcome

<!-- Written at close, replacing this comment: what was built, what was decided, what was
     found and left (each a new task), and what the next session needs to know. -->
