---
milestone: m6
plan: required
size: S
depends: []
priority: high
touches: [.belfry.yml, docs/security.md, tools/lint.sh, tools/lint.test.sh, tools/guards.sh, tools/guards.test.sh, CONTRIBUTING.md]
---

# 0233 — Every guard docs/security.md names is in .belfry.yml's reviewed paths, and CI keeps the two the same

## Intent

Under Belfry, Peal's security review (`security-pr`) runs only on pull requests that touch a path in `.belfry.yml`'s `never_auto_merge` or `review_before_merge` lists. Those lists are meant to be the guards `docs/security.md` names, but three guard files are in neither:

- `plugin/lib/task-text.sh` (`peal_text_human_section`) is named as a guard of "Text from others is data";
- `plugin/lib/close.sh` and `plugin/lib/config.sh` carry "`checks.close` comes from main" (`peal_config_load_ref`).

A pull request that changes one of them gets no security review, and under the "agreed tasks" tier (`merge: auto`) it merges by itself once green. Nothing notices the drift: unlike Belfry, which keeps its lists and its security document the same by rule, Peal has no check. Once this is done, the three files are reviewed before they merge, and CI fails when `docs/security.md` names a guard file that neither list covers.

## Scope

- `.belfry.yml`: `plugin/lib/task-text.sh`, `plugin/lib/close.sh`, `plugin/lib/config.sh`, `plugin/lib/tasks.sh` and `plugin/lib/task-check.awk` (with their `.test.sh` harnesses) go into `review_before_merge.paths`.
- A check in `tools/lint.sh` (or a script of its own run by it): every `plugin/…`, `tools/…` or `.peal/…` path that `docs/security.md` names on a `- Guard:` line is matched by a pattern in `never_auto_merge` or `review_before_merge.paths`; it names each one missing. A harness case with a guard file missing from both lists.
- `docs/security.md`: a sentence saying the two lists follow its guards, and that CI checks it.

## Done when

- The five files are in a reviewed list, and `security-pr` runs on a pull request touching any of them.
- `tools/lint.sh` fails, naming the file, when a guard named in `docs/security.md` is in neither list; a harness case asserts it.
- `tools/test-all.sh` passes.

## Raw

> Manche peal tasks bekommen gar kein security-review (ist das Absicht? Dann ist das okay).

## Notes

Found while answering that question: the review runs only for the listed paths, which is the intent, but the lists have fallen behind `docs/security.md`. Security: the review-before-merge guard itself (docs/security.md); the change only widens what is reviewed.

2026-10-26, plan agreed with the human:
- Extra files: yes, `plugin/lib/tasks.sh` (+ `tasks.test.sh`) and `plugin/lib/task-check.awk` go into `review_before_merge` too (both are on `- Guard:` lines).
- config.sh / Never list / Guard file: the human said "whatever is cleaner"; the session chose: the `checks.close` limit bullet gains a `- Guard:` line naming `plugin/lib/config.sh` (`peal_config_load_ref`) and `plugin/lib/close.sh`, so the check enforces them; `close.sh` and `config.sh` go into `review_before_merge`, not `never`; `tools/guards.sh` and its harness go into `&never` next to `tools/pins.sh` and are named on the Auto-merge tiers Guard line.
- A separate `tools/guards.sh`, run by `tools/lint.sh`.
- Only `- Guard:` bullets (with continuation lines) are read; no inline "Guard:" mentions, no `- Harness:` lines.
- Bash `case` glob matching (`*` crosses `/`) is accepted, noted in a comment.
- 0162 is left as is; the Outcome says its Guard-line part is done.
- CONTRIBUTING.md gets one clause for the guards step; `tools/lint.test.sh` may change (fixtures for its launcher cases, plus the end-to-end case).

## Plan

**Lists.** `.belfry.yml` `review_before_merge.paths` gains `plugin/lib/task-text.sh`, `plugin/lib/close.sh`, `plugin/lib/close.test.sh`, `plugin/lib/config.sh`, `plugin/lib/config.test.sh`, `plugin/lib/tasks.sh`, `plugin/lib/tasks.test.sh`, `plugin/lib/task-check.awk` (task-text.sh has no harness of its own). `tools/guards.sh` and `tools/guards.test.sh` go into the `&never` list next to `tools/pins.sh`.

**Check.** New `tools/guards.sh [SECURITY_MD BELFRY_YML]` (defaults: the repository's own two files), built like `tools/pins.sh`. awk reads each column-0 `- Guard:` bullet plus its two-space continuation lines, and keeps the backticked tokens starting with `plugin/`, `tools/` or `.peal/`. awk reads the `&never` block list (the security-pr paths), `policy.never_auto_merge` as the `*never` alias or a block list of its own, and `policy.review_before_merge.paths`; no YAML library. Each guard path is matched against each pattern with `case "$path" in $pattern)` (a comment notes `*` crosses `/` unlike Belfry). Output per miss: `guards: <path> (docs/security.md:<line>) is in neither never_auto_merge nor review_before_merge.paths`. Exit 0 clean, 1 on a finding, 2 when a list or the guard set is empty. `tools/lint.sh` gets an `echo 'lint: guards'` step running `tools/guards.sh || status=1` between the pins and launcher steps, and its header comment names it.

**docs/security.md.** In Auto-merge tiers: one sentence, the two lists follow this file's `- Guard:` lines and `tools/lint.sh` (`tools/guards.sh`) fails CI on a guard path in neither; the tiers prose (:499-501) names the task checks, close and config libraries; `tools/guards.sh` on the Auto-merge tiers `- Guard:` bullet (:528). The `checks.close` limit bullet (:64-73) gains a `- Guard:` line naming `plugin/lib/config.sh` (`peal_config_load_ref`) and `plugin/lib/close.sh`.

**CONTRIBUTING.md:51-54**: one clause naming the guards step.

**Verification.** `tools/guards.test.sh` on scratch fixtures: the real repository's files exit 0; a `- Guard:` naming `plugin/lib/missing.sh` exits 1 naming it; a path only on a continuation line is read; a guard covered only via the `*never` alias passes; `plugin/hooks/**` covers `plugin/hooks/x`; a `.github/...` path on a Guard line is ignored; no `review_before_merge.paths` or no Guard lines exits 2. `tools/lint.test.sh`: the launcher scratch repository gets agreeing fixtures (existing cases still exit 0), plus a case where a fixture `docs/security.md` names a guard missing from a fixture `.belfry.yml`: lint exits non-zero and names the file. `tools/test-all.sh` and `tools/lint.sh` pass.

Ranges: .belfry.yml:58-150; docs/security.md:53-73, 104-109, 184-191, 265-268, 361-365, 491-531; tools/lint.sh:1-44; tools/lint.test.sh:1-75; tools/pins.sh:1-59; tools/test-all.sh:25-30; .github/workflows/ci.yml:239; CONTRIBUTING.md:48-56; tasks/backlog/0162-harness-tiers-cover-security-paths.md:1-31; plugin/bin/peal:26-59; plugin/lib/tasks.sh:83.
