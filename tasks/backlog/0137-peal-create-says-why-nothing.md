---
plan: required
touches: [plugin/lib/store-files.sh, plugin/lib/hostile.test.sh]
---

# 0137 — `peal create` says why nothing was filed; the macOS hostile-stdin check is flaky

## Intent

On macOS CI, the `plugin/lib/hostile.test.sh` check "create --owner --title: hostile stdin filed, to compare it byte for byte" failed once on a pull request whose code had nothing to do with it. `peal create --owner ai --title "Hostile hex byte check"` printed only the seeded backlog's warnings and then "nothing was filed", with no line saying why. A rerun passed; main is green.

Two things follow. First, `peal create` must never fail silently: wherever `peal_push_main` returns non-zero on the create path (`plugin/lib/store-files.sh`, where `nothing was filed` is printed), the user gets a one-line reason on stderr. Second, find what actually made the push fail on macOS and make the hostile check robust against it, so it passes reliably there and, if it ever fails again, its failure message shows that reason.

## Scope

## Done when

## Raw

> `peal create` says why nothing was filed; the macOS hostile-stdin check is flaky
>
> ## Intent
>
> On macOS CI (PR #219, task 0127, unrelated code), the `plugin/lib/hostile.test.sh` check "create --owner --title: hostile stdin filed, to compare it byte for byte" (around line 407) failed once. `peal create --owner ai --title "Hostile hex byte check"` printed only the seeded backlog's warnings and "nothing was filed", with no error naming why. A rerun passed, and main is green.
>
> Find why `peal_push_main` failed without a message (`plugin/lib/store-files.sh` around 380-398, where `nothing was filed` is printed). Make every failure path there say why, and make the test robust against whatever made it flaky.
>
> ## Done when
>
> - Every non-zero return of `peal_push_main` in the create path carries a one-line reason on stderr.
> - The hostile check prints that reason when it fails, and passes repeatedly on macOS.

## Notes

- Open question: the cause is unknown and the failure happened once. The CI log of PR #219's failed macOS run is the first evidence to read, if it is still kept. Possible causes to rule out: a race with another push to the test's origin, a timing-dependent retry or lock in `peal_push_main`, BSD-vs-GNU tool differences, a git hook in the test's work tree.
- Open question: "passes repeatedly on macOS" needs a way to show it, e.g. running the check in a loop on a macOS runner. Is one CI run enough evidence, or should the plan add a stress loop?
- The check's output captures `2>&1` and takes only the last line as the id; once a reason is printed it should appear in the `not filed:` text with no other change, but check that the warnings of the seeded backlog don't hide it.
- `docs/reference/cli.md` documents `peal create`; update it if the error output changes in a way it describes.

---

## Outcome

<!-- Written at close, replacing this comment. -->
