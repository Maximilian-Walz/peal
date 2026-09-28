---
milestone: m1
plan: required
depends: []
size: M
touches: [plugin/lib/issues-lib.awk, plugin/lib/store-issues.sh, plugin/lib/store-issues.test.sh, plugin/lib/hostile.test.sh, plugin/lib/fake-gh, plugin/lib/issue-fixtures.sh, docs/security.md, docs/design.md]
---

# 0076 — Issues storage: a stranger's edit after labelling is still admitted

## Intent

On the issues storage, `admitted()` (`plugin/lib/issues-lib.awk`) checks only the
opener's write access or the filter label; a stranger who edits an already-labelled
issue afterwards passes unnoticed, since nothing compares the issue's last edit to when
it was labelled or claimed. Close that gap: admit an edit only when it precedes the
labelling, or comes from someone with write access; otherwise ask the maintainer to
re-label before the edit's text reaches a session.

## Scope

- `plugin/lib/issues-lib.awk` (`admitted()` or a sibling check), `plugin/lib/store-issues.sh`
  (wherever the labelling event's time is available, e.g. the label's own timeline event
  via `gh api repos/OWNER/REPO/issues/N/timeline`, or the issue's `updated_at` against a
  stored labelling time).
- `plugin/lib/hostile.test.sh`'s issues channels, `plugin/lib/store-issues.test.sh`.
- `docs/security.md`'s "Only admitted issues reach a session" section: replace the known
  limit this closes with the new guard and harness.
- Agreed beyond the first Scope: `plugin/lib/fake-gh` and `plugin/lib/issue-fixtures.sh`
  (the harnesses need them), and one sentence in `docs/design.md` naming the guard.
- Single-issue paths only (read, claim, work, revise, close, defer, session cache); the
  listing, board, offer and ship notes stay a narrower known limit, filed as a follow-up.

## Done when

- An issue labelled (or opened by someone with write access), then edited afterwards by
  someone without write access, is refused the same way an unadmitted issue is, unless
  the edit itself is by someone with write access; on every single-issue path.
- With no filter label configured, no extra `gh` call is made.
- When the edit data cannot be read, or no `labeled` event is found, the issue is refused
  rather than admitted.
- A harness case in `plugin/lib/hostile.test.sh`'s issues channels covers a labelled
  issue edited by an outsider afterwards; `store-issues.test.sh` covers `read` directly.
- `docs/security.md` drops this known limit and describes the new guard instead.

## Raw

Task 0062's Notes, agreed while planning it: "A stranger editing a labelled issue
afterwards is accepted for now, listed in security.md as a known limit; a follow-up idea
(m1) adds the re-label check (admit only when the last edit precedes the labelling or is
by someone with write access, otherwise ask the maintainer to re-label)."

## Notes

Split from 0062. GitHub's REST API does not timestamp a label's own addition directly on
the issue resource; the timeline API (`.../issues/N/timeline`, events of type
`labeled`) or the events API gives it, at the cost of another `gh` call per issue read -
weigh that against caching it alongside the claim label the way `_peal_issues_cache`
already does for the text.

Agreed with the human while planning:
- Paths: single-issue paths only; `docs/security.md` keeps a narrower known limit (the
  listing and release notes may show a title edited after labelling, never the body, and
  claiming refuses it), filed as a follow-up idea.
- Write access is inferred, no permission call: an editor who is not the author must be
  a writer; the author counts when their association is OWNER, MEMBER or COLLABORATOR.
- Only the last body edit (`lastEditedAt`/`editor`) and the latest title rename count.
- The labelling time is the latest `labeled` event of the filter label; the claim label
  vets nothing and is ignored; with no filter label no check runs.
- Fail closed: no `labeled` event found means the issue's `createdAt` is the labelling
  time; a failing GraphQL call refuses with status 2 (`could not read issue N's edits`).
- `fake-gh`, `issue-fixtures.sh` and one `docs/design.md` sentence change beyond Scope,
  noted in the pull request.
- Size M, implementer on the default model, merged by a human.

## Plan

**Approach.** When `PEAL_LABEL` is set, a single-issue read also runs one GraphQL query
(`peal_gh graphql`, owner/name split from `PEAL_REPO`):
`repository{issue(number){author{login} lastEditedAt editor{login}
timelineItems(last:100, itemTypes:[LABELED_EVENT, RENAMED_TITLE_EVENT]){nodes{__typename
... on LabeledEvent{createdAt label{name}} ... on RenamedTitleEvent{createdAt actor{login}}}}}}`.
`updated_at` is not used (the claim label and Peal's comments bump it).

- `store-issues.sh`: new `_peal_issues_edits N`, its `--jq` reducing the answer to one
  TSV line (latest labelling of `PEAL_LABEL` or `createdAt`, author, `lastEditedAt`,
  editor, latest rename time, renamer). `_peal_issues_admitted ROW [N]` keeps today's
  rule and, under a label, also calls the awk sibling. `_peal_issues_refuse` gains the
  reason: `refused: issue N is no task: edited after it was labelled 'LABEL' by someone
  without write access to REPO; read the edit, then take the label 'LABEL' off and add it
  again to make it a task` (no issue text, no login). Header comment updated.
- `issues-lib.awk`: `edit_admitted(labelled_at, author, assoc, edited_at, editor,
  renamed_at, renamer)` next to `admitted()`: 1 when no edit is later than
  `labelled_at` (ISO-8601 Z compares as strings); else each later edit must be by a
  non-author editor or by an author with OWNER/MEMBER/COLLABORATOR; a missing (ghost)
  editor is refused.
- Every single-issue path already goes through `_peal_issues_admitted`
  (`peal_store_read`, `peal_store_defer`), so read, claim, work, revise, close, defer and
  the session cache are covered.
- `fake-gh`: its GraphQL branch answers the edits query from new optional `issues.json`
  fields (`author_login`, `last_edited_at`, `editor`, `labeled_events`,
  `renamed_events`). `issue-fixtures.sh`: `issue()` gains `--labelled-at`,
  `--edited-at T BY`, `--renamed-at T BY` (or an `issue_edit` helper).
- `docs/security.md` 159-181: drop the re-label known limit, describe the guard, keep the
  narrower listing/title limit; `docs/design.md` 742-750: one sentence on the guard.

**Verification.**
- `store-issues.test.sh` `admission()` under `issues_repo_label`, refusals checked with
  `check_refused` against the exact message: a stranger's body edit after labelling is
  refused on `read`, `claim` and `defer --dry-run`; a stranger's rename after labelling is
  refused; an edit before labelling, a maintainer's edit, the owner's own edit and a
  re-label after the edit are admitted; another label's events have no effect; no label
  configured means `calls 'POST graphql'` is 0; a failing GraphQL call refuses, status 2.
- `hostile.test.sh` `issues_channels`: a `label: tasks` block with an `--assoc NONE`
  issue labelled, then edited in body and title by its author with `OUTSIDER-TEXT` and
  `$(touch $CANARY/...)`; `try` read, claim, work, revise --dry-run and defer: nothing
  runs, the marker reaches no output, no comments are read.
- Full suites and `shellcheck`; the reviewer forces `edit_admitted` to return 1 on a
  scratch copy and both harnesses must fail.

**Ranges.** tasks/doing/0076-re-label-after-edit.md:1-57, docs/milestones/m1.md:1-25,
docs/security.md:159-181, docs/design.md:740-750, plugin/lib/issues-lib.awk:62-74,
plugin/lib/issues-scan.awk:20-27, plugin/lib/store-issues.sh:26-49,
plugin/lib/store-issues.sh:197-234, plugin/lib/store-issues.sh:599-600,
plugin/lib/store-issues.sh:720-729, plugin/lib/github.sh:6-15,
plugin/lib/github.sh:46-68, plugin/lib/fake-gh:1-30, plugin/lib/fake-gh:91-107,
plugin/lib/fake-gh:154-178, plugin/lib/fake-gh:310-320,
plugin/lib/issue-fixtures.sh:52-75, plugin/lib/store-issues.test.sh:158-228,
plugin/lib/hostile.test.sh:400-468, plugin/lib/ship.sh:272-300, plugin/lib/backlog.sh:73,
plugin/lib/close.sh:263, plugin/lib/claim.sh:278, plugin/lib/main-write.sh:221.

---

## Outcome

On the issues storage, when a filter label (`storage.issues.label`) is set, a
single-issue read now refuses an issue whose body or title was edited after its latest
labelling by someone without write access. It is refused the way an unadmitted issue
is: status 2, and a `refused:` message that asks the maintainer to take the label off
and add it again. The message quotes no issue text and no login.

- **How it works.** `_peal_issues_edits` in `store-issues.sh` makes one GraphQL call. It
  reads `createdAt`, the author, `lastEditedAt`/`editor` and the timeline's
  `LABELED_EVENT` and `RENAMED_TITLE_EVENT` entries. `edit_admitted()` in
  `issues-lib.awk` then decides. `updated_at` is not used, because the claim label and
  Peal's own comments bump it.
- **Write access is inferred, with no permission call.** GitHub lets only writers edit
  someone else's issue, so an editor who is not the author counts as a writer. The
  author counts as one when their association is OWNER, MEMBER or COLLABORATOR.
- **Fails closed.** When no `labeled` event is found, the issue's `createdAt` stands in
  for the labelling time. A failing GraphQL call refuses the issue with `could not read
  issue N's edits`. With no filter label configured, the check never runs and makes no
  extra call.
- **Claim and revise are now checked too.** The plan assumed every single-issue path
  already went through `_peal_issues_admitted`. Claim and revise did not: they relied on
  the listing, which still admits a labelled issue. Both now call the new wrapper,
  `_peal_issues_check_admitted`, alongside read and defer. Before this change, claim and
  revise never checked admission directly.
- **Tests.** Fixtures: `fake-gh` answers the edits query, and `issue()` in
  `issue-fixtures.sh` gained `--labelled-at`, `--edited-at` and `--renamed-at`. New
  cases are in `store-issues.test.sh` (`edit_admission()`) and in a label-configured
  block of `hostile.test.sh`'s `issues_channels`. The reviewer's mutation check (forcing
  `edit_admitted` to always admit) failed both harnesses.
- **Docs.** `docs/security.md` drops the known limit this closes and describes the
  guard. `docs/design.md` names it in one sentence.
- **Left.** The listing, board, offer and ship's release notes still admit such an issue
  by its label, so an outsider's edited title can show there. The body never shows, and
  claiming refuses the issue. `docs/security.md` records this narrower limit, and the
  idea `listing-re-label-check` (m1) is filed to close it.
