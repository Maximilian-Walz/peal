---
milestone: m2
plan: skipped
depends: [milestone]
---

# 0046 — Review milestone m2, Adoption

## Intent

Close milestone m2 once its tasks are done: walk its acceptance criteria with the
evidence for each, file the loose ends, triage the backlog, and ask the human whether to
close it.

## Scope

Run `/peal:milestone-review m2` in this task's session; it changes the milestone's file
through `peal milestone-state`, nothing else.

## Done when

- The human answered "Close m2?", and on yes the milestone is `done` on the main
  branch.

## Raw

## Notes

---

## Outcome

Ran `/peal:milestone-review m2`. The human answered "Close m2?" with "Close it", and
`peal milestone-state m2 done --review ...` marked m2 `done` and m3 `current`. Main takes
writes through pull requests here, so the change and the review, appended to
`docs/milestones/m2.md` under `## Review, <date>`, are in pull request #190, which merges
once its checks pass. Until it merges, `peal milestone-state` still reported
`current milestone: m2`. The review in that file is the full record; in short:

- **Criteria.** 3 of 4 met, with evidence:
  - `peal doctor` (0036): run live here, it named two FAILs, each with a fix, and exited
    1.
  - `/peal:next` (0030, 0097, 0058): run live here, it suggested `decisions`.
  - `peal migrate` (0014): list and board agreed on 587 of 588 of the reference
    project's tasks.
- **Carried forward to m3.** The fourth criterion (README to a first worked task;
  every doc example exercised), at the human's choice:
  - the slash-command half of the walk was never done by hand;
  - four fenced doc examples carry no `docs-check` marker.
- **Ideas queued** (filed with this close): "Walk from the README to a first closed task
  by hand" (m3, owner human), "Every example in the docs is checked by the docs harness"
  (m3), "The config loader refuses invalid values, not only peal doctor" (from 0036),
  "Release and the reaper do not warn about a remote branch already gone" (seen at this
  session's start: the warnings for 0058 and 0113 came from stale tracking refs of
  branches GitHub had already deleted).
- **Triage.** No tasks without a milestone. `later` stays parked (no `until`, reason
  holds).

For the next session and the human:
- Post-merge checks still open: the triage "add" verdicts for 0067 and 0068 (0103/0113)
  have not landed dated lines yet; 0069's Dependabot page is unconfirmed.
- This machine: `peal doctor` reports stale hook stubs (`.peal/peal hooks install` from
  the main checkout) and a releasable claim of 0064 (`.peal/peal release 0064`).
- `peal milestone-state` printed `could not lock config file .../.git/config` in the
  sandbox and went on; that is 0101's ground.

The diff lies only in the review skip paths (`tasks/`), so no reviewer ran.

