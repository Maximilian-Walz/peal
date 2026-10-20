---
milestone: m3
plan: required
priority: high
---

# 0154 — `peal apply` reads and answers what Belfry's contract sends

## Intent

`peal apply` (0112, 0132, 0139) and Belfry's `tasks.commands.apply` disagree on the format, so once 0133 adds `apply:` to a project's `.belfry.yml`, Belfry's batches are refused or misread. Belfry's docs/contract.md ("Carrying out proposals", "Proposals") is the reference, and `internal/api/apply.go` and `internal/api/proposal.go` are what Belfry actually sends and reads:

- **`origin`:** Belfry puts it on every proposal (`writer` or `outsider`). Peal accepts it only on `file` and `add`, and answers "field origin is not one priority takes" for the rest. An invalid proposal stops the whole batch, so every batch fails.
- **`ref`:** a plan run's proposals carry Belfry's `ref` (the session's own name for the card). Peal refuses unknown fields.
- **`depends`:** Belfry sends `task`, `on` and `remove: true` to remove a dependency, or no `remove` to add one. Peal requires `op` (`add`, `remove`).
- **`split_milestone`:** Belfry names the milestone to split `milestone`. Peal reads `from`.
- **The answer:** Belfry reads one JSON line per proposal with `id`, `done` (true or false), `outcome` (one line), and `task` for a `file` or `milestone` for a new milestone. Peal answers `status` ("done", "invalid"), `detail` and `change`, so Belfry would read every proposal as not carried out.
- **Fields Belfry leaves out** (it omits empty values): check that a `move` without `milestone` means "no milestone", and that omitted optional fields are read as absent, not as invalid.

Make `peal apply` take and answer exactly that. `origin` is accepted on every kind, and only `file` and `add` act on it. Unknown Belfry-only fields such as `ref` and `item` are ignored. Peal's own `status` and `detail` can stay alongside if anything in Peal reads them.

## Scope

## Done when

## Raw

> Found while applying a batch by hand: peal apply refuses origin on priority and move, though Belfry's contract puts origin on every proposal; depends wants op where Belfry sends remove, split_milestone wants from where Belfry sends milestone, and the answer lines say status/detail where Belfry reads done/outcome. Fix before 0133 adds apply to the contract.

## Notes

- 0133 depends on this: until it is done, `apply:` in a project's `.belfry.yml` makes Belfry's batches fail.
- A test feeds `peal apply` batches shaped exactly as Belfry's `ApplyBatch` marshals them (every kind, with `origin` and a plan's `ref`, and a removing `depends`), and checks the answer lines against Belfry's `ApplyResult`.
- `docs/reference/cli.md` ("peal apply") and the kind list at the top of `plugin/lib/apply.sh` follow the change. 0153's `vouch` kind uses the same shapes.

---

## Outcome

<!-- Written at close, replacing this comment. -->
