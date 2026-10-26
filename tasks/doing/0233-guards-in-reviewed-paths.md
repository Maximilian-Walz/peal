---
milestone: m6
plan: required
size: S
depends: []
priority: high
touches: [.belfry.yml, docs/security.md, tools/lint.sh]
---

# 0233 — Every guard docs/security.md names is in .belfry.yml's reviewed paths, and CI keeps the two the same

## Intent

Under Belfry, Peal's security review (`security-pr`) runs only on pull requests that touch a path in `.belfry.yml`'s `never_auto_merge` or `review_before_merge` lists. Those lists are meant to be the guards `docs/security.md` names, but three guard files are in neither:

- `plugin/lib/task-text.sh` (`peal_text_human_section`) is named as a guard of "Text from others is data";
- `plugin/lib/close.sh` and `plugin/lib/config.sh` carry "`checks.close` comes from main" (`peal_config_load_ref`).

A pull request that changes one of them gets no security review, and under the "agreed tasks" tier (`merge: auto`) it merges by itself once green. Nothing notices the drift: unlike Belfry, which keeps its lists and its security document the same by rule, Peal has no check. Once this is done, the three files are reviewed before they merge, and CI fails when `docs/security.md` names a guard file that neither list covers.

## Scope

- `.belfry.yml`: `plugin/lib/task-text.sh`, `plugin/lib/close.sh` and `plugin/lib/config.sh` (with their `.test.sh` harnesses) go into `review_before_merge.paths`, or into `never_auto_merge` where the plan finds them release-chain code.
- A check in `tools/lint.sh` (or a script of its own run by it): every `plugin/…`, `tools/…` or `.peal/…` path that `docs/security.md` names on a `- Guard:` line is matched by a pattern in `never_auto_merge` or `review_before_merge.paths`; it names each one missing. A harness case with a guard file missing from both lists.
- `docs/security.md`: a sentence saying the two lists follow its guards, and that CI checks it.

## Done when

- The three files are in a reviewed list, and `security-pr` runs on a pull request touching any of them.
- `tools/lint.sh` fails, naming the file, when a guard named in `docs/security.md` is in neither list; a harness case asserts it.
- `tools/test-all.sh` passes.

## Raw

> Manche peal tasks bekommen gar kein security-review (ist das Absicht? Dann ist das okay).

## Notes

Found while answering that question: the review runs only for the listed paths, which is the intent, but the lists have fallen behind `docs/security.md`. Security: the review-before-merge guard itself (docs/security.md); the change only widens what is reviewed.
