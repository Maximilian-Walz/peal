---
milestone: m3
plan: required
size: M
touches: [tools/docs.test.sh, docs/getting-started.md, docs/migrating.md, docs/reference/tasks.md, docs/design.md, CONTRIBUTING.md]
---

# 0119 — Every example in the docs is checked by the docs harness

## Intent

Carried forward from milestone m2's review (0046), acceptance criterion 4's second half:
"every example in the docs is exercised by a harness". `tools/docs.test.sh` checks only
fenced blocks that carry a `<!-- docs-check: ... -->` marker, and four blocks carry none:
the settings.json pin in `docs/getting-started.md`, both `peal migrate` commands in
`docs/migrating.md`, and the section skeleton in `docs/reference/tasks.md`. Mark or check
them, and make the harness fail on an unmarked block so a new example cannot slip past.

## Scope

- `tools/docs.test.sh`: fail on a fenced block with no `docs-check` marker; new marker
  kinds `settings`, `migrate`, `sections`, `belfry`, `decision`, each with negative cases.
- Markers (and only markers, plus fixing an example a check finds already wrong) in
  `docs/getting-started.md`, `docs/migrating.md`, `docs/reference/tasks.md` and
  `docs/design.md` (its three unmarked blocks: `.belfry.yml`, decision entry,
  settings.json lines).
- The marker list in `CONTRIBUTING.md`, rewritten complete.
- No exempt marker. Nothing under `plugin/` changes.

## Done when

- `bash tools/docs.test.sh` passes on the branch.
- An unmarked fenced block in a checked document is reported (negative case: the
  install block's marker removed).
- Both settings.json blocks are checked (negative case: repo `other/peal`).
- Both `peal migrate` lines run against a pre-Peal fixture with exit 0 and nothing
  reported (negative case: a misspelled flag).
- The tasks.md skeleton matches `plugin/templates/task.md` (negative case: `## Done when`
  renamed).
- design.md's `.belfry.yml` and decision-entry blocks are checked, each with a negative case.
- "every marker kind is used" covers the new kinds; `tools/lint.sh` is clean.

## Raw

> every example in the docs is exercised by a harness (m2's acceptance criterion 4,
> found not met by the m2 review, 0046: four unmarked fenced blocks)

## Notes

- Open: whether a block that cannot run sensibly (the settings.json pin) gets an explicit
  exempt marker, or a check of its own (valid JSON, the repo and marketplace names).
- Open: the migrate commands need a pre-Peal fixture project to run against;
  `plugin/lib/migrate.test.sh` has synthetic fixtures that may serve.
- 2026-10-18, human (planning): no exempt marker, every block gets a real check;
  design.md's three blocks are in this task; decision entry: `peal decision check` in a
  scratch repo, else a structural check (Outcome says which); belfry: `tasks:` part
  byte-equal to `peal init`'s, `actions:` equal to one of init's commented suggestions;
  sections compared to the task template; `ref` accepts `vX` or `vN.N.N`, no lookup;
  migrate lines share one fixture in document order, exit 0 and empty stderr required.
  Defaults agreed: every fence at column 0 whatever its language; m2.md and m3 untouched.
- 2026-10-18, human (close): the merge of main brought an unmarked `claude plugin` block
  into `CONTRIBUTING.md` (0115's refresh section). `install` is extended to check
  `claude plugin` lines too (marketplace `peal`, plugin `peal@peal`, subcommands
  marketplace add/update and install/uninstall, `--scope` user/project/local), with a
  negative case; `CONTRIBUTING.md` marks that block `install`.

## Plan

**Enforcement.** In `blocks()` of `tools/docs.test.sh`, a fence that opens with no marker
pending reports `FILE:LINE: a fenced block with no docs-check marker`, through
`docs_problems`. Column-0 fences only, every language; note it in the harness header.

**New kinds**, each comparing the example to the code producing it:
- `settings` (`docs/getting-started.md:19-26`, `docs/design.md:584-591`): valid JSON via
  `plugin/lib/settings-json.awk` (`op=has`); `extraKnownMarketplaces.peal` and
  `enabledPlugins.peal@peal` present; `"repo"` equals `PEAL_INIT_MARKETPLACE`
  (`plugin/lib/init.sh:23`); a `"ref"` only `vX` or `vN.N.N`.
- `migrate` (`docs/migrating.md:67-69`, `90-92`): one pre-Peal fixture repo
  (`tasks/{backlog,doing,done}`, numbered milestone docs, a `key: value`-header task in
  each pool named, a milestone a task uses), lines run in document order through this
  checkout's `peal`; exit 0 and empty stderr; the milestones line's pool files exist
  afterwards. Fixture written in the harness, shapes from `plugin/lib/migrate.test.sh`.
- `sections` (`docs/reference/tasks.md:77-88`): `## ` headings minus `## Plan` equal
  `plugin/templates/task.md`'s, `---` before `## Outcome`; `## Plan` right after `## Notes`.
- `belfry` (`docs/design.md:61-82`): `tasks:` part byte-equal to what
  `peal init --stage tasks` then `--stage belfry` writes in a scratch repo (files
  storage, `init.sh:419-435`); `actions:` part equals one of init's commented suggestions
  with `# ` removed.
- `decision` (`docs/design.md:534-542`): written to `docs/decisions/0042-title.md` in a
  scratch repo whose config sets `decisions`, `peal decision check` run there
  (`docs/reference/cli.md:497-517`); if that needs more than this, a structural check
  (title `# NNNN — `, `Date:`, `Status: accepted|superseded by NNNN`, the bold labels).

Negative cases: marker removed, wrong repo in the pin, `--parked` misspelt, a section
renamed, a `claim:` line changed in the belfry block, a broken `Status:` line. "every
marker kind is used" lists the new kinds. `CONTRIBUTING.md:47-55` lists every kind
(including `frontmatter`).

**Verification:** `bash tools/docs.test.sh`, `tools/lint.sh`.

Touches: `tools/docs.test.sh`, `docs/getting-started.md`, `docs/migrating.md`,
`docs/reference/tasks.md`, `docs/design.md`, `CONTRIBUTING.md`.

Ranges: `tools/docs.test.sh:1-399`, `docs/getting-started.md:6-26`,
`docs/migrating.md:49-92`, `docs/reference/tasks.md:17-33`, `docs/reference/tasks.md:73-93`,
`docs/design.md:59-82`, `docs/design.md:530-543`, `docs/design.md:578-593`,
`docs/reference/cli.md:44-62`, `docs/reference/cli.md:497-517`,
`plugin/templates/task.md:1-67`, `plugin/lib/init.sh:23`, `plugin/lib/init.sh:142-204`,
`plugin/lib/init.sh:402-451`, `plugin/lib/settings-json.awk:120-130`,
`plugin/lib/migrate.test.sh:15-30`, `plugin/lib/migrate.test.sh:176-339`,
`plugin/lib/migrate.sh:10-56`, `CONTRIBUTING.md:47-55`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
