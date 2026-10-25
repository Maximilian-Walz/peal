---
plan: required
priority: low
touches: [plugin/lib/commit.test.sh]
size: S
merge: auto
---

# 0209 — commit.test.sh covers a checks.commit refusal and a failed index restore

## Intent

Task 0093 made `peal commit` restore the index after it refuses a commit. Two of those paths have no test yet:

1. A refusal caused by a failing `checks.commit` item. The index should be put back the way it was before the commit started.
2. A restore that fails itself. `peal commit` should exit 1, keep the index snapshot and name its path.

Add a test case for each to `plugin/lib/commit.test.sh`. This task adds tests only. If a test shows the behaviour is wrong, that is an open question for the planner, not part of this task's scope.

## Scope

Tests only, in `plugin/lib/commit.test.sh`; `plugin/lib/commit.sh` is not changed.

## Done when

- `plugin/lib/commit.test.sh` has a case for each path (a `checks.commit` refusal, a failed index restore), and the harness is green.

## Raw

> commit.test.sh covers a checks.commit refusal and a failed index restore
>
> ## Intent
>
> 0093 made `peal commit` put the index back after a refusal. Two paths are still untested: a refusal caused by a failing `checks.commit` item, and a restore that itself fails (exit 1, snapshot kept, path named). Add tests for both.
>
> ## Done when
>
> - `plugin/lib/commit.test.sh` has a case for each path.
>
> ## Notes
>
> - From the m3 milestone review (0093's Outcome).

## Notes

- From the m3 milestone review (0093's Outcome).
- Open question: how to make the restore fail reliably in a test (for example a read-only index, or a stubbed restore step) without changing `plugin/lib/commit.sh` just to make it testable.
- `docs/reference/configuration.md` describes `checks.commit`.
- 2026-10-25, plan agreed with the human:
  - Done when: a case for each path, and the harness is green.
  - Case 1 also covers the run without paths (`git add -A`), and proves the restore both byte for byte (`cmp` of `.git/index`) and by what is staged.
  - Case 2 covers the snapshot branch only (an index existed) and rides on the new-backlog-file refusal (its exit 2 becomes 1). The human left both choices to the session, which took the cleaner one.
  - After a failed restore, the test asserts nothing about the live index; it only restores it as cleanup.

## Plan

Tests only; `plugin/lib/commit.sh` is unchanged. If a test shows wrong behaviour, stop and report it.

**Case 1, `checks.commit` refusal.** Goes after the "the gate judges only the named path" block, before the config reset (about line 153).
- Write `.peal/config.yml` with `checks: commit: ["false"]`.
- Stage `p` as `p1`, change it on disk to `p2`, and create an untracked `e`.
- Copy `.git/index` to a scratch file and record HEAD.
- Run `check_fails "..." 1 "false failed; the commit is refused" peal commit "feat: e [0001]" e`.
- Check:
  - HEAD is unchanged;
  - `cmp -s` of the saved copy against `.git/index`;
  - `git show :p` is `p1`;
  - `e` is still `?? e`.
- Repeat without paths (the `git add -A` branch, mirroring lines 112-115): `check_fails` plus `cmp`.
- Clean up, and put the config back to `commit: []`.

**Case 2, failed restore (the snapshot branch).**
- `_peal_commit_restore` (commit.sh:16-33) calls `mktemp "$index.peal.XXXXXX"`, `cp -p` and `mv -f` by name.
- The test writes a `mktemp` shim into a scratch dir. It exits 1 when its arguments contain `index.peal.` and otherwise execs the real `mktemp`, captured with `command -v mktemp`.
- Pre-stage `q`, create `tasks/backlog/0011-x.md` (the new-backlog-file refusal, normally exit 2), and copy the index.
- Run `PATH="$shim:$PATH" TMPDIR=<scratch> check_fails "..." 1 "could not restore the index; the original is kept at" peal commit "feat: e [0001]"`.
- Parse the path after "kept at " from stderr, and check:
  - the file exists;
  - `cmp -s` of it against the saved index;
  - no `.git/index.peal.*` is left behind;
  - HEAD is unchanged.
- Assert nothing else about the live index.
- Clean up: restore the index from the snapshot (or `git reset -q`), and remove the snapshot, `q` and the backlog file.

**Header comment:** add both cases to the list at lines 7-9.

Rejected: a read-only `.git` (it fails under root and breaks git's own lock files), a `git` shim (the restore doesn't call git), and a test hook in `commit.sh` (out of scope).

**Files:** `plugin/lib/commit.test.sh`.

**Verification:**
- `bash plugin/lib/commit.test.sh` is green, including under `PEAL_TEST_AWK=<an installed awk>`.
- During development only, remove the shim from PATH and confirm that case 2 then fails.

**Ranges:**
- plugin/lib/commit.sh:16-33, 120-162
- plugin/lib/commit.test.sh:1-20, 100-153, 193-196
- plugin/lib/test-lib.sh:22-28, 41-60, 62-87
- plugin/lib/task-fixtures.sh:15-22, 68-72
- plugin/lib/githooks.sh:124-130, 485-487, 590-639
- plugin/bin/peal:527-530
- docs/reference/configuration.md:37

---

## Outcome

`plugin/lib/commit.test.sh` now covers the two `peal commit` refusal paths from task 0093 that had no test. `plugin/lib/commit.sh` is unchanged, and no wrong behaviour turned up.

- **A `checks.commit` refusal.**
  - Setup: the config holds `checks.commit: ["false"]`. `p` is staged as `p1` and changed on disk; an untracked `e` exists.
  - Two runs: one with a named path, one without paths (`git add -A`).
  - Each run asserts:
    - the gate's own message, "false failed; the commit is refused";
    - HEAD is unchanged;
    - the index is byte for byte what it was (`cmp`);
    - `p` is still staged as `p1`, and `e` is still untracked.
- **A failed index restore** (the snapshot branch).
  - How it fails: a `mktemp` shim, put first on PATH, fails only for the restore's `index.peal.*` argument and passes every other call to the real `mktemp`. The restore calls `mktemp`, `cp` and `mv` by name, never git, so `commit.sh` needed no hook to be testable.
  - It rides on the new-backlog-file refusal, whose normal exit 2 turns into 1, so the restore failure is shown to decide the status.
  - The test asserts:
    - the "kept at PATH" message;
    - the snapshot at PATH equals the original index;
    - no `.git/index.peal.*` is left behind;
    - HEAD is unchanged.
  - It asserts nothing about the live index afterwards; that behaviour is unspecified.
  - Mutation check: without the shim, case 2 fails.
- **Cleanup** restores the index from a baseline copy rather than `git reset`, because later cases expect `g` to still be staged.
- **Harness:** 222 passed, 0 failed, under mawk, nawk and busybox awk.

The reviewer found that case 1 at first asserted only `peal commit`'s generic refusal text, which any commit-msg refusal would match. It was fixed to assert the gate's own message (5deec59). No ideas were filed.

