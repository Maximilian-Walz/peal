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
