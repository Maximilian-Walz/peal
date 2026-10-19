---
milestone: m3
plan: required
touches: [plugin/bin/peal, plugin/lib/apply*, plugin/lib/store*.sh, plugin/lib/githooks*.sh, plugin/lib/ship*.sh, plugin/lib/init*.sh, plugin/lib/hostile.test.sh, plugin/commands/setup.md, docs/design.md, docs/security.md, docs/reference/*.md, docs/guides/belfry.md]
size: L
model: opus
---

# 0112 — `peal apply`: carry out a batch of proposals as one change

## Intent

A control plane's triage and planning runs end with a list of changes the human
accepted: file these tasks, move those to another milestone, change a priority, add a
dependency, retire a duplicate, create or park a milestone. Today each is one `peal`
command, and on a repository whose main branch takes pull requests only, each opens a
pull request of its own, so one decision becomes a dozen pull requests for the human to
merge. When this is done, `peal apply` reads the whole list as one JSON document on
stdin and makes it one change: one commit on the files storage (one pull request where
main is protected) and one line of result per item on stdout.

This task builds the task kinds on the files storage; the rest is split into 0132
(milestone kinds) and 0133 (fold the single contract commands into `apply`, and
`apply:` in this repository's own `.belfry.yml`).

## Scope

- `peal apply` takes the task proposal kinds of Belfry's #433 (`file`, `add`, `move`,
  `priority`, `depends` add/remove, `retire` with a reason or a duplicate) on the files
  storage, in the input and answer format of the plan below, which is Peal's proposal
  for Belfry's `tasks.commands.apply` (#434). Each item is validated as the single
  commands validate it today (depends cycles, unknown milestones, frontmatter), and a
  batch with an invalid item changes nothing and says which.
- The milestone kinds (`milestone_create`, `milestone_update`, `milestone_state`,
  `split_milestone`) are answered `invalid` with "not yet" until 0132; `fold` and
  `dismiss` are answered `invalid` (not a backlog change; Belfry carries it out).
- Filed tasks get ids the way `peal create` gives them (unique across filings, 0073),
  keep `origin` when given, and may refer to each other within the batch.
- On the issues storage `peal apply` refuses: Belfry writes github-issues projects
  through its own client.
- `/peal:setup belfry` and `peal init --stage belfry` write `apply:` into
  `.belfry.yml`. The single contract commands stay; 0133 deletes those Belfry's #434
  folds into `apply`.

## Done when

- A batch of mixed task items on the files storage becomes one commit (one pull request
  on a protected main, tested against the fake gh); each item's result is printed.
- An invalid item leaves everything unchanged and names the item.
- `peal apply` on the issues storage refuses with the reason.
- `docs/design.md` documents `apply` next to the other Belfry commands.

## Raw

The task's text before planning narrowed it (0132 and 0133 hold the rest):

> ## Intent
>
> A control plane's triage and planning runs end with a list of changes the human
> accepted: file these tasks, move those to another milestone, change a priority, add a
> dependency, retire a duplicate, create or park a milestone. Today each is one `peal`
> command, and on a repository whose main branch takes pull requests only, each opens a
> pull request of its own, so one decision becomes a dozen pull requests for the human to
> merge. When this is done, `peal apply` reads the whole list as one JSON document on
> stdin and makes it one change: one commit on the files storage (one pull request where
> main is protected), the matching API calls on the issues storage, and one line of result
> per item on stdout.
>
> ## Scope
>
> - `peal apply` takes the proposal kinds Belfry's contract defines for
>   `tasks.commands.apply` (Belfry issue #434, with the kinds of #433): file, add, move,
>   priority, depends, retire (with a duplicate), milestone create, update, state and
>   split. Each item is validated as the single commands validate it today (depends
>   cycles, unknown milestones, frontmatter), and a batch with an invalid item changes
>   nothing and says which.
> - Filed tasks get ids the way `peal create` gives them (unique across filings, 0073),
>   keep `origin` when given, and may refer to each other within the batch.
> - `/peal:setup belfry` and `peal init --stage belfry` write `apply:` into
>   `.belfry.yml`; this repository's own `.belfry.yml` gets it once a release carrying it
>   is installed.
> - Whether the single commands stay is decided with Belfry's #434; Peal follows it.
>
> ## Done when
>
> - A batch of mixed items on the files storage becomes one commit (one pull request on a
>   protected main), and on the issues storage the matching API calls; each item's result
>   is printed. Tested against the fake gh.
> - An invalid item leaves everything unchanged and names the item.
> - `docs/design.md` documents `apply` next to the other Belfry commands.

## Notes

- 2026-10-19, planning. Belfry's #433 and #434 are open and record no decision, so
  Peal proposes the contract and Belfry adopts it. The human's answers:
  - Contract: build the input/answer format of the plan; it goes into Belfry's
    contract.
  - Issues storage: dropped. Belfry writes github-issues projects itself, and Peal
    never gives an issues-storage project the `commands` backend; `peal apply` there
    refuses. The Done-when's issues half is struck.
  - Single commands: kept here; 0133 deletes the ones Belfry's #434 folds into `apply`.
  - Outside the original touches: yes to a new pre-push `apply` shape (documented in
    `docs/security.md`) and to the `ship.sh` fix.
  - `fold` and `dismiss`: answered `invalid`, never a silent `done`.
  - Split: 0132 (milestone kinds), 0133 (single commands, own `.belfry.yml`).

- 2026-10-19, review. The human's answers:
  - The `why` texts stay in the commit and pull request bodies (so
    `plugin/lib/main-write.sh` gets the `PEAL_BODY` change), but closing keywords and
    @mentions in them are defused, and `docs/security.md` says so.
  - The rules `apply.sh` copied from the single commands (unclaimed check, add note,
    depends rewrite, retire Outcome, dependents scan) are refactored into shared
    old-text → new-text helpers that both paths call, in this task.

## Plan

**Contract.** Input on stdin, ids resolved by Belfry:

```json
{"proposals": [
  {"id": "p1", "kind": "file", "title": "...", "text": "<task text as create takes it, NNNN for its number>",
   "milestone": "m3", "priority": "high", "owner": "ai", "origin": "outsider", "why": "..."},
  {"id": "p2", "kind": "add", "task": "0042", "text": "...", "origin": "outsider", "why": "..."},
  {"id": "p3", "kind": "move", "task": "0042", "milestone": null, "why": "..."},
  {"id": "p4", "kind": "priority", "task": "0042", "priority": "urgent|high|normal|low"},
  {"id": "p5", "kind": "depends", "task": "@p1", "on": "0040", "op": "add|remove"},
  {"id": "p6", "kind": "retire", "task": "0039", "reason": "..."},
  {"id": "p7", "kind": "retire", "task": "0038", "duplicate": "0040"}
]}
```

- `id` is Belfry's opaque proposal id, echoed back; `"@<id>"` names a task an earlier
  `file` proposal of the batch files.
- `file`: `milestone`, `priority`, `owner`, `origin` go into the frontmatter and win over
  the text; `title` only gives the slug, as `create --title`.
- `add`: a dated line under Notes; with `origin: outsider` the task is marked
  `origin: outsider` too.
- `priority: normal` removes the field.
- `retire` with `duplicate`: Outcome "Retired <date> without being claimed: duplicate of
  0040".
- Milestone kinds: `invalid`, "not yet" (0132). `fold`, `dismiss`: `invalid`, "not a
  backlog change; Belfry carries it out".

Answer on stdout, one JSON line per proposal in input order:

```json
{"id": "p1", "status": "done", "task": "0131", "detail": "filed tasks/backlog/0131-x.md", "change": "https://github.com/o/r/pull/9"}
{"id": "p3", "status": "invalid", "detail": "milestone m9 does not exist"}
```

`status`: `done`, `invalid` (this proposal failed a check), `not_applied` (valid, but
another was not, so nothing was written), `failed` (the write failed). Exit 0 all done,
2 invalid batch and nothing changed, 1 the write failed. A pull request still open at the
budget with auto-merge on answers `done` with `change` set, as `peal create` does.

**Approach.**

- `plugin/lib/apply.awk`: JSON to flat records (proposal index, key, value); long texts
  to files of their own under a temp dir, never shell words. Decodes `\uXXXX`, surrogate
  pairs included, to UTF-8 under `LC_ALL=C` (Go escapes U+2028/U+2029). Malformed JSON,
  an unknown kind or field makes the item invalid. No jq (bash/git/awk rule in
  `docs/design.md`).
- `plugin/lib/apply.sh`, validate everything on the fetched main, against the state
  after the whole batch, reporting every problem:
  - task in the backlog and unclaimed (`_peal_files_unclaimed`);
  - milestone exists, not done, parked rules of task-check's revise rule;
  - known priority;
  - added text has no `---` or `## ` line (`peal comment`'s rule);
  - filed text passes `peal_task_check` and `peal_create_filed`'s rules (no `merge`, no
    delimiter, owner/origin values);
  - a retired task no longer named by any `depends` or `part-of` once the batch's own
    depends items count (so a batch can re-point dependents to the duplicate);
  - no depends cycle in the final texts (`peal_cycle_check_*`);
  - every `@ref` resolves to a `file` proposal of the batch.
- Write: one build function for `peal_push_main`, replaying every item in order onto
  copies from the base it is given (a race retry rebuilds on the new main); items on one
  task compose on one copy; new ids from `_peal_files_next_id` with
  `PEAL_MW_TAKEN=_peal_files_create_taken`; `@ref` replaced by the new id; retire moves
  backlog → done. One tree, subject `docs(tasks): apply N proposals`; the commit body
  (and pull request body) lists each proposal with its `why`. Reuse the rewrite helpers
  (`_peal_files_rewrite_milestone`, `_rewrite_comment`, `_rewrite_depend`,
  `_build_retire`'s Outcome) as old-text → new-text functions.
- `PEAL_MAIN_WRITE_BUDGET` capped at 90 s unless set, as `create` and `depend`.
- `peal_store_apply` in the storage interface; the issues storage refuses.
- `plugin/lib/githooks.sh` pre-push: an `apply` shape, exact subject, accepting only
  added or modified backlog task files and backlog → done moves under the same name.
  Documented as a widening in `docs/security.md`.
- `plugin/lib/ship.sh`: release items leave out every done file added by a
  `docs(tasks)` commit (a real close never is one).
- `peal init --stage belfry` and `/peal:setup belfry` write `apply: .peal/peal apply`.
- Docs: `docs/design.md` (table row and belfry block), `docs/reference/cli.md`,
  `docs/reference/storage.md`, `plugin/lib/store.sh`'s interface comment,
  `docs/security.md`, `docs/guides/belfry.md` (blocks checked by `tools/docs.test.sh`).

**Files.** New `plugin/lib/apply.sh`, `plugin/lib/apply.awk`,
`plugin/lib/apply.test.sh`. Modified `plugin/bin/peal`, `plugin/lib/store-files.sh`,
`plugin/lib/store-issues.sh`, `plugin/lib/store.sh`, `plugin/lib/githooks.sh` and test,
`plugin/lib/ship.sh` and test, `plugin/lib/init.sh` and test,
`plugin/lib/hostile.test.sh`, `plugin/commands/setup.md`, `docs/design.md`,
`docs/security.md`, `docs/reference/cli.md`, `docs/reference/storage.md`,
`docs/guides/belfry.md`. `plugin/lib/main-write.sh` expected unchanged.

**Verification.**

- `apply.test.sh` on a bare remote: a batch of two `file` items (the second depending on
  `@p1`), `add` with outsider, `move`, `priority` set and normal, `depends` remove and
  add re-pointing to a duplicate, `retire` with a duplicate: exactly one new commit, the
  expected tree, ids and frontmatter, one `done` line per proposal, exit 0.
- The same batch with `main-writes: pr` against the fake gh: one pull request, apply
  subject, whys in its body.
- A rival `peal/main-write-*` branch holding the next number: filed ids skip it (0073).
- Invalid batches (unknown milestone, claimed task, a cycle only the batch closes, a
  retire whose dependents are not re-pointed, a `file` setting `merge`, an `add` with a
  `## ` line, unknown kind, `fold`, a milestone kind, malformed JSON, a dangling `@ref`):
  main's sha unchanged, no pull request in the fake gh, the bad one `invalid` with its
  reason, the rest `not_applied`, exit 2.
- Issues storage: `peal apply` refuses.
- `githooks.test.sh`: an apply commit passes a direct push; one touching a non-task file,
  deleting a done file or renaming is refused.
- `ship.test.sh`: a retire inside an apply commit is no release item.
- `init.test.sh`, `tools/docs.test.sh`: `apply: .peal/peal apply` written, docs blocks
  match.
- `hostile.test.sh`: text with `$(...)`, backticks, newlines or the delimiter is stored
  byte for byte or refused, never run.

**Ranges.** `docs/design.md:38-111`, `docs/design.md:372-410`, `docs/design.md:436-454`,
`docs/design.md:468-516`, `docs/security.md:135-176`, `docs/reference/tasks.md:35-55`,
`docs/reference/tasks.md:132-154`, `docs/reference/cli.md:250-301`,
`docs/reference/cli.md:382-402`, `plugin/bin/peal:69-311`, `plugin/bin/peal:400-550`,
`plugin/lib/main-write.sh:109-214`, `plugin/lib/main-write.sh:378-424`,
`plugin/lib/store-files.sh:284-435`, `plugin/lib/store-files.sh:437-542`,
`plugin/lib/store-files.sh:672-719`, `plugin/lib/store-files.sh:776-929`,
`plugin/lib/store-files.sh:1171-1239`, `plugin/lib/store-issues.sh:440-547`,
`plugin/lib/store.sh:1-100`, `plugin/lib/backlog.sh:56-110`,
`plugin/lib/backlog.sh:159-274`, `plugin/lib/review.sh:9-55`,
`plugin/lib/task-check.awk:1-40`, `plugin/lib/githooks.sh:144-302`,
`plugin/lib/ship.sh:8-24`, `plugin/lib/ship.sh:389-414`, `plugin/lib/init.sh:402-468`,
`plugin/lib/json-get.awk:1-98`, `plugin/lib/fake-gh:240-260`,
`plugin/commands/setup.md:118-130`, `tools/docs.test.sh:16-34`,
`docs/guides/belfry.md:14-31`.

---

## Outcome

`peal apply` is built for the task kinds on the files storage. It reads Belfry's
accepted proposals as one JSON document on stdin
(`{"proposals":[{id, kind, …, why}]}`, the format agreed in the Plan as Peal's proposal
for Belfry's `tasks.commands.apply`, #434). It checks the whole batch against main as it
will be afterwards. Then it writes one commit through `peal_push_main` (one auto-merging
pull request where main is protected) and answers one JSON line per proposal: `done`,
`invalid`, `not_applied` or `failed`, with exit 0, 2 or 1.

- **Files.**
  - New: `plugin/lib/apply.awk` (a JSON reader: no jq, `LC_ALL=C`, `\uXXXX` to UTF-8
    with surrogate pairs, each value written to a file of its own), `plugin/lib/apply.sh`
    and `plugin/lib/apply.test.sh`.
  - `peal_store_apply` is in `store-files.sh`. `store-issues.sh` refuses: Belfry writes
    github-issues projects itself (the human's call; the Done-when's issues half is
    struck).
- **Kinds.**
  - Carried out: `file`, `add`, `move`, `priority`, `depends` (add or remove) and
    `retire` (with a reason or a duplicate).
  - Answered `invalid` "not yet": the milestone kinds, until 0132.
  - Answered `invalid`: `fold` and `dismiss`.
  - `@<id>` names a task filed earlier in the batch, in `task`, `on` and `duplicate`.
    A filed text's own `depends` cannot name one.
- **Shared rules.** On review, the rules apply had copied were turned into helpers in
  `store-files.sh` that both the single commands and apply call: `_peal_files_no_claim`,
  `_peal_files_in_backlog`, `_peal_files_add_depend`, `_peal_files_retire_text` and
  `_peal_files_dependents`. As a result, apply's `invalid` details use the single
  commands' wording.
- **The `why` texts.** Each `why` goes into the commit and pull request bodies through a
  new optional `PEAL_BODY` in `main-write.sh`. `_pa_defuse` puts a zero-width joiner
  after `#`, `@`, `issues/` and `pull/`, so outside text cannot close an issue or ping
  anyone when the pull request merges unread. `docs/security.md` says so.
- **Gate, release notes and setup.**
  - The pre-push gate has an exact-subject `docs(tasks): apply N proposals` shape: only
    added or modified backlog files, and backlog → done moves under the same name.
  - `ship.sh` leaves out done files added by any `docs(tasks)` commit, so a retire inside
    an apply is no release item.
  - `peal init --stage belfry` and `/peal:setup belfry` write
    `apply: .peal/peal apply`. This repository's own `.belfry.yml` is left to 0133.
- **Departures from the plan.**
  - `depends` proposals write no Notes line; the why goes into the commit body.
  - A `depends remove` of an id not in the list, and a batch that changes nothing, answer
    `done` with no commit.
  - A problem found after the whole batch is applied is marked on the last proposal that
    touched that task, or on the `depends add` proposals for a cycle.
- **Planning.** `peal record` could not record the plan, because the task had no
  `## Raw` section and adding one counts as a change. The plan commit was made with git
  under record's subject, with a Raw quoting the task's text before planning (friction
  reported; 0134).
- **Tests.**
  - apply: 159 checks, under mawk, nawk and busybox awk.
  - store-files 187, githooks 157, backlog 145, docs 37 and hostile 2257, all passing.
  - Lint is clean.
- **Next.** 0132 (milestone kinds) and 0133 (fold the single commands into `apply`
  once Belfry's #434 decides, and `apply:` in this repository's `.belfry.yml`). Belfry
  should take the input and answer format from the Plan into its contract.
