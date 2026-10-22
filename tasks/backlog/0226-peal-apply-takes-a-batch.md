---
milestone: m8
plan: auto
size: S
depends: []
touches: [plugin/lib/apply.sh, plugin/lib/apply.test.sh, plugin/lib/hostile.test.sh, docs/reference/cli.md]
---

# 0226 — peal apply takes a batch id as a commit trailer and refuses a repeat of a batch it already carried out

## Intent

The control plane carries out a batch of accepted proposals in one request and records the outcomes only at its end; a restart or a lost worker answer leaves the batch half done, and re-accepting runs `peal apply` again, which files the same tasks under new numbers (its `PEAL_MW_TAKEN` check prevents duplicate ids, not duplicate tasks). The control plane's belfry#731 records an intent before the batch and hands `apply` a batch id as an idempotency key. When this is done `peal apply` writes the id into its commit's trailer and, given the same id again, answers the recorded outcome lines and changes nothing.

## Scope

- `plugin/lib/apply.sh`: a `batch` field (or `--batch ID`) written as a `Peal-Batch:` trailer on the apply commit (and the main-write pull request); before carrying out, `git log` main for the trailer and, when found, answer each proposal with the outcome recorded then (`already applied`) and exit 0.
- `apply.test.sh` and the hostile harness cover a repeated id and a hostile one.

## Done when

- A harness case runs the same batch twice and finds one commit and the second answer marked as already applied.
- The contract fixtures (0202) carry the field once the control plane publishes it.

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Waits for the control plane's belfry#731 (the batch id's name and where it travels), which its Recovery milestone delivers around 10-28; this task sits in Ready for newcomers so Contract kept does not wait for it. Reliability review finding 2.
- Security: none; the trailer is Peal's own text, written by Peal.

---

## Outcome

<!-- Written at close, replacing this comment. -->
