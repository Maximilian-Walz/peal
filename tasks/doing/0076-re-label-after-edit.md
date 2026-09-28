---
milestone: m1
plan: required
depends: []
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

## Done when

- An issue labelled (or opened by someone with write access), then edited afterwards by
  someone without write access, is refused the same way an unadmitted issue is, unless
  the edit itself is by someone with write access.
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

---

## Outcome

<!-- Written at close, replacing this comment. -->
