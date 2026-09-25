---
plan: required
priority: high
touches: [plugin/lib/hostile.test.sh, .github/workflows/**]
milestone: m1
---

# 0065 — The hostile-input harness on macOS: leftover temp files seen, and a faster CI job

## Intent

The hostile-input harness (`plugin/lib/hostile.test.sh`, 0039) cannot see leftover temp files on macOS, because BSD `mktemp` without a template ignores `TMPDIR`; it prints a note and skips the check there. And the macOS CI job takes about 20 minutes against about 5 on Linux, so every Peal pull request waits four times longer than it needs to. When this is done, the check also runs on macOS, and macOS CI takes a fraction of today's time.

## Scope

- Peal's own `mktemp` calls take an explicit `"${TMPDIR:-/tmp}/peal.XXXXXX"` template (or a shim on the harness's PATH forces it), so the leftover check works on both systems.
- The macOS job runs a smaller set: the harnesses that exercise what differs on macOS (bash 3.2, BSD tools, the file system), with the full set on Linux. Which ones is the planner's call, recorded in the CI file.

## Done when

- The leftover-temp-file check runs on macOS without a note.
- The macOS CI job takes at most a third of today's time on a normal pull request, and the full set still runs on Linux.

## Raw

From an idea 0039's session filed.

## Notes


---

## Outcome

