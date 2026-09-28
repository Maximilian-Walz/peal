---
plan: required
touches: [plugin/lib/next.sh, plugin/lib/init.sh]
---

# 0104 — Share the CI file list between init's survey and next

## Intent

`peal init --survey` and `peal next` both look for a project's CI files. Each keeps its
own copy of the list: `_peal_next_ci_files` in `plugin/lib/next.sh` repeats the list in
`plugin/lib/init.sh`'s survey word for word. The two copies will drift apart. Move the
list into one helper that both call.

## Scope

## Done when

## Raw

> Share the CI file list between peal init --survey and peal next: `_peal_next_ci_files` in plugin/lib/next.sh repeats the list in plugin/lib/init.sh's survey word for word, so the two will drift. Move it into one helper both call. Found by 0097's review.

## Notes

- Open: where the shared helper lives, in `init.sh`, `next.sh` or a common lib that
  both already source.

---

## Outcome

<!-- Written at close, replacing this comment. -->
