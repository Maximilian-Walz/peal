---
milestone: m1
priority: high
plan: required
depends: []
size: M
model: opus
touches: [plugin/lib/main-write.sh, plugin/lib/main-write.test.sh, plugin/lib/store-files.sh, plugin/lib/fake-gh, plugin/lib/tasks.sh, plugin/lib/tasks.test.sh, plugin/bin/peal, tools/lint.sh, .github/workflows/ci.yml, docs/design.md]
---

# 0073 — Two filings at once never give two tasks the same id

## Intent

Since writes to a protected main go through pull requests (0061), two filings can
pick their id from different states of main: #71 and #72 both filed a 0069, and both
merged, so the backlog held two tasks with one id. Every command that looks a task up
by id is then ambiguous. When this is done, a filing whose id is taken by the time its
pull request merges is renumbered first, and the lint refuses a tree with duplicate ids,
so CI catches what slips through.

## Scope

- The main-write path: before merging (or when its PR conflicts), check the id against
  the current main and renumber the task file, its heading and any `depends`/`part-of`
  in the same PR that name it.
- The lint: duplicate ids in the tasks directories fail, naming both files.
- The rivals: every open same-repository pull request against main with a lower
  number, not only Peal's own filings; pull requests from forks never count.
- CI runs `peal check` (through `tools/lint.sh`); `docs/design.md` says so.

## Done when

- Harnesses: two filings from the same base end as two ids; a tree with a duplicate id
  fails the lint.
- A filing raced by a hand pull request (not `peal/main-write-*`) ends under a free id
  in one replacement, without using up its attempts.
- `tools/lint.sh` runs `peal check`, and Peal's own tree passes it.

## Raw

Found when 0069 was filed twice on 2026-09-25; the later filing's text was renumbered
to 0070 by hand.

## Notes

The human's answers when the plan was agreed (2026-09-27), all the planner's defaults:

- Cause: #71 was a hand pull request from `chore/file-0069`, which the rival check
  (only `peal/main-write-*`) never saw. Fix: widen the rivals to every same-repository
  pull request against main, rather than forbidding hand filings.
- Keep the return-at-once auto-merge design (`docs/design.md`, 0061): check at open
  time with the wider rivals, check again before Peal's own merge, and let CI be the
  backstop. Filings do not skip auto-merge.
- "Renumber" means building the filing again from the texts Peal holds (placeholders
  `NNNN`/`PART<k>`/`ORIGIN`); no new command and no CI job.
- CI runs the branch's `peal check` from `tools/lint.sh`, not a separate `ci.yml` step.
- Making that CI job a required check on main is a human step, listed in the pull
  request; no settings change here.
- The duplicate check covers backlog, doing and done together, every `NNNN-*.md`,
  nothing for the issues storage. Message: `peal: task id 0069 is used by A and B`.
  `list`, `board` and `read` do not warn.
- A higher-numbered rival that merges first is left to CI (lower number wins).
- Pull requests from forks never count as rivals (`head.repo` is this repository); no
  cap on how far an id may jump.
- On the `pr` route the rivals are fetched before the first build as well.
- The `push` route stays free of `gh`; a clash there is left to CI.
- Each replacement pull request gets its own `PEAL_MAIN_WRITE_BUDGET`, as now.
- Conflicts found after the command returned stay the human's job, as in 0061.
- Docs: update the Races paragraph and the `peal check` bullet of `docs/design.md`;
  nothing new about hand filings.
- Model opus; merge default (the human merges).

## Plan

Size M, built by opus.

A. Rivals (`plugin/lib/main-write.sh`, `plugin/lib/store-files.sh`). The rival list of
`_peal_mw_pr` becomes every open pull request against main with a lower number whose
`head.repo` is this repository (not only `peal/main-write-*`); heads are fetched by
`head.ref`, as today. `_peal_files_next_id` also counts the ids on those fetched rival
heads, so the rebuild does not pick the same id again and loop until
`PEAL_PUSH_ATTEMPTS` runs out. On the `pr` route the same fetch runs before the first
build, so the common case picks a free id at once.

B. Check before Peal's own merge (`_peal_mw_merge_self`). When the checks are READY
and before the `PUT pulls/N/merge`, fetch main and the rivals again and run
`PEAL_MW_TAKEN`. If an id is taken, close the pull request and return 5, so the
existing loop rebuilds (file, heading, `depends`/`part-of` renumbered through the
placeholders) and opens a replacement ("Replaces #N"). The conflict path already
rebuilds; nothing new there.

C. The lint (`plugin/lib/tasks.sh`, `plugin/bin/peal`). A new `peal_check_ids`, called
from `cmd_check`, for task files only (a no-op for issues): every `NNNN-*.md` under
backlog, doing and done in the work tree; one line per duplicated id naming all its
files, `peal: task id NNNN is used by <a> and <b>` (and more); exit 2.
`tools/lint.sh` runs `PEAL_ROOT=$PWD/plugin plugin/bin/peal check`.

D. Docs: `docs/design.md` Races paragraph and the `peal check` bullet.

Verification:
- `plugin/lib/main-write.test.sh` (`protected "main-writes: pr"`, `fake_github`):
  1. a hand pull request `chore/file-0002` with a lower number adds
     `tasks/backlog/0002-rival-task.md`; the filing ends as 0003, its first pull
     request closed, the replacement "Replaces #N" adding exactly `0003-my-task.md`;
  2. that case needs one replacement, not `gave up after 5`;
  3. with `no-auto-merge` and `checks-pending=2`, a rival lands 0002 on main while the
     checks wait; the filing closes before the `PUT`, rebuilds as 0003 and merges;
     main holds 0002 and 0003 once each;
  4. a raced two-piece `--batch` whose second text depends on the first (`PART1`):
     both renumbered, the `depends` names the new id;
  5. a lower-numbered fork pull request (`head.repo` another repository) does not
     renumber the filing.
- `plugin/lib/tasks.test.sh`: `backlog/0002-a.md` with `done/0002-b.md` makes `peal
  check` exit 2 naming both; three files with one id name all three; a tree without
  duplicates exits 0; Peal's own tree passes.
- `tools/test-all.sh` and `tools/lint.sh` pass; bash 3.2 compatible.

Ranges relied on:
- tasks/done/0061-main-writes-through-a-pull-request.md:37-42, 64-86, 108-114
- plugin/lib/main-write.sh:55-127, 137-207, 240-269
- plugin/lib/store-files.sh:74-80, 275-306, 348-408
- plugin/lib/main-write.test.sh:25-52, 131-203, 231-240
- plugin/lib/fake-gh:1-28, 213-255
- plugin/lib/tasks.sh:115-170
- plugin/lib/tasks.test.sh:277-293
- plugin/bin/peal:263-272
- tools/lint.sh:1-21
- .github/workflows/ci.yml:1-41
- docs/design.md:413-415, 542-588

---

## Outcome

Built as planned (A to D). The 0069 twins came from a hand pull request
(`chore/file-0069`), which the rival check never saw because it only looked at
`peal/main-write-*` branches.

- **Rivals** (`_peal_mw_rivals`, `plugin/lib/main-write.sh`): every open pull request
  against main with a lower number whose head is in the repository itself
  (`.head.repo.full_name == .base.repo.full_name`; the configured repository can fall
  back to the literal `{owner}/{repo}`, so it is not used). Fork pull requests never
  count, so a stranger cannot burn numbers. The rival heads are fetched to
  `refs/remotes/<remote>/<head.ref>` and listed in `PEAL_MW_RIVALS`, which
  `_peal_files_next_id` counts. That is what stops a rebuild from picking the same id
  and looping. On the `pr` route the fetch also runs before the first build, but only
  for writes that set `PEAL_MW_TAKEN` (filings). The `push` route still makes no `gh`
  call.
- **Check before Peal's own merge:** `_peal_mw_merge_self` runs the check again once
  the checks are READY and before the `PUT`. When an id is taken it closes the pull
  request and returns 5, and the existing loop rebuilds and opens "Replaces #N". Pull
  requests that GitHub auto-merges are not checked again, as agreed; CI is their
  backstop. The open-time check and the pre-merge check now share
  `_peal_mw_taken`/`_peal_mw_taken_drop`.
- **Lint:** `peal_check_ids` in `peal check` (task files only) prints
  `peal: task id NNNN is used by A and B` for each duplicated id across backlog, doing
  and done, and exits 2. `tools/lint.sh` runs the branch's `peal check` after
  shellcheck. `.github/workflows/ci.yml` is unchanged: its `shellcheck` job already runs
  `tools/lint.sh`, and keeping the job's name keeps any required-check setting valid.
- **Harnesses:** in `main-write.test.sh`, `hand_race`, `split_race`, `merge_race` and
  `fork`. `plugin/lib/fake-gh` gained `$FAKE_GH/on-check-runs`, a script run once at
  the next check-runs read, so a rival can land while the checks are polled. In
  `tasks.test.sh`, `duplicates`.
- **Departure:** the "raced two-piece `--batch`" case is a `--part-of` split instead.
  `PART1` only works in split mode (`task-check.awk` refuses it in a batch).
- `docs/design.md`: the Races paragraph and the `peal check` bullet are updated.
- **Merged origin/main** (0070's idea queue and action bumps) before closing. There were
  no conflicts.

**Next session:** a higher-numbered rival that merges first, a direct push racing an
open hand pull request, and an auto-merged filing raced after it returned are all left
to CI. So the CI `shellcheck` job must be a required check on main (a human step in
the pull request). The review found nothing.
