---
milestone: m3
plan: required
---

# 0153 — `peal apply` takes a `vouch` proposal that drops a task's `origin: outsider`

## Intent

Belfry is adding a human-only "Vouch for this text" action (Maximilian-Walz/belfry#588): the human reads an outsider's task and says its text is to count as a writer's from then on. On a project with Belfry's `tasks.commands.apply`, Belfry carries it out as one `vouch` proposal. `peal apply` can set `origin: outsider` today (through `file`, and through `add` with `origin: outsider`), but no kind clears it. Add a `vouch` kind: field `task` (plus the usual `why`). It drops `origin` from the task's frontmatter and adds a dated line under its Notes saying who vouched and why, in the batch's one commit like every other kind.

## Scope

## Done when

## Raw

> Belfry will let the human vouch for an outsider's task (belfry#588). On a commands project it sends a vouch proposal through tasks.commands.apply; peal apply needs a vouch kind that drops origin: outsider from the task file and records it.

## Notes

- Checks as for the other kinds: the task is in the backlog, nobody claimed it, and the batch leaves valid frontmatter. Vouching for a task without `origin` is refused as invalid, or answered done with "already a writer's" (the planner decides which).
- A Notes line from outside stays quoted as data, as it is. Vouching changes the task's origin, not the history of its text.
- `docs/reference/cli.md` ("peal apply") and the kind list at the top of `plugin/lib/apply.sh` name it. `apply.test.sh` covers it, and `hostile.test.sh` feeds `task` and `why` the hostile values as for the other kinds (mind 0152: keep those tries fast).
- Belfry offers Vouch on a commands project only with `apply`, so no single command is needed.

---

## Outcome

<!-- Written at close, replacing this comment. -->
