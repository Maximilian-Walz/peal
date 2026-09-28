---
milestone: m1
plan: skipped
depends: [milestone]
---

# 0045 — Review milestone m1, Safe in public

## Intent

Close milestone m1 once its tasks are done: walk its acceptance criteria with the
evidence for each, file the loose ends, triage the backlog, and ask the human whether to
close it.

## Scope

Run `/peal:milestone-review m1` in this task's session; it changes the milestone's file
through `peal milestone-state`, nothing else.

## Done when

- The human answered "Close m1?", and on yes the milestone is `done` on the main
  branch.

## Raw

## Notes

- The human, asked "Close m1?" with the review's summary: close it.
- The human, on the queued idea `gate-settings-from-main` (composed for m1, which is
  done before this task's close files it): file it with no milestone.

---

## Outcome

Milestone m1 (Safe in public) was reviewed and, on the human's yes, closed. The full
review is under `## Review, 2026-09-28` in `docs/milestones/m1.md`. `peal milestone-state
m1 done` wrote it there through pull request #103 (m1 `done`, m2 `current`), because
main takes its writes through a pull request. #103's CI passed and it is set to merge
itself. m2 "Adoption" is current once it lands.

- All four acceptance criteria are met, each with evidence: the security docs and
  private vulnerability reporting (checked with `gh api`), the hostile-input harness
  with a clean `tools/lint.sh`, the hook, launcher and init harnesses, and SHA-pinned
  workflows with Dependabot, Scorecard and minimal permissions. None were carried
  forward. There is no `.peal/review.md`, so the review had no project steps to run.
- Loose ends: 0040 had composed four ideas to file once 0061 landed, and they were never
  filed. Three are filed now: `gate-settings-from-main`, `launcher-drift-warning` and
  `close-checks-from-main`. The fourth, `bash32-parse-guard`, is left unfiled because
  0065's macOS job under a forced `/bin/bash` covers it. 0038 noted that
  `docs/security.md` is missing from `.peal/config.yml`'s `context:`, which is filed as
  `security-doc-in-context`. 0041's template pin is already task 0069, and 0062's
  re-label is done (0076, 0085).
- `gate-settings-from-main` was composed for m1. It is filed with no milestone because
  m1 is done before this close files it and the task check would refuse it. The human
  chose no milestone; it can be moved into m2 later.
- Triage: none of the 17 tasks without a milestone plainly belongs to m2, so none was
  moved. There are no parked milestones.
- The review skipped the reviewer: the diff is this task's file only, which lies under
  the skip path `tasks/`.

