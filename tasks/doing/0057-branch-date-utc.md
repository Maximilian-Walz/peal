---
plan: required
priority: high
touches: [plugin/lib/store.sh, plugin/lib/store-files.sh, plugin/lib/store-issues.sh, plugin/lib/tasks.test.sh, plugin/lib/store-issues.test.sh]
milestone: m1
size: S
merge: auto
---

# 0057 — Branch-date detail in UTC: the "every state" and "parked" harness checks fail around midnight

## Intent

Print the branch date in UTC so it matches the rest of Peal, for example
`TZ=UTC git log -1 --format=%cd --date=format-local:%Y-%m-%d ...`. Put it in one shared helper that both stores call, not two copies. This fixes the real inconsistency and not only the tests. Setting `TZ=UTC` in the harnesses would only hide it.

## Scope

- A shared helper `peal_ref_date_utc REF` in `plugin/lib/store.sh`, called by `store-files.sh` and `store-issues.sh` for the parked `last <date>` detail.
- One fixed-date pin check each in `plugin/lib/tasks.test.sh` and `plugin/lib/store-issues.test.sh`.
- Out: `docs/design.md`, CI, `task-fixtures.sh`.

## Done when

- `store-files.sh` and `store-issues.sh` print the `last <date>` detail as the UTC date of the branch's last commit, through one shared helper
- `plugin/lib/tasks.test.sh` and `plugin/lib/store-issues.test.sh` pass with a time zone whose date differs from UTC's at the moment of the run (for example `TZ=Pacific/Kiritimati` or `TZ=Etc/GMT+12`), and with `TZ=UTC`
- A harness check pins this: a branch commit whose local date differs from its UTC date (set through `GIT_COMMITTER_DATE` with an offset) shows the UTC date

## Raw

Filed as issue #57 (https://github.com/Maximilian-Walz/peal/issues/57) from an idea a session had; its text is carried over into the sections above.

## Notes

A parked task's list detail reads `N commit(s) ahead, last <date>`. Both stores build it the same way:

- `plugin/lib/store-files.sh:153`: `git log -1 --format=%cd --date=short "refs/heads/$lb"`
- `plugin/lib/store-issues.sh:125-126`: the same call

`--date=short` prints the commit date in the time zone the commit recorded, which in the harnesses is the machine's local zone. The harnesses compare against `today=$(date -u +%Y-%m-%d)` from `plugin/lib/task-fixtures.sh:10`, which is UTC.

When the local date and the UTC date differ (for example 00:00–02:00 CEST), these checks fail:

- `plugin/lib/tasks.test.sh:79`: "every state" (the `0006 parked ... last $today` line)
- `plugin/lib/store-issues.test.sh:106`: "every state" (the `7 parked ... last $today` line)
- `plugin/lib/store-issues.test.sh:501`: "parked"

Every other date Peal writes is already UTC: `Revised`, `Deferred` and `Retired` notes (`backlog.sh`, `store-files.sh`), decisions (`decisions.sh`), and the session and deferral timestamps (`session.sh`, `backlog.sh`).

The human's answers when agreeing the plan:

- The shared helper lives in `plugin/lib/store.sh`, named `peal_ref_date_utc REF`, commented as a helper shared by the stores and kept out of the storage interface list.
- `docs/design.md` stays as it is; the Outcome mentions that `last <date>` is now UTC.
- No CI or tooling change to run the suite under a non-UTC zone: the fixed-date pin checks guard it.
- One pin check in each harness. The date stays the committer date (`%cd`). No minimum git version is recorded (`format-local` needs git 2.7). `task-fixtures.sh` needs no change. A harness run that crosses UTC midnight between sourcing the fixtures and the parked commit can still fail: noted in the Outcome, not fixed.
- Merge: auto.

## Plan

**Approach.**

- Add `peal_ref_date_utc REF` to `plugin/lib/store.sh`, below `peal_store_load`. It prints the UTC calendar date of the ref's last commit: `TZ=UTC git log -1 --format=%cd --date=format-local:%Y-%m-%d "$1"`. Git's `format-local` is portable across GNU and BSD, unlike `%ct` piped to `date`.
- Call it from both stores in place of `git log -1 --format=%cd --date=short`:
  - `plugin/lib/store-files.sh:162`
  - `plugin/lib/store-issues.sh:130-131`
- Add a pin check to each harness, in its own repository so the "every state" expectations and the later whole-list comparisons stay untouched:
  - `plugin/lib/tasks.test.sh` for the files store;
  - `plugin/lib/store-issues.test.sh` for the issues store, using `issues_repo` and `issue N`, with the branch set up as for issue 7 at lines 84-87.
  - Each check commits on a parked branch with `GIT_COMMITTER_DATE='2026-03-01T23:30:00-05:00'` and expects `last 2026-03-02`. It may add a second commit the other way, `2026-03-02T00:30:00+14:00`, expecting `2026-03-01`.
- The existing `last $today` checks need no change: `today` is already `date -u`.

**Verification.**

- The pin checks fail with the helper temporarily reverted to `--date=short`. Check this locally; do not commit the revert.
- These runs pass:
  - `TZ=Pacific/Kiritimati`, `TZ=Etc/GMT+12` and `TZ=UTC bash plugin/lib/tasks.test.sh`;
  - the same three with `plugin/lib/store-issues.test.sh`.
- `tools/test-all.sh` passes, and shellcheck passes on the changed files.

**Touches:** `plugin/lib/store.sh`, `plugin/lib/store-files.sh`, `plugin/lib/store-issues.sh`, `plugin/lib/tasks.test.sh`, `plugin/lib/store-issues.test.sh`.

**Ranges relied on:**

- plugin/lib/store-files.sh:136-175
- plugin/lib/store-issues.sh:102-137
- plugin/lib/store.sh:1-89
- plugin/lib/task-fixtures.sh:1-79
- plugin/lib/tasks.test.sh:1-110
- plugin/lib/store-issues.test.sh:1-125
- plugin/lib/store-issues.test.sh:480-509
- docs/design.md:78-85
- tools/test-all.sh:1-32
- .github/workflows/ci.yml:17-40

---

## Outcome

**Built.** A parked task's list detail, `N commit(s) ahead, last <date>`, now always shows the UTC calendar date of the branch's last commit. That matches every other date Peal writes.

- The date comes from one helper, `peal_ref_date_utc REF`, in `plugin/lib/store.sh` below `peal_store_load`. It runs `TZ=UTC git log -1 --format=%cd --date=format-local:%Y-%m-%d`.
- It is commented as shared by the stores and is not part of the storage interface.
- `store-files.sh` and `store-issues.sh` call it instead of their own `--date=short` calls.
- Each harness (`tasks.test.sh`, `store-issues.test.sh`) has a `branch_date_utc` case in its own repository. It commits at `2026-03-01T23:30:00-05:00` and expects `last 2026-03-02`, then at `2026-03-02T00:30:00+14:00` and expects `last 2026-03-01`.
- Both cases fail when the helper is switched back to `--date=short`. That was checked locally and not committed.

**Verified.** After merging origin/main, both harnesses pass under `TZ=Pacific/Kiritimati`, `TZ=Etc/GMT+12` and `TZ=UTC`. `tools/test-all.sh` passes, and shellcheck is clean on the changed files.

**Decided, with the human.**

- The helper lives in `store.sh`, because that file loads both stores.
- The date is the committer date (`%cd`).
- `docs/design.md` is unchanged: its `last <date>` does not say that the date is now UTC.
- No CI run under a non-UTC time zone: the fixed-date cases guard against a regression.
- No minimum git version is recorded. `format-local` needs git 2.7 or later.

**Left.**

- A harness run that crosses UTC midnight can still fail. The window is between `task-fixtures.sh` computing `today` and a later parked commit made at the real time. That is rarer than the bug fixed here and was accepted, not fixed.
- The implementer once saw `store-issues.test.sh` fail under `TZ=Etc/GMT+12` with busybox awk while other test runs were going at the same time. It did not recur when run alone, before or after the merge.

**Found.** One of the implementer's `peal commit <paths>` calls also committed about 22 sandbox placeholder files that were already staged. Commit 912623c un-tracks them again, and the net diff does not include them. `peal commit` commits the whole index, not only the paths it is given: filed as the queued idea "peal commit with paths commits only those paths".

