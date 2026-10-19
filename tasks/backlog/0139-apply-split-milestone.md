---
milestone: m3
plan: required
size: M
depends: [0132]
touches: [plugin/lib/apply*, plugin/lib/hostile.test.sh, docs/reference/cli.md, docs/security.md]
---

# 0139 — `peal apply`: the `split_milestone` kind

## Intent

`peal apply` carries out Belfry's `split_milestone` proposal on the files storage: a new
milestone made and the listed tasks moved to it, in the same single commit as the rest
of the batch. Until this lands, the kind is answered `invalid: not yet`.

## Scope

- `lib/apply.awk` learns a JSON array of strings on whitelisted keys (here the split's
  task list), each item written as data like any other value; arrays elsewhere stay
  refused.
- `split_milestone` in `lib/apply.sh`: built on 0132's `milestone_create` (id assigned
  by Peal, `@<proposal id>` for later proposals, init's text) and `move`.
- Docs: `docs/reference/cli.md`'s `peal apply` table, `docs/security.md`'s reader
  paragraph (arrays).

## Done when

- A batch with a `split_milestone` is one commit: the new milestone file and the moved
  tasks.
- A task not in `from`, an empty or non-string array item, or an array on another key
  makes the proposal invalid and leaves main unchanged.
- `hostile.test.sh` feeds hostile array items; nothing runs.

## Raw

> `split_milestone` (a new milestone and the tasks that move to it)

(quoted from Belfry #433's kinds, via task 0132's notes; the last of 0112's kinds)

## Notes

- The human's answers on 0132 (A3, A4): the tasks come as a JSON array of strings; `from`
  is required and every listed task must be in it; the new milestone's order is the given
  one or `from`'s + 1; nothing is renumbered.
- 0132 left the milestone kinds' compose in `plugin/lib/apply.sh` (`_pa_ms_item`,
  `_pa_ms_ids`, `_pa_ms_resolve`); reuse them.

---

## Outcome

<!-- Written at close, replacing this comment. -->
