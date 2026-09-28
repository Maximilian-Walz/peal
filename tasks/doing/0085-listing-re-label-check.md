---
milestone: m1
plan: required
touches: [plugin/lib/store-issues.sh, plugin/lib/issues-scan.awk, plugin/lib/issues-lib.awk, plugin/lib/ship.sh, plugin/lib/fake-gh, plugin/lib/*.test.sh, docs/security.md, docs/design.md]
size: M
model: opus
---

# 0085 — Issues storage: re-label check on the listing path too

## Intent

Since 0076, a single-issue read refuses a labelled issue that someone without write
access edited after the labelling. The listing path still admits it: the listing, the
board, the offer and ship's release notes can show a title an outsider edited after
the labelling. Claiming it is refused and its body never leaks, but the title does.
Extend 0076's re-label check (`edit_admitted` in `issues-lib.awk`) to the listing path,
for example with one batched GraphQL query over the labelled issues. Then drop the
narrower known limit from `docs/security.md`.

## Scope

Every issue the listing admits by the filter label also passes `edit_admitted()`, from
batched GraphQL calls (one per chunk of up to 100 listed issues, open and closed); ship's
release notes get the same check; `docs/security.md` drops the known limit and
`docs/design.md` no longer says "single-issue path" only. Nothing changes, and no extra
call is made, when no filter label is configured. Extras (depends, part-of) stay
unchecked: only their state is used.

## Done when

- `store-issues.test.sh` (`edit_admission`): issues 11 and 12 are absent from `list`,
  `board` and `offer`; 10, 13, 14 and 15 are still listed; 17 (no labelled event) is
  absent; 150 labelled issues make exactly 2 `POST graphql` calls, and one chunk makes 1;
  no configured label makes 0; a failing `POST graphql` makes `list` fail with status 2
  and a message naming no issue text; every 0076 single-issue check still passes on the
  shared query.
- `hostile.test.sh` (labelled repository of `issues_channels`): `list`, `board`,
  `overview`, `offer current,unassigned` and `ship notes` never print `OUTSIDER-TEXT`.
- `ship.test.sh`: a labelled closed issue renamed by its NONE author after labelling gets
  the commit's subject in `propose` and `notes`, never its title.
- `tools/lint.sh` and shellcheck pass.

## Raw

> Issues storage: the listing, board, offer and ship's release notes still admit a labelled issue whose title an outsider edited after the labelling (claiming refuses it since 0076, and no body leaks). Extend the re-label check of 0076 (edit_admitted in issues-lib.awk) to the listing path, e.g. with one batched GraphQL query over the labelled issues, and drop the narrower known limit from docs/security.md. Milestone m1. Found in 0076.

## Notes

Found in 0076. Open questions:
- What does the extra query cost per listing? It could be one batched GraphQL call, or
  paginated calls for repositories with many labelled issues.
- Should the listing hide such an issue, or mark it as waiting for a re-label?

`docs/security.md`'s "Only admitted issues reach a session" section covers this limit.

Human's answers at planning (2026-09-28):
- An issue edited by an outsider after labelling is hidden from the listing, as an
  unadmitted one is (no placeholder).
- A failing batch call fails `list` with status 2.
- Ship's release notes are in this task.
- Closed issues are checked too.
- Extras (depends, part-of) are not checked.
- No cache: up to ceil(listed/100) GraphQL calls per list is acceptable.
- The single-issue path (`_peal_issues_edits`) moves onto the shared batched query.
- The batch uses one alias per validated issue number, not the `issues(labels:)`
  connection.
- Carried over from 0076, unchanged: only the last 100 labeled/renamed events are read.

## Plan

Agreed 2026-09-28. Size M, implementer on opus, merge default.

- `store-issues.sh`: add `_peal_issues_edits_batch N...`: one GraphQL query per chunk of
  up to 100 numbers, one alias per issue (`iN: issue(number: N) { createdAt author{login}
  lastEditedAt editor{login} timelineItems(last:100, itemTypes:[LABELED_EVENT,
  RENAMED_TITLE_EVENT]) {...} }`), owner and name as variables; each number checked
  against `^[0-9]+$` before it enters the query text. Prints
  `number<TAB>labelled_at<TAB>author<TAB>edited_at<TAB>editor<TAB>renamed_at<TAB>renamer`
  per issue, the same jq as today per alias. `_peal_issues_edits N` becomes a batch of
  one.
- `_peal_issues_scan`: when `PEAL_LABEL` is set, collect the numbers of the rows in
  `listed` (open and closed) and write their edits to `$dir/edits`; a failed call makes
  `peal_store_list` fail with status 2.
- `issues-scan.awk`: read the edits file; a listed, non-extra issue passes only with an
  edits row and `edit_admitted(...)` = 1 (joined on the row's `$6`); a labelled listed
  issue with no edits row fails closed (hidden). Extras unchanged.
- `issues-lib.awk`: comments, or a small helper if the join wants one.
- `ship.sh` (`_peal_ship_issue_items`): run the batch once over the admitted, labelled,
  closed ids; a refused id or a failed call gets the commit's subject, as the unadmitted
  case does.
- `fake-gh`: replace the `*timelineItems*` branch with one answering the aliased query
  (pull the `iN: issue(number: N)` pairs from the query text, answer each from
  `issues.json` with the existing optional fields); update its header comment.
- Tests as in Done when; `issue-fixtures.sh` probably unchanged.
- `docs/security.md`: drop the limit and name the new guard; `docs/design.md` ~750:
  the check holds on the listing too.

Rejected: one `_peal_issues_edits` call per issue (N calls per list); a GraphQL
connection listing (duplicates the REST listing, needs pagination in fake-gh);
`nodes(ids:)` over `node_id` (changes `PEAL_ISSUES_ROW`).

Ranges:
- .peal/config.yml:5-58
- docs/milestones/m1.md:1-25
- plugin/lib/store-issues.sh:22-91
- plugin/lib/store-issues.sh:142-168
- plugin/lib/store-issues.sh:197-300
- plugin/lib/issues-lib.awk:1-21
- plugin/lib/issues-lib.awk:62-97
- plugin/lib/issues-scan.awk:1-51
- plugin/lib/ship.sh:272-324
- plugin/lib/fake-gh:1-34
- plugin/lib/fake-gh:95-120
- plugin/lib/fake-gh:158-197
- plugin/lib/issue-fixtures.sh:52-87
- plugin/lib/store-issues.test.sh:29-31
- plugin/lib/store-issues.test.sh:152-165
- plugin/lib/store-issues.test.sh:230-310
- plugin/lib/hostile.test.sh:430-537
- plugin/lib/ship.test.sh:415-426
- plugin/lib/session.sh:119-121
- plugin/lib/github.sh:48-68
- docs/security.md:159-195
- docs/design.md:740-752

---

## Outcome

<!-- Written at close, replacing this comment. -->
