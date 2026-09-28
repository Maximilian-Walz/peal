---
milestone: m2
plan: required
size: M
touches: [plugin/lib/migrate*, plugin/bin/peal, plugin/lib/hostile.test.sh, docs/design.md]
---

# 0014 — Migration from an existing task-file process

## Intent

A project with its own task-file process adopts Peal by migrating, not rewriting: tasks
keep their numbers, history stays, the project's own tooling keeps working through the
extension points. See `docs/design.md`, "Migrating an existing project".

## Scope

- `peal migrate headers`: rewrites `key: value` task headers (trailing comments, space-
  or comma-separated lists) into frontmatter; maps the pools to milestones (numbered
  milestone to its id, unassigned to none, a never-offered pool to a `parked` milestone,
  a by-name-only pool to an `open` one); reports what it cannot convert; changes nothing
  else in the file.
- `peal migrate milestones`: frontmatter for existing milestone docs (newest `current`,
  earlier `done`) plus the milestones the pools need.
- `plugin/lib/hostile.test.sh`: the `migrate` case its coverage check requires.
- `docs/design.md`, "Migrating an existing project": pools named by flags rather than
  fixed words, the "any" pool statement corrected.
- `docs/migrating.md` is split off into 0096 (`depends: [0014]`).

## Done when

- Both converters run clean over a copy of the reference project's `tasks/` and
  milestone docs (read from its main branch, never edited), and `peal list` and `peal
  board` there agree with the reference's own task-state and board output on every
  task's done/free/blocked state.
- `plugin/lib/migrate.test.sh` and `plugin/lib/hostile.test.sh` pass.

## Raw

Filed as issue #14 (https://github.com/Maximilian-Walz/peal/issues/14); its text is carried over into the sections above and below.

## Notes

The migration of the reference project itself is a task of its own, in that project.

Split: `docs/migrating.md` is 0096, a piece of this task.

The human's answers while planning:
- The reference copy for the Done-when comparison comes as a tarball the human puts into
  the job's attachments directory: a `git archive` of the reference's main branch
  (`tasks`, `docs/milestones`, its task-state and task-board scripts and their library)
  plus the output of its own task-state and task-board with `--no-pr`. Nothing from it is
  committed; the Outcome records counts only, and never names the reference project or
  its paths.
- A numbered milestone doc gets `id: mNN` (digits as in its file name, `milestone-08.md`
  gets `id: m08`); files are not renamed.
- Pool names are flags (`--parked`, `--open`, `--none`) with no defaults.
- A never-offered recurring pool (the reference's "any") becomes its own parked
  milestone, not folded into another; `docs/design.md`'s claim that it held only the
  drift check is corrected.
- "State for state" compares done/free/blocked; claim states need branches a copy lacks.
- Touching `hostile.test.sh` and `docs/design.md` beyond the original Scope: allowed.

The human's answer during the build: a few real task files carry a prose paragraph right
under the `key: value` block, with no `## ` heading before it. The header ends at the
first blank line after its `key: value` lines (comment-only continuation lines count as
header); what follows, prose included, is body and stays byte-for-byte. `migrate headers`
then runs clean (exit 0) over the whole reference copy.

## Plan

**`peal migrate headers [--parked P,...] [--open P,...] [--none P,...]`**
(`plugin/lib/migrate.sh`, parser/renderer `plugin/lib/migrate-headers.awk`, dispatched
from `plugin/bin/peal` with usage lines):

- Walks `{tasks}/{backlog,doing,done}/NNNN-slug.md` in the work tree (config `tasks`,
  default `tasks`; no `.peal/config.yml` needed). A file whose first line is already
  `---` is left alone, so a second run is a no-op. Non-numbered files (`TEMPLATE.md`, an
  unnumbered checklist) are skipped silently.
- Header block: every line after the `# NNNN — Title` line up to the first `## `
  heading. Only `key: value` lines, blank lines and comment-only continuation lines may be
  in it; anything else is reported.
- Values: a trailing ` # ...` is stripped; an empty value drops the key; `depends` and
  `needs` split on `[ ,]+` into a flow list; other keys stay scalars, quoted with
  `yaml-render.awk`'s `yaml_scalar`. Keys known: milestone, plan, depends, size, part-of,
  needs, model; an unknown key is reported and the file left untouched.
- Milestone field: a number N maps to `mN` with N's digits as in the milestone doc's
  file name (`08` → `m08`); a value in `--none` drops the field; a value in `--parked` or
  `--open` stays as the id; anything else is reported.
- Output: `---`, the fields in original order, `---`, a blank line, the title line, then
  the rest of the file from the first `## ` heading byte-for-byte. The header lines and
  the blank line under them are what goes.
- The result is checked with `peal_fm_check` before replacing the file. A file with any
  problem is left entirely untouched and named on stderr; exit 1 if any file was
  reported, 0 otherwise. Never commits.

**`peal migrate milestones [--parked P,...] [--open P,...]`:**

- Each `*.md` in the milestones directory without frontmatter and whose file name ends in
  a number gets `id: mNN`, `state` (highest number `current`, the rest `done`) and
  `order` (the number); the title defaults to the heading. A doc without a number in its
  name is reported, not guessed.
- Each `--parked`/`--open` pool without a file gets `<pool>.md` with `state: parked|open`
  and a one-line `# <Pool>` heading; no order, no reason.
- Refuses to make a second `current` when one exists. Reports every milestone id a task
  uses that has no milestone file. Safe to run again; never commits; no refusal on main.

Rejected: hardcoding a project's pool names (project vocabulary); renaming milestone
files (breaks links, "history stays"); converting through `peal_fm_set` field by field
(cannot remove the old header, not byte-exact).

**Files:** `plugin/lib/migrate.sh`, `plugin/lib/migrate-headers.awk`,
`plugin/lib/migrate.test.sh` (new); `plugin/bin/peal`; `plugin/lib/hostile.test.sh`;
`docs/design.md` (lines 1012–1035: pools by flag, not "later"/"process"; line ~482: the
"any" pool held more than the drift check).

**Verification:**

- `plugin/lib/migrate.test.sh`, on `task-fixtures.sh` repos with synthetic, anonymised
  fixtures (nothing copied from the reference):
  - headers: title/blank/header/blank/`## Intent` → frontmatter/blank/title/rest,
    byte-exact against an expected file; trailing comment incl. indented comment-only
    continuation lines; `depends: 0297, 0269`, `depends: 0608 0609`, `depends: 0230
    human` → flow lists; `needs: a, b, c`; empty `depends:`/`size:` dropped;
    `milestone: 08` → `m08`, a `--none` pool dropped, `--parked` pools and the `--open`
    pool kept as ids; a `model: some/path` line under `## Notes` untouched;
    `TEMPLATE.md` and a non-numbered file skipped; a prose line in the header, an
    unknown pool, an unknown key → file unchanged, reported, exit 1; second run no-op.
  - milestones: three numbered docs get the right id/state/order; pool files created;
    existing frontmatter left alone; an existing `current` prevents a second; a task
    milestone with no doc reported.
  - end-to-end: a fixture repo with a review task on `depends: milestone`, a split origin
    with pieces, `depends: human`, deps done and not done, a recurring task in a
    never-offered pool, done tasks in every pool; converted, committed, pushed; `peal list
    --no-pr` states asserted against a hand-derived table, `peal board --no-pr` states
    match `peal list`, `peal check` clean.
- `bash plugin/lib/hostile.test.sh` passes, its coverage check included; `tools/test-all.sh`.
- The Done when, one-off, outside Peal's tree: extract the attachments tarball into a
  scratch repo with a bare remote under `$TMPDIR`; run the reference's task-state and
  task-board `--no-pr` there (or use the supplied output); run both converters (exit 0,
  nothing reported), commit, push; `peal list --no-pr` and `peal board --no-pr`; diff the
  `id state` pairs on done/free/blocked: empty. `task-board` needs `jq`. The Outcome
  records counts only.

Reference facts (from its main branch; for the implementer, never for the repo):
- Header layout: title on line 1, blank line, the `key: value` header, blank line,
  `## Intent`. Its parser reads every line before the first `## `.
- Keys seen: milestone, plan, depends, size, part-of, needs, model; empty values common.
- Milestone values: two-digit NN, `unassigned`, `later`, `process`, `any`. Milestone docs
  `milestone-01.md`..`milestone-08.md`, no frontmatter, first line `# Milestone NN —
  Title`. No backlog task on milestones 01–07.
- Trailing comments only in `TEMPLATE.md`, which also has indented comment-only lines.
- `key:`-like prose appears under `## ` headings (e.g. `model: art/...` in Notes).
- Read-model differences the reference does not trigger today: its `depends: milestone`
  on a non-numbered milestone warns and is ignored, Peal's expands; Peal drops a depends
  token that is not NNNN/milestone/human, the reference counts it unmet.

Ranges relied on: `docs/design.md:120-316`, `docs/design.md:441-507`,
`docs/design.md:1012-1035`, `plugin/bin/peal:63-252`, `plugin/bin/peal:389-452`,
`plugin/lib/milestones.sh:6-46`, `plugin/lib/milestone-read.awk:1-76`,
`plugin/lib/frontmatter.sh:1-93`, `plugin/lib/frontmatter-write.awk:1-70`,
`plugin/lib/task-scan.awk:1-117`, `plugin/lib/task-state.awk:1-34`,
`plugin/lib/task-state.awk:110-140`, `plugin/lib/task-state.awk:194-220`,
`plugin/lib/tasks.sh:296-333`, `plugin/lib/config-defaults.yml:8-9`,
`plugin/lib/config.sh:1-21`, `plugin/lib/task-fixtures.sh:1-79`,
`plugin/lib/hostile.test.sh:1-30`, `plugin/lib/hostile.test.sh:268-297`,
`plugin/lib/hostile.test.sh:760-820`, `tools/test-all.sh:1-41`.

---

## Outcome

Built `peal migrate headers` and `peal migrate milestones` (`plugin/lib/migrate.sh`,
`plugin/lib/migrate-headers.awk`, dispatched from `plugin/bin/peal`), their harness
`plugin/lib/migrate.test.sh` (synthetic fixtures only, every case under mawk, nawk and the
system awk), a `migrate` group in `plugin/lib/hostile.test.sh`, and the migration section
of `docs/design.md` rewritten for pool flags.

- **Headers.** A numbered task file without frontmatter gets its `key: value` header
  lifted into a `---` block. Trailing comments are dropped, empty fields are dropped,
  `depends`/`needs` become flow lists, and the milestone is mapped (N → `mNN` with the
  digits as in the file name, `--none` pools dropped, `--parked`/`--open` pools kept as
  ids). The rest of the file stays byte-for-byte. A file with any problem is left
  untouched and named on stderr, exit 1. A second run changes nothing; non-numbered files
  (`TEMPLATE.md`) are skipped. Nothing is committed.
- **Milestones.** Numbered docs get `id: mNN`, `state` (highest `current`, the rest
  `done`) and `order`. Pool files `<pool>.md` are created as `parked`/`open`. It refuses a
  second `current` and reports milestone ids used by tasks that have no file.
- **Decided:**
  - Pool names are flags with no defaults, so no project's vocabulary is built in.
  - Milestone files are not renamed; an `id:` field carries the new id.
  - A never-offered recurring pool becomes its own parked milestone; `docs/design.md`'s
    claim that it held only the drift check is corrected.
  - The header ends at the first blank line after its `key: value` lines, not at the
    first `## ` heading. This was a mid-build correction by the human (see Notes): real
    files put prose right under the header.
- **Hardening beyond the plan:**
  - Pool names from `--parked`/`--open` are validated against the milestone id shape
    before they become file names. The hostile harness caught `--parked ../../x`
    writing outside the milestones directory.
  - A comment-only line is a single `#`, so a `## ` heading is never swallowed as a
    comment.
- **Review fix:** a trailing comment on an empty value (`size:   # S, M or L`) was
  converted as the value, and a comment after a tab was not stripped. Both are fixed,
  with tests.
- **The Done when.** Over a copy of the reference project's main branch (supplied by the
  human, extracted and converted outside this repository, nothing from it committed):
  - both converters exit 0 with nothing reported;
  - `peal list --no-pr` and `peal board --no-pr` agree with the reference's own
    task-state and board output on done/free/blocked for 587 of 588 tasks;
  - the one left out is claimed in the real clone, a claim the copy cannot carry (the
    human agreed claim states are out of the comparison);
  - `migrate.test.sh` and `hostile.test.sh` pass.
- **Next:**
  - 0096 (split from this task) writes `docs/migrating.md`, the procedure around these
    commands.
  - The reference project's own migration is a task in that project.
