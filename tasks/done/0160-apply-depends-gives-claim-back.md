---
milestone: m3
plan: skipped
size: M
depends: [0133]
priority: high
---

# 0160 — `apply`'s `depends` gives this clone's live claim back

## Intent

Belfry with `apply:` set sends `task_defer` as a `depends` proposal on the session's own,
claimed task. `apply` refuses it (`_peal_files_no_claim`), and `peal depend`, which gave the
claim back, is deleted by 0133. Let `apply`'s `depends` on a task held by a live claim of
this clone give the claim back as `peal defer` does, so Belfry's deferral works again.

## Scope

- `plugin/lib/apply.sh` and the files store: a `depends` proposal on this clone's live claim.
- Tests in `plugin/lib/apply.test.sh`; docs in `docs/reference/cli.md` and `docs/design.md`.

## Done when

- A batch with a `depends` proposal on the task this worktree claims gives the claim back
  and writes the dependency in the same commit; a claim elsewhere is still refused.

## Raw

> Found while building 0133 (plan agreed with the human): deleting `peal depend` leaves
> Belfry's `task_defer` refused by `apply`.

---

## Outcome

`peal apply` now takes a `depends` proposal on the task this worktree claims, the case
Belfry's `task_defer` sends once `apply:` is set. When it finds one, it gives the claim back
the way the deleted `peal depend` did. It writes the dependency and a "Deferred <date> after
a claim: <why>" note onto the backlog copy, all in the batch's one
`docs(tasks): apply N proposals` commit. It then commits the claim's file here as
`wip: defer capture [<id>]` so the worktree can go clean. A claim elsewhere (another branch
or worktree) is still refused. Any other kind of proposal on the claim is refused too, even
later in the same batch. So is a claim that has work on it: `_peal_files_no_work`, the check
`peal defer` uses. The new helper `_peal_files_own_claim` in `plugin/lib/store-files.sh`
matches only when this worktree has the task's branch checked out and no other branch
claims the task. Run from the main checkout, the claim reads as a claim elsewhere. A
`"remove": true` with no `why` writes "no longer waits for <on>".

What is given back is main's backlog text, so edits made under the claim (a plan, notes) do
not travel. `peal defer` takes its text on stdin and does carry them. The docs
(`docs/design.md`, `docs/reference/cli.md`) say so. The stale `depend id on wt` row, left by
0133, is gone from design.md's storage table.

`origin/main` (0137, which touched `apply.sh` and `store-files.sh`) was merged in before the
review. `apply.test.sh` passes, 519 tests. The full suite was left to CI.

A security review of the pull request found that the give-back wrote an outsider's `why`
into a backlog task without the `origin: outsider` mark. It is fixed by marking, not
refusing: an `origin: outsider` depends proposal that gives a claim back sets
`origin: outsider` on the task, as `add` does, and `apply.test.sh` covers both cases.
`docs/security.md` now also states the give-back's note and its `wip: defer capture`
commit.

### Reviewer findings not acted on

- The give-back checks in `_pa_load` and `_pa_giveback_capture` copy some checks from
  `peal_store_defer` instead of sharing them: the file-under-`doing/` check, the no-work
  call, the note line and the capture. They are kept as they are. The copies are a few
  lines, and the two paths write different texts (main's versus stdin's).
