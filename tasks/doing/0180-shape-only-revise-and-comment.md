---
plan: required
size: M
depends: []
touches: [plugin/lib/githooks.sh, plugin/lib/work.sh, plugin/lib/issues-text.awk, plugin/lib/store-issues.sh, docs/security.md]
milestone: m6
priority: high
---

# 0180 — Shape-only revise and comment pushes cannot drop origin: outsider, add merge or fill ## Plan; an outsider's labelled issue with ## Plan does not read as PLAN agreed

## Intent

Two routes let hostile text become an agreed plan or an unmarked task. First, the pre-push shapes `modify`, `apply` and `add` (`_peal_pre_push_direct` in `plugin/lib/githooks.sh`) check the path, mode and count of a `docs(tasks): revise 0180` push but never the frontmatter or sections of the new blob. A commit with that subject that modifies one backlog file passes with any text: `origin: outsider` gone, `merge: auto` added, or `## Plan` filled (which `plugin/lib/work.sh` reads as `PLAN agreed`). Only a `vouch` proposal should drop the mark. Second, on the issues storage `origin` is never set, so `plan` comes from labels and a filled `## Plan` in the body reads as `agreed`; the re-label check covers edits after labelling, not a plan that was already in the body when the maintainer labelled the issue. Under plain Claude Code `/peal:work` then starts the implementer on the stranger's plan. When this is done neither route turns text from outside into consent.

## Scope

- The `modify`, `apply` and `add` shapes parse the old and new blobs with the awk the storage uses and refuse when `merge` appears, `origin` disappears or changes, or `## Plan` or `## Outcome` goes from empty to filled, unless the subject is a `vouch` or a `record` the storage itself made.
- Issues storage: an issue whose `author_association` is not owner, member or collaborator counts as `origin: outsider` in `_peal_issues_text` so `peal work` forces `PLAN required`, or its `## Plan` and `## Outcome` are stripped from the body unless the task is a writer's.
- Links 0161, which gates the pull request route (`peal merge-gate`, `plugin/lib/merge-gate.sh`: a task file gaining a `merge` key fails the pull request); this task keeps the direct-push route, and may reuse `merge-gate.awk` to read the raw `merge` of a blob. 0122 (`peal comment --origin` on the issues storage) is the same family: do it here or leave it linked.

## Done when

- Tests: a direct revise push that removes `origin: outsider`, one that adds `merge`, and one that fills `## Plan` are each refused by the gate.
- A test: an issue by a stranger whose body holds `## Plan` reads as `PLAN required`, not `agreed`.
- `docs/security.md` says both limits are closed, with the tests.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Security review findings 7 and 8 (MEDIUM, read). Check 0161 (a task-files pull request setting `merge: auto` on another task; it is moved into this milestone) and 0122 first and take what the plan finds they share rather than doing it twice.
- Security: touches the "nothing reaches main but..." and "hostile prose is read, never run" boundaries; update `docs/security.md` here.

---

## Outcome

<!-- Written at close, replacing this comment. -->
