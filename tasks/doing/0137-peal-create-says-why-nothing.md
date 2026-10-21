---
plan: required
touches: [plugin/lib/store-files.sh, plugin/lib/tasks.sh, plugin/lib/main-write.sh, plugin/lib/decisions.sh, plugin/lib/store-files.test.sh, plugin/lib/hostile.test.sh]
milestone: m3
size: M
---

# 0137 — `peal create` says why nothing was filed; the macOS hostile-stdin check is flaky

## Intent

On macOS CI, the `plugin/lib/hostile.test.sh` check "create --owner --title: hostile stdin filed, to compare it byte for byte" failed once on a pull request whose code had nothing to do with it. `peal create --owner ai --title "Hostile hex byte check"` printed only the seeded backlog's warnings and then "nothing was filed", with no line saying why. A rerun passed; main is green.

Two things follow. First, `peal create` must never fail silently: wherever `peal_push_main` returns non-zero on the create path (`plugin/lib/store-files.sh`, where `nothing was filed` is printed), the user gets a one-line reason on stderr. Second, find what actually made the push fail on macOS and make the hostile check robust against it, so it passes reliably there and, if it ever fails again, its failure message shows that reason.

## Scope

- `peal create` (every form, the `--owner/--title` contract included) never ends with "nothing was filed" without a reason line above it: the extract pipe, the depends-cycle check's listing, `_peal_files_overlay`'s status, and `peal_push_main`'s silent returns.
- Remove the likely macOS cause: `git archive | tar -x` under pipefail when bsdtar stops reading before the archive's padding (git dies of SIGPIPE, silently). The same pipe in `decisions.sh` is fixed too.
- The hostile byte-for-byte check shows the status and reason when it fails; no retry.

## Done when

- Every non-zero return of `peal create` prints a one-line reason on stderr before "nothing was filed" (that line itself unchanged).
- `peal_push_main`'s "failed, and not from a race:" output is flattened to one line too.
- New `store-files.test.sh` tests with stub `tar`s (one closing stdin early over a >1 MiB tasks tree; one failing) pass, and the existing harnesses stay green.
- A temporary macOS CI stress run (old vs new pipe, 500 each, plus 5 hostile awk_channels runs) has run, been reverted before review, and its counts are in the Outcome.

## Raw

> `peal create` says why nothing was filed; the macOS hostile-stdin check is flaky
>
> ## Intent
>
> On macOS CI (PR #219, task 0127, unrelated code), the `plugin/lib/hostile.test.sh` check "create --owner --title: hostile stdin filed, to compare it byte for byte" (around line 407) failed once. `peal create --owner ai --title "Hostile hex byte check"` printed only the seeded backlog's warnings and "nothing was filed", with no error naming why. A rerun passed, and main is green.
>
> Find why `peal_push_main` failed without a message (`plugin/lib/store-files.sh` around 380-398, where `nothing was filed` is printed). Make every failure path there say why, and make the test robust against whatever made it flaky.
>
> ## Done when
>
> - Every non-zero return of `peal_push_main` in the create path carries a one-line reason on stderr.
> - The hostile check prints that reason when it fails, and passes repeatedly on macOS.

## Notes

- Open question: the cause is unknown and the failure happened once. The CI log of PR #219's failed macOS run is the first evidence to read, if it is still kept. Possible causes to rule out: a race with another push to the test's origin, a timing-dependent retry or lock in `peal_push_main`, BSD-vs-GNU tool differences, a git hook in the test's work tree.
- Open question: "passes repeatedly on macOS" needs a way to show it, e.g. running the check in a loop on a macOS runner. Is one CI run enough evidence, or should the plan add a stress loop?
- The check's output captures `2>&1` and takes only the last line as the id; once a reason is printed it should appear in the `not filed:` text with no other change, but check that the warnings of the seeded backlog don't hide it.
- `docs/reference/cli.md` documents `peal create`; update it if the error output changes in a way it describes.
- 2026-10-21, from the planning session: the failed macOS log (run 39164703986 attempt 1) is unreachable from the session; the diagnosis is from the code. Human's answers: widen Done-when to every silent create failure, push_main's included; fix `decisions.sh`'s identical pipe here; run the temporary CI stress loop and keep the fix whatever its counts; keep the "nothing was filed" line unchanged; flatten the new reasons and push_main's existing multi-line failure output to one line; trust tar's exit 0 after the drain (no ls-tree count check); fix `_peal_files_overlay`'s status here; file an idea for hostile `try()` flagging a status-2 run with no `peal:` reason line.

## Plan

**Diagnosis.** The failure was before `peal_push_main`: the seeded backlog's warnings are printed on create only when `_peal_cycle_records` (`tasks.sh:248-254`) sees `peal_store_list` fail; `_peal_files_scan` returns 2 when `_peal_files_extract` (`store-files.sh:52-55`, `git archive | tar -x` under `set -uo pipefail`, `bin/peal:5`) fails, which it does silently if bsdtar exits before git's last write (git: SIGPIPE, 141). `try()` accepts status 2, so only the byte-for-byte check notices.

**Approach.**
1. `_peal_files_extract`: drain the pipe after tar (`{ tar -x -C "$3"; s=$?; cat >/dev/null; exit $s; }`), capture git's and tar's stderr, and on failure print one line `could not read <path> at <ref>: <reason>` (flattened, as `peal_git_try`, `common.sh:138-147`) and return 2.
2. `decisions.sh:388`: use the same extract (or the same drain).
3. `_peal_cycle_records`: on a failed listing add `create: could not list the tasks on <remote>/<main> to check for depends cycles`.
4. `_peal_files_overlay` (`store-files.sh:263-276`): return awk's status, not `rm -rf`'s.
5. `peal_push_main`: a reason before each silent `return 2` (`mktemp` `:132`, `commit-tree` `:164`); `_peal_files_build_create` reports its own `peal_write_tree` failure (`store-files.sh:469`); flatten "failed, and not from a race:" plus git's output to one line (`main-write.sh:202-205`), updating the tests that pin it.
6. `hostile.test.sh:436-448`: capture the status and print `not filed (status N): $bout`; no retry.
7. `store-files.test.sh`: a `tar` stub on PATH that reads one byte, closes stdin, exits 0, against a tasks tree over 1 MiB (create files); a `tar` stub that prints "tar: boom" and exits 1 (create and list: status 2, the reason line, then "nothing was filed" for create).
8. A temporary commit adding a macOS CI step: 500 runs each of the old pipe and the new extract against a hostile-sized tree, counting non-zero statuses, plus `PEAL_HOSTILE_CASES=awk_channels` 5 times; read the counts, revert the commit before review, record the counts in the Outcome. The fix stays either way.

**Files.** `plugin/lib/store-files.sh`, `plugin/lib/tasks.sh`, `plugin/lib/main-write.sh`, `plugin/lib/decisions.sh`, `plugin/lib/store-files.test.sh`, `plugin/lib/hostile.test.sh`; temporarily `.github/workflows/ci.yml`. No `docs/reference/cli.md` change (`cli.md:253-270` does not describe the error output).

**Verification.** The new tests; `store-files.test.sh:289-304`, `main-write.test.sh:155-158`, `hostile.test.sh`, `backlog.test.sh`, the apply and decisions harnesses, `tools/lint.sh`; the macOS stress counts.

**Ranges.** `plugin/bin/peal:5`, `plugin/bin/peal:185-190`, `plugin/bin/peal:461`, `plugin/lib/store-files.sh:38-77`, `plugin/lib/store-files.sh:263-300`, `plugin/lib/store-files.sh:326-341`, `plugin/lib/store-files.sh:377-477`, `plugin/lib/main-write.sh:109-215`, `plugin/lib/main-write.sh:380-384`, `plugin/lib/main-write.sh:404-426`, `plugin/lib/tasks.sh:7-39`, `plugin/lib/tasks.sh:56-85`, `plugin/lib/tasks.sh:215-254`, `plugin/lib/tasks.sh:286-307`, `plugin/lib/backlog.sh:103-218`, `plugin/lib/common.sh:132-147`, `plugin/lib/config.sh:29-46`, `plugin/lib/decisions.sh:381-393`, `plugin/lib/hostile.test.sh:55-110`, `plugin/lib/hostile.test.sh:381-449`, `plugin/lib/hostile.test.sh:913-962`, `plugin/lib/store-files.test.sh:265-304`, `plugin/lib/main-write.test.sh:152-159`, `.github/workflows/ci.yml:37-83`, `docs/reference/cli.md:253-270`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
