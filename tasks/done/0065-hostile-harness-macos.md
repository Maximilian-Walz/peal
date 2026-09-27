---
plan: required
priority: high
touches: [plugin/lib/hostile.test.sh, .github/workflows/ci.yml, tools/test-all.sh]
milestone: m1
size: M
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

- The planner found that CI's history contradicts the premise. Since 0039, Linux takes 29-36 minutes and macOS 21-24 (runs 36129832834 and 36163270642), so Linux is the job pull requests wait on.

The human's answers (2026-09-27):
- Goal: the macOS job at most 1/3 of today's time, as written. The Linux time becomes a follow-up idea, filed from this task.
- mktemp: a shim in the harness, not explicit templates in Peal's own calls.
- macOS: log `bash --version` and the awks found, and force `/bin/bash`. If that turns up real bash 3.2 failures, stop and ask rather than fix them here.
- The hostile harness's `arg_cases` and `hook_cases` run on Linux only; macOS runs `self_test` and `awk_channels`.
- README and docs/security.md stay as they are.
- Only the mktemp note must go; the APFS invalid-UTF-8 note stays.
- The macOS set is an include list, with a comment in ci.yml.
- Job names stay as they are (they are required checks on main).

## Plan

**The mktemp shim.** `plugin/lib/hostile.test.sh` records the real `mktemp` (`command -v mktemp`) before building `$STUBS`, then writes `$STUBS/mktemp`. When no argument contains `XXX`, the shim appends the template `"${TMPDIR:-/tmp}/tmp.XXXXXXXX"`; otherwise it passes the call through to the real mktemp unchanged. Every Peal run in the harness already goes through `PATH="$STUBS:$PATH"` (`assess`, `claim_wt`, `hostile_repo`), and git hooks inherit that PATH. The probe (lines 524-528) runs through the shim, so the "mktemp here ignores TMPDIR" note no longer appears on macOS; the note stays in the code as a guard. The self-test's `unsafe.temp` goes back to a bare `mktemp >/dev/null`, so "a temp file left is caught" proves the shim works on both systems.

**The harness runner.** `tools/test-all.sh` takes harness paths as arguments; with none, it finds them all, as now. It prints each harness's elapsed seconds.

**CI.** `.github/workflows/ci.yml` keeps the matrix and both job names and sets a `harnesses` value per OS through `matrix.include`. Linux runs everything. macOS runs an include list, with a comment saying why each harness is in it:
- `plugin/templates/githook.test.sh` and `plugin/templates/launcher.test.sh`: they run in other people's repositories, and bash 3.2 broke them in 0040.
- `tools/install.test.sh`
- `plugin/lib/githooks.test.sh`
- `plugin/lib/frontmatter.test.sh`: BSD awk and sed.
- `plugin/lib/store-files.test.sh`: `find`, file names, and worktrees on APFS.
- `plugin/lib/hostile.test.sh` with `PEAL_HOSTILE_CASES="self_test awk_channels"`.

The macOS job also logs `bash --version` and the awks found, and forces `/bin/bash` through a PATH shim directory. The set is then trimmed or grown against the measured per-harness times.

**Verification.**
- Locally on Linux:
  - The hostile harness passes, including with `PEAL_HOSTILE_CASES=self_test`.
  - Make a Peal function skip removing a temp file, check that the harness reports `temp files left:`, then revert.
  - `tools/test-all.sh` with no arguments finds all 26 harnesses; given paths, it runs only those and prints timings.
  - `tools/lint.sh` is clean.
- On the pull request's CI:
  - The macOS log has no `mktemp here ignores TMPDIR` note.
  - The macOS job takes at most 7 minutes (baseline 21m0s in run 36163270642).
  - Linux runs all 26 harnesses and passes.
  - The pull request body quotes the per-harness timings.

**Ranges relied on:** plugin/lib/hostile.test.sh:27-47, 144-218, 281-285, 508-533, 558-589; plugin/lib/test-lib.sh:17-28, 62-87; .github/workflows/ci.yml:1-42; tools/test-all.sh:1-32; README.md:95-97; tasks/done/0039-hostile-input-harness.md:155-206; tasks/done/0040-safe-hooks-and-launcher.md:310-337; plugin/templates/githook:177; plugin/lib/frontmatter.sh:83.

Touches: plugin/lib/hostile.test.sh, .github/workflows/ci.yml, tools/test-all.sh.


---

## Outcome

**What was built.**
- **The mktemp shim.** `plugin/lib/hostile.test.sh` records the real `mktemp` and writes a `mktemp` shim into `$STUBS`, which is on the PATH of every Peal run in the harness and of the git hooks those runs install. When a call has no `XXX` template, the shim appends `"${TMPDIR:-/tmp}/tmp.XXXXXXXX"`; otherwise it passes the call through unchanged. With it, BSD `mktemp` writes under the harness's `TMPDIR`, where the leftover-temp-file check looks.
- **The self-test and the note.** The self-test's `unsafe.temp` is a bare `mktemp` again, so "a temp file left is caught" proves the shim works. The "mktemp here ignores TMPDIR" probe runs through the shim and stays as a guard. The APFS invalid-UTF-8 note is untouched, as agreed.
- **The harness runner.** `tools/test-all.sh` takes harness paths as arguments (with none, it finds every harness, as before) and prints each harness's elapsed seconds.
- **CI.** `.github/workflows/ci.yml` sets a harness list per OS through `matrix.include`; the job names are unchanged, because they are required checks.
  - Linux runs every harness, all hostile groups included, plus the coverage check.
  - macOS runs an include list with a comment explaining each entry: the githook and launcher templates, install, githooks, frontmatter, store-files, and the hostile harness with only `self_test` and `awk_channels`.
  - macOS also forces `/bin/bash` (bash 3.2) through a PATH shim, and logs its version and the awks it finds.

**What was decided, and why** (the human's answers are under Notes):
- A shim, not explicit templates at Peal's ~55 call sites: it touches only the harness, covers future calls, and changes no code on users' machines.
- An include list for macOS: a new harness runs on Linux only until someone adds it here.
- Forcing `/bin/bash`, because the image's Homebrew bash 5 would otherwise hide bash 3.2. If bash 3.2 failures show up, the human is asked rather than having them fixed in this task.

**Verified.**
- Locally on Linux:
  - The full hostile harness: 1616 passed, 0 failed, no notes.
  - With `self_test` alone: 5 passed.
  - With `claim.sh`'s temp-file cleanup removed on purpose, `awk_channels` reported `temp files left:` (then reverted).
  - `test-all.sh` with no arguments finds all 26 harnesses; given paths, it runs only those.
  - `tools/lint.sh` is clean.
- The reviewer, with a fake `mktemp` that ignores TMPDIR as BSD's does: main prints the note, this branch doesn't, and the self-test catches a temp file left behind.
- The macOS timings and the log without the note can only come from this pull request's CI. CI runs only on pull requests, so the per-harness times are added to the pull request once its run is done.

**Found and left.**
- The Linux job (29-36 minutes since 0039) is the one pull requests actually wait on, not macOS (21-24). Filed as the idea `speed-up-linux-ci`, as the human asked.

**For the next session.** If the macOS job misses 7 minutes, trim the include list in ci.yml against the per-harness times that `test-all.sh` prints in the job log.

