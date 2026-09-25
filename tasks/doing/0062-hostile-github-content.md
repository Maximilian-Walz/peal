---
milestone: m1
plan: required
depends: [0039]
part-of: 0039
size: M
touches: [plugin/lib/store-issues.sh, plugin/lib/issues-*.awk, plugin/lib/claim.sh, plugin/lib/work.sh, plugin/lib/ship.sh, plugin/lib/store-files.sh, plugin/lib/*.test.sh, plugin/lib/issue-fixtures.sh, plugin/lib/fake-gh, plugin/commands/setup.md, plugin/commands/commands.test.sh, docs/security.md, docs/design.md]
---

# 0062 — Hostile GitHub content: the write-access rule on every issues read

## Intent

On the issues storage, text from strangers (issue titles, bodies, labels, comments, pull
requests) must reach a session only when the write-access rule or the filter label admits
it. Extend the hostile-input harness to the issues storage's channels and make every read
path apply the rule.

## Scope

- `plugin/lib/issues-lib.awk`, `issues-scan.awk`, `store-issues.sh`: one admission rule,
  applied on every read path of the issues storage.
- `plugin/lib/claim.sh`, `work.sh`: the refusal for an issue the rule does not admit.
- `plugin/lib/ship.sh`: release notes take no stranger's text.
- `plugin/lib/store-files.sh`: fork pull requests supply no task's PR URL.
- `plugin/commands/setup.md`: the issue sample only from write-access openers.
- `plugin/lib/hostile.test.sh`, `issue-fixtures.sh`, `store-issues.test.sh`,
  `ship.test.sh`, the files storage's tests, `plugin/commands/commands.test.sh`.
- `docs/security.md`, `docs/design.md`.

## Done when

- Every read path of the issues storage (read, the claim's cache, work, defer, ship,
  setup's sample) applies the one rule, `admitted()` in `issues-lib.awk`.
- `peal read`, `claim` and `work` refuse an issue the rule does not admit, with the agreed
  message, and quote none of its text.
- `hostile.test.sh` runs the issues storage's channels with outsider content and shows
  that nothing runs, nothing is written outside, and no outsider text reaches any output,
  and that no command reads comments.
- The files storage takes no PR URL from a fork's pull request.
- `docs/security.md` names the boundary and its known limits.

## Raw

> Check that every read path of the issues storage applies the write-access rules
> (issues, comments, PRs), and that text from outsiders reaches a prompt only quoted as
> data.

Split from 0039

## Notes

- Agreed with the human while planning 0039: when `peal read`, `claim` or `work` is
  given a stranger's issue that no filter label admits, Peal refuses it and says that
  adding the filter label (or re-filing it) makes it a task.
- Read paths 0039's planner found: `peal_store_read` for issues (reads any number), the
  depends-extra reads, `peal init --survey`'s issue count, `/peal:setup`'s
  `gh issue list`, `ship`'s issue and PR reads. Pull requests are already filtered.
- Reuses 0039's `plugin/lib/hostile.test.sh`, adding the fake-`gh` channels (outsider
  `author_association`, titles, labels, milestone titles, bodies).
- Size estimate: M.
- Planning 0062, the human agreed:
  - Scope and Done when as the planner proposed.
  - With no filter label configured, the refusal names both ways: set
    `storage.issues.label` and label the issue, or file it anew yourself (`peal idea`).
  - With a filter label set, an owner's unlabelled issue is refused too ("not
    labelled", no mention of write access).
  - `work` in a worktree whose task cache is empty refuses, with read's reason or
    "could not read".
  - A stranger editing a labelled issue afterwards is accepted for now, listed in
    security.md as a known limit; a follow-up idea (m1) adds the re-label check
    (admit only when the last edit precedes the labelling or is by someone with write
    access, otherwise ask the maintainer to re-label).
  - ship applies the rule; setup.md's issue sample is filtered here (0063 edits
    setup.md too); `init --survey`'s count stays as is, with a harness case.
  - Depending on a stranger's issue stays allowed (its state is read); documented.
  - The files storage's fork-PR URL gap is fixed in 0062.
  - Comments: the harness proves no command reads them; no filter is built.

## Plan

Size M, model default, merge default.

1. `admitted(assoc, labels, label)` in `plugin/lib/issues-lib.awk`: the filter label is
   set and among the issue's labels (trimmed, exact), or no label is set and the opener
   is OWNER, MEMBER or COLLABORATOR. `issues-scan.awk` (line 26) uses it instead of its
   inline test; `store-issues.sh` adds `_peal_issues_admitted ROW`, a one-line awk over
   the `PEAL_ISSUES_ROW` row (field 5 labels, field 6 association). One rule.
2. `peal_store_read` (store-issues.sh:191-200) refuses an issue the rule does not admit,
   status 2, quoting no title: `refused: issue N is no task: opened by someone without
   write access to OWNER/REPO [and not labelled 'L']; labelling it 'L' or filing it anew
   yourself (peal idea) makes it a task`. With no label configured: `set
   storage.issues.label and label it, or file it anew yourself (peal idea)`. An owner's
   unlabelled issue under a label: refused as not labelled. `_peal_issues_cache` and
   `peal_store_session_task` go through read, so they are covered.
3. `peal_store_defer` (store-issues.sh:565): the same refusal after fetching the row.
4. `_peal_claim_one` (claim.sh:206-210): when the list has no record for the id, run
   `peal_store_read "$id" >/dev/null` and pass on its refusal, else `no task N`.
   `peal_work` (work.sh:22-29) in a worktree with an empty task text refuses with read's
   reason (or "could not read") instead of printing `TASK id <empty file>`.
5. ship (ship.sh:185-212): an issue the rule does not admit gets the commit subject in
   the release notes instead of its title; the Outcome sentence is read only from a PR
   from the repository itself or by someone with write access (as `_peal_issues_prs`).
6. `/peal:setup` (setup.md:50-54): `gh issue list --limit 20` becomes a `gh api` read
   filtered with jq to write-access openers; `commands.test.sh` checks setup.md no longer
   says `gh issue list`.
7. `_peal_files_prs` (store-files.sh:178-201): drop pull requests from forks
   (`isCrossRepository`), so a fork's branch named like a task branch supplies no PR URL;
   a test in the files storage's tests.
8. Left as they are, each with a harness case: `init --survey`'s count; the depends
   extras (store-issues.sh:75-79, 282-287; only state is used); milestones and labels
   (write or triage access only); comments (never read; the harness asserts it).
9. Harness: group `issues_channels` in `plugin/lib/hostile.test.sh`, under every awk. A
   `hostile_issues_repo` reusing `issue-fixtures.sh`'s `fake_github`, `issue`,
   `milestone`, `pr` against a local bare remote, `storage.kind: issues`. Seeds: NONE,
   CONTRIBUTOR and FIRST_TIME_CONTRIBUTOR issues whose title, body and labels hold each
   hostile value plus the marker `OUTSIDER-TEXT`; OWNER issues with hostile fields
   (`size: $(...)`, `touches: ../../escape`); a hostile milestone title and
   description; fork and repository PRs with hostile bodies; outsider comments; all
   again under a filter-label config. Runs list, board, overview, milestones, offer,
   read, claim and work (each id), revise --dry-run, set-milestone, retire, init
   --survey, ship notes. New assess kinds `outsider text` (marker in stdout or stderr;
   assess captures stdout to a file) and `read comments` (fake-gh log), each with a
   self-test case. `check_refused` for read, claim and work on a stranger's issue.
   Without jq: skipped with a NOTES line, failing under `PEAL_REQUIRE_JQ`.
10. Functional tests: `store-issues.test.sh` (read, claim, work refused on a NONE issue
    with the message; a labelled stranger's issue readable; an owner's unlabelled issue
    refused under a label; defer refused); `ship.test.sh` (no stranger's title, no fork
    PR body in the notes).
11. Docs: `docs/security.md` gains the boundary "Only admitted issues reach a session"
    with its guard and harnesses, known limits (edits after labelling; a stranger's
    issue as a dependency), and its "Hostile prose" harness line loses "is task 0039".
    `docs/design.md` (about 229-232, 628-632): a sentence on the refusal and the harness.
12. Ideas to queue: the re-label check for edits after labelling (m1).

Rejected: a new store interface function for claim's message (read's refusal already
carries the reason); filtering inside `_peal_issues_issue` (breaks the extras, the edit
comparison in `_peal_issues_apply` and `_peal_issues_context`).

Verification: `bash plugin/lib/hostile.test.sh`, `store-issues.test.sh`,
`ship.test.sh`, the files storage's tests, `plugin/commands/commands.test.sh`,
`tools/test-all.sh`, `tools/lint.sh`.

Ranges: plugin/lib/hostile.test.sh:1-589, plugin/lib/store-issues.sh:22-85,
plugin/lib/store-issues.sh:134-200, plugin/lib/store-issues.sh:267-289,
plugin/lib/store-issues.sh:402-424, plugin/lib/store-issues.sh:537-590,
plugin/lib/store-issues.sh:685-694, plugin/lib/store-issues.sh:798-809,
plugin/lib/issues-lib.awk:1-66, plugin/lib/issues-scan.awk:1-51,
plugin/lib/issues-text.awk:1-65, plugin/lib/github.sh:46-73, plugin/lib/fake-gh:1-267,
plugin/lib/issue-fixtures.sh:1-111, plugin/lib/store-issues.test.sh:15-165,
plugin/lib/test-lib.sh:1-90, plugin/lib/claim.sh:201-253, plugin/lib/claim.sh:270-277,
plugin/lib/work.sh:19-47, plugin/lib/backlog.sh:60-73, plugin/lib/ship.sh:183-212,
plugin/lib/init.sh:484-557, plugin/lib/store-files.sh:175-201,
plugin/commands/setup.md:48-74, docs/design.md:224-232, docs/design.md:610-658,
docs/security.md:17-27, docs/security.md:71-114, .github/workflows/ci.yml:29-34.


---

## Outcome

<!-- Written at close, replacing this comment. -->
