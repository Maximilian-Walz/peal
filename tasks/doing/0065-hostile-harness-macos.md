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

Draft plan from the planner (2026-09-25). The human has not agreed it: the questions timed out in the inbox twice, so there is no `## Plan` yet. The next session asks these questions again instead of replanning.

- mktemp: a shim in hostile.test.sh's `$STUBS` adds `"${TMPDIR:-/tmp}/tmp.XXXXXXXX"` when a call gives no template. The probe (hostile.test.sh:524-528) goes through the shim, and the self-test's `unsafe.temp` uses a bare `mktemp` again.
- `tools/test-all.sh` takes harness paths as arguments and prints per-harness time. It is outside the current touches.
- ci.yml keeps its job names (they are required checks) and gets a per-OS harness list through `matrix.include`. macOS runs githook, launcher, install, githooks, frontmatter, store-files, and hostile with `PEAL_HOSTILE_CASES="self_test awk_channels"`. Linux runs all 26. Target: macOS at most 7 minutes (today 21-24).
- Size M, model sonnet, merge by a human.
- CI history contradicts the premise: since 0039, Linux takes 29-36 minutes and macOS 21-24 (runs 36129832834, 36163270642). Linux is the job pull requests wait on.

Open questions (the recommended answer first):
1. Goal: the macOS job at most 1/3 as written, with a follow-up idea for Linux; or make pull requests wait less?
2. mktemp: the shim, or explicit templates at about 55 call sites?
3. macOS: log the bash and awk versions and force /bin/bash, stopping on bash 3.2 failures; log only; or leave it?
4. Hostile arg_cases and hook_cases on Linux only, or the whole harness on macOS?
5. README.md:95-97: leave it as is, or add a clause about the macOS subset?
6. Keep the APFS invalid-UTF-8 note (only the mktemp note must go)?
7. macOS as an include list with a comment, or a skip list?


---

## Outcome

