---
milestone: m2
plan: required
depends: [0030]
part-of: 0030
size: M
touches: [plugin/lib/next.sh, plugin/lib/next.test.sh, plugin/lib/session.test.sh, plugin/commands/next.md, plugin/commands/commands.test.sh, plugin/bin/peal, docs/design.md, README.md]
---

# 0097 — /peal:next knows the features within the stages

## Intent

`/peal:next` (the origin) suggests the setup stages and the milestone review task. The
features around them, the decisions module, `/peal:drift`, `.peal/review.md`,
releases and the reviewer's settings, should find the user the same way: one
suggestion with this repository's evidence, never a change unasked.

## Scope

- New `peal next` catalogue items after `review-task`, in this order: `decisions`,
  `drift`, `releases`, `reviewer`, `review-steps`. Each has a cheap check (local files
  and git only, no `gh`, no fetch), evidence made of counts, ids and repository paths,
  and a decline.
- `/peal:next` explains each item, and its "Try it" shows the exact change, then
  commits it as `chore(peal): <item>` on `peal/next-<item>` from main. For drift and
  releases it runs `/peal:drift` or `/peal:release` once instead.
- `docs/design.md` (the `/peal:next` paragraph) and `README.md` name the new items.
- Out: no new `peal init` stage, no `peal next --take` CLI, `templates/decisions.yml`
  only named for the human to copy, `checks.*` never written.

## Done when

- `next.test.sh` covers each new item firing and not firing, its decline, the order
  when all qualify, and `NONE` once each is set up or declined.
- `session.test.sh`: on a project with all four stages, the SessionStart hint names a
  feature item, with no more `gh` calls than before.
- By hand: on a scratch project with all four stages, `/peal:next` suggests one of these
  features with fitting evidence, and nothing once each is set up or declined; this is
  recorded in the Outcome.
- `tools/lint.sh` passes.

## Raw

> It knows the stages of `peal init` and the features within them (the decisions
> module, drift and milestone review, releases, the reviewer's settings), each with a
> short check of whether it would help here.

Split from 0030

## Notes

What the origin's planning agreed with the human for this piece:

- Catalogue items `decisions`, `drift`, `releases`, `reviewer` in `plugin/lib/next.sh`,
  checked in fixed order after the stages, with the agreed draft thresholds:
  - `decisions`: off, and an ADR-like directory (`docs/adr`, `docs/decisions`,
    `doc/adr`) or at least 20 tasks done.
  - `drift`: no `.peal/drift.md`, `context` set or a `docs/` of Markdown files, and at
    least 10 tasks done.
  - `releases`: no release tag under `release.tag-prefix` and at least 5 `feat`/`fix`
    tasks done; a version file (`package.json`, `Cargo.toml`, `pyproject.toml`,
    `.claude-plugin/plugin.json`) suggests `release.version-files`.
  - `reviewer`: no `.peal/reviewer.md` and `context` empty while design-like docs exist,
    or CI files while `checks.close` and `checks.commit` are empty.
- `.peal/review.md` joins the `review-task` item or becomes an item of its own: the
  piece's plan decides.
- Accepting does a small step, shown first and committed as `chore(peal)` (`decisions:
  <dir>` in the config, a stub `.peal/reviewer.md` or `.peal/drift.md`,
  `release.version-files`), or runs the command once (`/peal:drift`, `/peal:release`).
  No new `peal init` stages. `templates/decisions.yml` is named for the human to copy,
  not written.
- The checks feed the SessionStart hint too, so they stay cheap: local files and git
  only, no `gh`.
- Likely Done when: `next.test.sh` covers each new item firing and not firing, and its
  decline; on a scratch project with all four stages, `/peal:next` suggests one of these
  features with fitting evidence, and nothing once each is set up or declined.
- Size estimate: M.

Agreed with the human at planning (2026-09-28):

- `.peal/review.md` is an item of its own, `review-steps`. It fires when milestones are
  recorded, at least one milestone is `done`, and `.peal/review.md` is missing.
  Accepting writes a stub.
- Order: after `review-task`, in the order decisions, drift, releases, reviewer,
  review-steps.
- Version files: suggest only `package.json` and `.claude-plugin/plugin.json` at the
  repository root. The TOML files are ignored, because `release.version-files` takes
  only top-level fields.
- The `/peal:next` session makes the accept step itself (edit, show, commit). There is
  no new CLI; only the engine is under test.
- `decisions`: before writing `decisions: <dir>`, "Try it" runs `peal decision check`
  against the directory. If that fails, it shows the failures, does not write, and
  proposes a fresh `docs/decisions`.
- `releases`: counts all done tasks from the records, the same count as `belfry`.
  "No tag" means no local tag under `release.tag-prefix` that is merged into local main;
  no fetch. It stays silent once any release tag exists.
- `drift`: counts only Markdown under `docs/` outside the configured milestones, tasks
  and decisions directories. It stays silent once `.peal/drift.md` exists.
- `reviewer`: fires when there is no `.peal/reviewer.md` AND either (`context` is empty
  while design docs exist) or (CI files exist while `checks.close` and `checks.commit`
  are both empty). Design docs means `design*` or `architecture*` `.md` files at the
  root or in `docs/`, case-insensitive, or a `docs/architecture/` directory. Accepting
  writes a stub `.peal/reviewer.md` and, in the same shown change,
  `context: [<design docs found>]`. It never writes `checks.*`.
- The accept commit is `chore(peal): <item>` on `peal/next-<item>` from main.
- Peal's own repository will start hinting (decisions or drift). That is fine;
  no declines are recorded for it.

Agreed with the human at close, after the review (2026-09-28):

- Accepting `drift` writes a stub `.peal/drift.md` that lists the documents `/peal:drift`
  would suggest. The stub is shown first and committed as `chore(peal): drift`; then
  `/peal:drift` runs once.
- When the ADR directory found fails `peal decision check`, the fallback proposes
  `docs/decisions` only if that directory is missing or empty. Otherwise the flow says
  that no clean directory exists, writes nothing, and lets the human name one.

## Plan

**Engine (`plugin/lib/next.sh`).**
- A gatherer, `_peal_next_features`, prints `key value` lines of local facts:
  - the ADR directory;
  - whether `.peal/drift.md`, `.peal/reviewer.md` and `.peal/review.md` exist;
  - the count of docs Markdown outside milestones, tasks and decisions;
  - the design docs;
  - the CI files, from the same list as `peal init --survey`;
  - the first root version file;
  - whether a local release tag under `release.tag-prefix` is merged into local main.
- The gatherer runs once in `peal_next` and once in `peal_next_hint`. It is passed to
  `peal_next_core` as a seventh fact argument, FEATURES; the ONLY/--all arguments shift
  by one. The core stays pure.
- The new items join `PEAL_NEXT_ITEMS`, `_qualifies`, `_evidence` and `_peal_next_try`.
  The try values are single tokens: `decisions: <dir>`, `/peal:drift`, `/peal:release`,
  `.peal/reviewer.md`, `.peal/review.md`.
- The decline and `declined:` handling work unchanged.
- The header comment's catalogue is updated.

**Command (`plugin/commands/next.md`).**
- Per-item explanations, the argument list, and "Tell me more" texts.
- A "Try it" per feature: show the exact change, then commit as the decline does
  (branch `peal/next-<item>` from main, `chore(peal): <item>`). The branch-and-commit
  wording is shared with the decline section.
- Drift and releases run their command once and let its report stand.
- The decisions check runs first.
- `templates/decisions.yml` is named, not written.

**Docs.** `docs/design.md`, the `/peal:next` paragraph: items and thresholds.
`README.md` line 42: stages and features.

**Verification.**
- `next.test.sh`, `PEAL_TODAY` pinned, on fixtures with all four stages and m1's review
  task filed:
  - `decisions`: fires with `docs/adr` at 0 done; fires at 20 done, silent at 19; silent
    with the module on.
  - `drift`: fires at 10 done with `context` set or with other docs Markdown; silent at
    9 done; silent with only milestones Markdown; silent once `drift.md` exists.
  - `releases`: fires at 5 done with no tag, silent at 4; evidence names `package.json`;
    silent with a `v0.1.0` tag on main; respects a custom `tag-prefix`.
  - `reviewer`: fires on `docs/design.md` with `context: []`; fires on CI files with
    empty checks; silent when checks and context are set; silent once `reviewer.md`
    exists.
  - `review-steps`: fires with a done milestone and no `review.md`; silent otherwise.
  - Declines for each item; order when all qualify; `NONE`.
  - The existing expectations are updated where the new items now appear as ALSO lines.
- `session.test.sh`: on an all-stages fixture the hint names a feature item, and the
  gh-call count is unchanged. The state-C "no hint" fixtures are adjusted.
- `tools/lint.sh`.
- By hand, on a scratch project; the result goes into the Outcome.

**Ranges.**
- plugin/lib/next.sh:1-265
- plugin/lib/next.test.sh:1-191
- plugin/commands/next.md:1-85
- plugin/commands/drift.md:20-26
- plugin/commands/commands.test.sh:38-40
- plugin/lib/session.sh:100-145
- plugin/lib/ship.sh:1-49, 64-88, 152-172
- plugin/lib/init.sh:87-140, 566-584
- plugin/lib/config-block.awk:1-49
- plugin/lib/decisions.sh:18-31
- plugin/lib/store.sh:8-17
- plugin/bin/peal:62-63, 85-90, 431-435, 469
- docs/design.md:142, 151, 211, 220, 496-506, 520-574, 798-875, 877-941, 981-1038
- README.md:42
- tasks/done/0030-peal-next.md:25-33, 48-87, 88-162, 205-209

---

## Outcome

`peal next` now knows the features around the setup stages. After `review-task`, in this
order, it checks five new items:

- **`decisions`**: the decisions module is off, and there is an ADR-like directory
  (`docs/adr`, `docs/decisions`, `doc/adr`) or at least 20 tasks done.
- **`drift`**: `.peal/drift.md` is missing, `context` is set or there is docs Markdown
  outside the milestones, tasks and decisions directories, and at least 10 tasks done.
- **`releases`**: no local release tag under `release.tag-prefix` is merged into main,
  and at least 5 tasks are done. Only the root `package.json` or
  `.claude-plugin/plugin.json` is named as a version file.
- **`reviewer`**: `.peal/reviewer.md` is missing, and either `context` is empty while
  design docs exist, or CI files exist while `checks.close` and `checks.commit` are both
  empty.
- **`review-steps`**: a milestone is done and `.peal/review.md` is missing.

How the checks work:

- One gatherer, `_peal_next_features`, collects the local facts once per run, using files
  and git only, no `gh` and no fetch. It feeds `peal_next_core` as a seventh fact
  argument, so the SessionStart hint stays cheap.
- Declines work unchanged for the new items.

`plugin/commands/next.md` has a "Try it" for each item. It shows the change, then commits
it as `chore(peal): <item>` on `peal/next-<item>` from main:

- `decisions` runs `peal decision check` first. When that check fails, it proposes
  `docs/decisions` only if that directory is missing or empty; otherwise it writes
  nothing and asks the human for a directory.
- `drift` writes a stub `.peal/drift.md`, then runs `/peal:drift` once.
- `reviewer` writes a stub `.peal/reviewer.md` plus `context: [<design docs>]`. It never
  writes `checks.*`.
- `review-steps` writes a stub `.peal/review.md`.
- `releases` runs `/peal:release` once.

`docs/design.md` and `README.md` describe the new items.

Decisions (all in the task's Notes):

- `review-steps` is an item of its own. Folded into `review-task`, it could never fire
  once the review task is filed.
- The TOML version files are not suggested, because `release.version-files` takes only
  top-level fields.
- The session makes the accept step itself; there is no `peal next --take` command. A
  safe nested config merge would have doubled the task.
- The review found two dead ends: drift's "Try it" ran `/peal:drift`, which stops without
  `drift.md`, and the decisions fallback could re-propose the directory that had just
  failed. The human chose both fixes at close.

Verification:

- `next.test.sh` has 159 passing cases: each item firing and silent, the declines, the
  order, and `NONE`.
- `session.test.sh`: the hint names a feature item on an all-stages project, with no more
  `gh` calls. The state-C fixtures now decline the feature items, so they stay `NONE`.
- The full suite passes (31 harnesses) and `tools/lint.sh` passes.
- By hand, on a scratch project with this branch's plugin:
  - The fixture had all four stages, 12 tasks done, `docs/design.md`, an empty `docs/adr`,
    a `package.json`, `context: []` and no tag.
  - `peal next --all` suggested `review-task`, with `decisions` ("docs/adr found"),
    `drift` ("12 done, 1 docs") and `releases` ("12 done, package.json") as ALSO lines.
  - Each item was then taken through its next.md step and committed: `decisions` (the
    check passed on the empty directory), the `drift` stub, the `reviewer` stub with its
    context, and the `review-steps` stub. `review-task` and `releases` were declined.
  - `peal next` then printed `NONE`.
  - `/peal:drift` and `/peal:release` themselves were not run there; they are agent
    commands. The Try it commits were made by hand, following the text.

For the next session:

- Peal's own repository now hints `decisions` or `drift` at session start. The human
  agreed to this.
- The CI file list is duplicated between `next.sh` and `init.sh`'s survey. This is filed
  as an idea.
- An interrupted build session left an autosave commit with a stray empty `hostile.out`,
  removed on the branch. No test writes it, and its cause is unknown.
- `plugin/lib/hostile.test.sh` alone takes about 7 minutes here.

