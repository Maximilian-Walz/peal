---
milestone: m3
plan: required
size: M
depends: [0132]
touches: [plugin/lib/apply*, plugin/lib/hostile.test.sh, docs/reference/cli.md, docs/security.md, docs/design.md]
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
  paragraph (arrays), `docs/design.md`'s list of kinds.

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
- The human's answers on the plan (2026-10-19): A1 fields `from`, `tasks` (array), `title`
  (required), `goal`, `due`, `order`, with `milestone_create`'s rules for title/goal/due.
  A2 "in `from`" is judged on the batch as it stands at that proposal (an earlier `move`
  into `from` counts). A3 items are `NNNN` ids or `@<id>` of an earlier `file` proposal
  (filed into `from`). A4 an empty array and a duplicate item are both invalid. A5 later
  proposals name the new milestone `@<split id>`; `from` may be `@<earlier create>`; the
  answer carries `milestone` (new id), no `task` key, the moved tasks in `detail`. A6
  `docs/design.md`'s list of apply kinds gains `split_milestone` in this task. A7 (decided):
  `from` without `order` falls back to one past the highest (`_pa_ms_order`).

## Plan

Approach:
- `plugin/lib/apply.awk`: a whitelist passed in from apply.sh (`-v arrays="tasks"`). An
  array on a whitelisted key writes the manifest line `I<TAB>tasks<TAB>a` and item n (from 1)
  decoded to `DIR/I.tasks.n`; a non-string item (number, null, object, nested array) gives
  `field tasks holds an item that is not a string`; a lone surrogate or `\u0000` in an item
  gives the usual `serr`; an array on any other key keeps today's error. Header comment.
- `plugin/lib/apply.sh`: helper `_pa_items I KEY` prints the item files in order (items
  only ever matched against `^[0-9]{4}$` or `@<id>`, never split into words).
  `PEAL_APPLY_KINDS` gains `split_milestone`, the "not yet" branch goes. `_pa_static`:
  allowed `from tasks title goal due order`, required `from tasks title`, type `tasks:a`
  for this kind only; items non-empty, each a task id or earlier `@<file id>`, no
  duplicates, empty array invalid. `title`/`goal`/`due`/`order` through `_pa_static_ms`.
  `_pa_ms_ref` takes a KEY (`milestone` or `from`). `_pa_ms_index` and `_pa_ms_ids` cover
  `split_milestone` too. Compose: `_pa_ms_item`'s create branch becomes a shared
  `_pa_ms_new I ORDER`; a split resolves `from` (must exist), order = given, else
  `from`'s + 1, else `_pa_ms_order`; writes the file; then per item `_pa_resolve`,
  `_pa_load` (backlog, unclaimed), refuse retired, refuse "task X is not in milestone
  <from>" unless its composed milestone is `from`; `peal_fm_set` milestone, `t/$id.last=i`,
  `ms.last=i`. Detail `created milestone m4 (docs/milestones/m4.md); moved 0001, 0002`;
  `res.$i.milestone` the new id, no `task` key. End-state checks, commit body and the
  pre-push gate unchanged.
- Rejected: items joined in one file (forgeable separators); whitelist hard-coded in awk;
  synthetic create+move proposals.

Files: `plugin/lib/apply.awk`, `plugin/lib/apply.sh`, `plugin/lib/apply.test.sh`,
`plugin/lib/hostile.test.sh`, `docs/reference/cli.md` (table row, "not taken yet" narrowed
to fold/dismiss, `@` sentence extended to `from` and `@<split id>`), `docs/security.md`
(reader paragraph: arrays only on `tasks`, string items each in its own file, checks on
`from` and items), `docs/design.md:100` (the kinds list).

Verification:
- `apply.test.sh`: happy path on `setup_tasks` with 0005 in m1: split (`from: m1`,
  `tasks: ["0001","0005"]`, title, goal), a `move` of 0002 to `@s`, a `priority`; exit 0,
  one commit `docs(tasks): apply 3 proposals`, `A docs/milestones/m4.md` plus `M` on the
  three tasks; m4 is init's text, `state: open`, order m1's + 1, m2 unchanged; answer has
  `"milestone": "m4"` and the moved tasks in detail; tasks say `milestone: m4`; `peal check`
  passes. A given `order` used as is. Invalid (exit 2, main unchanged, rest `not_applied`):
  task not in `from`, task in no milestone, unknown `from`, no `from`, empty array,
  empty-string item, number/null/object/nested-array item, duplicate, non-NNNN item, `tasks`
  as a string, `tasks` on `move`, array on `title`, lone surrogate in an item, claimed task,
  `from` parked at the start. The old "not yet" case (line 299) replaced.
- `hostile.test.sh`: `{"kind":"split_milestone","from":"@","tasks":["@","@"],"title":"@"}`
  through `each_input` and the escaped `H[i]` loop for items, `from` and title; canaries
  `$CANARY/dollar`, `$CANARY/backtick` absent.
- `tools/docs.test.sh` and shellcheck pass.

Ranges:
- tasks/done/0132-apply-milestone-kinds.md:66-99, 101-151, 212-218
- plugin/lib/apply.sh:1-52, 106-131, 145-162, 164-306, 308-320, 363-370, 452-572, 590-628, 749-779
- plugin/lib/apply.awk:1-15, 52-92, 94-134, 148-198
- plugin/lib/apply.test.sh:112-195, 258-340
- plugin/lib/hostile.test.sh:420-454
- plugin/lib/milestones.sh:6-46, 77-85
- docs/reference/cli.md:303-341
- docs/security.md:132-140, 183-209
- docs/design.md:96-104


---

## Outcome

`peal apply` now carries out `split_milestone`, the last of 0112's milestone kinds; only
`fold` and `dismiss` remain "not yet" (0133).

- `plugin/lib/apply.awk` takes a whitelist of array keys from `apply.sh`
  (`-v arrays="tasks"`). An array on a whitelisted key writes the manifest line
  `I<TAB>tasks<TAB>a` and each item, decoded, to its own file `I.tasks.n`, so an item is
  never a shell word and cannot forge a separator. A non-string item (number, null,
  object, nested array) and an array on any other key make the proposal invalid.
- `plugin/lib/apply.sh`: fields `from tasks title goal due order` (`from`, `tasks`,
  `title` required). Items are `NNNN` or `@<earlier file>`, non-empty and not repeated;
  an empty list is invalid. The compose checks every listed task (backlog, unclaimed, not
  retired, in `from` as the batch stands at that proposal) before it writes anything, so
  a failing split leaves no partial state. Then it writes the milestone with init's text
  (`open`; order the given one, else `from`'s + 1, else one past the highest; nothing
  renumbered) and moves the tasks. `@<split id>` names the new milestone for later
  proposals, and `from` may be `@<earlier create or split>`. The answer carries
  `milestone`, and its detail lists the moved tasks. `_pa_ms_ref` takes the key
  (`milestone` or `from`); the create branch of `_pa_ms_item` covers both kinds, instead of
  the separate `_pa_ms_new` the plan named.
- Tests: `ms_split` (5 proposals, two splits chained through `@s`, one commit) and
  `split_invalids` (about 25 cases, each with exit 2 and main unchanged) in `apply.test.sh`;
  hostile items, `from`, title and goal in `hostile.test.sh`. Hostile `from` values are
  refused before the compose; the compose path is covered by `apply.test.sh`.
- Docs: `cli.md` (the kind's row, the `@` rules), `security.md` (the reader's arrays),
  `design.md` (the list of kinds, A6).

### Reviewer findings not acted on

- The plan's `_pa_ms_new` helper was not made; the existing create branch was widened
  instead. It has the same effect, with no duplication.
