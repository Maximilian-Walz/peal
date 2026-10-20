---
plan: required
touches: [tools/docs.test.sh]
milestone: m3
---

# 0128 — The docs harness runs faster

## Intent

`tools/docs.test.sh` takes about six minutes after task 0119, most of it sys time. Each
negative case (`mutant`) copies the repository and reruns the check of every document,
and 0119 added eleven of them. Make the harness fast again. Either each mutant checks only
the document it changes, or the harness gets its own CI shard.

## Scope

## Done when

## Raw

> The docs harness is slow: tools/docs.test.sh takes about 6 minutes after 0119 (mostly
> sys time), because each negative case (`mutant`) copies the repository and reruns the
> check of every document, and 0119 added eleven. A mutant could check only the document
> it changes, or the harness could get its own CI shard. Found in 0119.

## Notes

- Open: which of the two, or both. A mutant that checks one document still needs the
  whole-repo checks (every marker kind is used, the command headings) where its mutation
  bears on them.
- Open: the time before 0119 was not measured; measure both for comparison.

---

## Outcome

<!-- Written at close, replacing this comment. -->
