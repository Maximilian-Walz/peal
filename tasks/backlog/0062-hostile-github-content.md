---
milestone: m1
plan: required
depends: [0039]
part-of: 0039
---

# 0062 — Hostile GitHub content: the write-access rule on every issues read

## Intent

On the issues storage, text from strangers (issue titles, bodies, labels, comments, pull
requests) must reach a session only when the write-access rule or the filter label admits
it. Extend the hostile-input harness to the issues storage's channels and make every read
path apply the rule.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
