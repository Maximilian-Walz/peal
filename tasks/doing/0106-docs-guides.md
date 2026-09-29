---
milestone: m2
plan: required
depends: [0031, 0105]
part-of: 0031
size: M
touches: [docs/guides/**, README.md, docs/getting-started.md, docs/reference/README.md, tools/docs.test.sh, CONTRIBUTING.md]
---

# 0106 — docs/guides/: one short page per workflow

## Intent

One short page per workflow, each with a real example that the docs check exercises:
working a task, the backlog commands, milestones, running under Belfry, releases. The
guides link into the reference (0105) rather than repeat it. The README's Peal-and-Belfry
link is repointed to the Belfry guide.

## Scope

- Create `docs/guides/README.md` (a short index mirroring `docs/reference/README.md`) and
  five guides: `working-a-task.md`, `backlog.md`, `milestones.md`, `belfry.md`,
  `releases.md`. Each is about one screen (40-80 lines) of narrative, and links into the
  reference instead of copying its flag lists, output shapes or settings tables.
- `tools/docs.test.sh`: every `run` block's scratch repository gets an empty bare
  `origin`, all in one scratch directory so claim worktrees land inside it. Add a check
  that the guides are among the checked documents and a mutant on a guide's `run` block.
  Update the header comment, and `CONTRIBUTING.md:51-54` if the `run` description
  changes. Fix the temp-directory leak (below) within `tools/docs.test.sh`.
- Link the guides from the README (a line in Start, and a sentence in "Peal and Belfry"
  linking `docs/guides/belfry.md`, keeping the Belfry repository link), from
  `docs/getting-started.md` ("Where to look things up") and from
  `docs/reference/README.md:4`.

## Done when

- `bash tools/docs.test.sh` passes. Each guide has at least one marked block (`run`,
  `config`, `shape` or `frontmatter`) that it exercises. A check proves the
  `docs/guides/*.md` pages are among the checked documents.
- The negative case "a quoted output that changed is reported" still passes, and a new
  mutant on a guide's `run` block proves the remote-backed path fails too.
- getting-started's `run` block still passes with the remote present.
- The README's Belfry section links `docs/guides/belfry.md`, and the link check resolves
  it.
- No guide holds a settings table, flag list or output-shape list that the reference
  holds (`grep -n '^| `' docs/guides/*.md` is empty; the reviewer checks by eye).
- `tools/docs.test.sh` no longer leaks temporary directories: after a run, none of the
  scratch directories it created remain.
- `tools/test-all.sh tools/docs.test.sh` and `tools/lint.sh` pass.

## Raw

> - `docs/guides/`: one page per workflow (working a task, the backlog commands,
>   milestones, running under Belfry, releases), each short, with a real example.

Split from 0031

## Notes

- The releases guide should describe the CHANGELOG once 0107 has landed; if it has not,
  describe the release as it is and leave the CHANGELOG to 0107.
- Size: M.
- The human's answers to the plan (2026-09-29):
  - Harness: every `run` block gets an empty bare `origin` (not a new marker, and not
    each guide setting up its own remote).
  - A "real example" for a `/peal:` command is a `shape`-checked session excerpt plus a
    `run` block of the CLI underneath.
  - README: keep the Belfry repository link and add a sentence linking the Belfry guide.
  - A short `docs/guides/README.md` index.
  - The planner's remaining defaults are accepted:
    - The file names above.
    - The backlog guide covers idea, split, defer, retire and revise, plus `list` and
      `offer` for reading the backlog. `board` goes to the Belfry guide. Split and
      defer live in the backlog guide, with one-line pointers from working-a-task.
    - Releases describes `release.changelog` as a setting any project can turn on,
      without claiming that Peal keeps a CHANGELOG yet (0108 is open and is left
      untouched). `publish` and `wait` are named in prose only. The `ship bump`
      example does not set up guardrails.
    - Belfry's `auto_merge` policy gets one sentence and a link, no YAML. The guide
      quotes the `.belfry.yml` that `peal init --stage belfry` writes (with `--origin`).
      This repository's own `.belfry.yml` is not fixed here.
    - Neither `.belfry.yml docs:` nor `.peal/config.yml context` gains the guides.
    - "Short" means 40-80 lines.
    - working-a-task picks up where getting-started ends (plan agreement, review
      findings, a failed check, resuming, `merge: auto`) and links back to it.
    - The guides follow the Words list in `docs/reference/README.md`.
  - The planner found that `tools/docs.test.sh` leaks temporary directories, because
    `docs_problems` and `scratch_repo` run inside `$(...)` and so the `scratch+=` in
    `plugin/lib/test-lib.sh:26` happens in a subshell. The human chose to fix it in
    this task rather than file it.

## Plan

Facts: the docs check is `tools/docs.test.sh`, run by `tools/test-all.sh`. It checks every
`docs/**/*.md` except milestones/ and decisions/, so the guides are covered automatically.
Markers: `<!-- docs-check: run|config|frontmatter|shape|install -->`. A `run` block runs
each `$ ` line in a fresh scratch repository. 0107 (`release.changelog`) has landed; 0108
(Peal keeping its own CHANGELOG) has not.

Harness (`tools/docs.test.sh`):
- In `run`'s branch of `docs_problems`, make the scratch repository `$d/repo` with an
  empty bare `$d/origin.git` as `origin`, both inside one scratch directory. A guide then
  shows `$ git push -q -u origin main` after committing its setup.
- Update the header comment (`:15-17`). Add a guides-count check in the style of `:338`.
  Add a mutant on a guide's `run` block. Touch `CONTRIBUTING.md:51-54` only if the `run`
  description changes.
- Fix the leak: scratch directories are created inside `$(...)` subshells (`:164`,
  `:268`, `:275`, `:333`), so the EXIT trap never sees them. Create them under a base
  directory made in the main shell, or otherwise register them there, so the trap
  removes everything. Keep the fix inside `tools/docs.test.sh`.

Guides, each with an exercised example, whose exact output comes from running it:
- `working-a-task.md`: a `shape` session excerpt (filed/claimed/closed lines, like the
  README's), then plan agreement, the implementer, review, the Outcome, the human's
  merge and `merge: auto`. Then a `run` block: `peal init --stage tasks`, commit, push,
  file a task, `peal claim 0001`, `peal work` in the worktree. Links:
  `reference/commands.md#pealwork`, `#pealclose`, `cli.md#peal-close`,
  `tasks.md#claim-states`.
- `backlog.md`: idea, split, defer, retire, revise, when each fits and what the human
  confirms. `run`: file a task, `peal list`, `peal offer current,unassigned`,
  `peal revise … --dry-run`, `peal retire … --reason …`, `peal list`.
- `milestones.md`: milestone files and their states, the review task,
  `/peal:milestone-review`, parking. `run`: `peal init --stage milestones`,
  `peal milestones`, `peal milestone-state m1 done`, `peal milestones`; a `frontmatter`
  block if it helps.
- `belfry.md`: what Belfry is, a `run` block of `peal init --stage belfry` and
  `cat .belfry.yml` quoting the contract lines (`plugin/lib/init.sh:419-447`), the
  review and release actions, `/peal:idea` under Belfry, and "finished means a pull
  request open and green". Links `design.md#peal-and-belfry` instead of copying it.
- `releases.md`: `/peal:release`, `peal ship propose/notes/bump/tag/publish/wait`, the
  CHANGELOG through `release.changelog`, and the trap that `peal release ID` releases a
  claim, not a version. A `config` block (`release.changelog: CHANGELOG.md` and a
  version file). `run`: a `feat:` commit, `peal ship propose` (`LAST none`,
  `PROPOSE v0.1.0 first`), `peal ship bump 0.1.0`, show the CHANGELOG,
  `peal ship tag 0.1.0`.
- `README.md` (index), plus the links in the README, getting-started and
  `docs/reference/README.md:4`.

Verification: see Done when. `tools/test-all.sh tools/docs.test.sh`, `tools/lint.sh`.

Ranges relied on:
- tasks/done/0031-readme-docs-newcomers.md:54-98
- tasks/done/0105-docs-reference-design-prune.md:67-86, 196-199
- tasks/done/0107-changelog-kept-by-release.md:129-164
- tasks/backlog/0108-peal-keeps-its-changelog.md:1-45
- tools/docs.test.sh:1-29, 54-60, 116-199, 226-288, 332-377
- plugin/lib/test-lib.sh:15-28
- plugin/lib/init.sh:402-466
- plugin/lib/config-defaults.yml:1-51
- README.md:1-70
- docs/getting-started.md:1-117
- docs/reference/README.md:1-47
- docs/reference/commands.md:1-129
- docs/reference/cli.md:1-60, 126-131, 206-374, 376-433, 495-564
- docs/design.md:38-102, 143-154, 308-332, 531-555
- docs/milestones/m2.md:15-24
- CONTRIBUTING.md:47-59
- .belfry.yml:1-46
- tools/ci-changes.sh:23-38

---

## Outcome

<!-- Written at close, replacing this comment. -->
