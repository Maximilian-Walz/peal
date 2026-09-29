---
milestone: m2
plan: required
depends: [0030]
size: M
touches: [README.md, CONTRIBUTING.md, docs/getting-started.md, docs/design.md, tools/docs.test.sh, .github/ISSUE_TEMPLATE/*, .github/pull_request_template.md]
---

# 0031 — README and docs for newcomers: a first screen that explains, docs split by reader

## Intent

Peal is public, and its README is its first impression. Today the README's status is one
long sentence listing internals, half the page is about working *on* Peal rather than
*with* it, and there is no install section. `docs/design.md` is accurate but written for
us: design, reference and guide in one dense document. A visitor should understand
within one screen what Peal is, why it exists and how to start, and find everything else
where they would look for it.

This task is narrowed to the first piece: README, getting started, CONTRIBUTING, the
templates and the docs check. The rest is split into 0105 (reference, design.md pruned),
0106 (guides) and 0107 (CHANGELOG kept by `/peal:release`).

## Scope

README:

- One sentence on what Peal is, then a short example of the loop (an idea becomes a
  task, `/peal:work` plans and builds it, `/peal:close` opens the PR), as a terminal
  excerpt.
- Why it exists, in three points (tasks in the repository, one branch and worktree per
  task, a plan before code), and what it is not.
- **Start:** install the plugin (the two `/plugin` lines), then `/peal:setup`. Nothing
  else.
- Status in two lines, with a link to the roadmap (the milestones), not a list of what is
  built.
- Peal and Belfry, in three sentences, with a link.
- Contributing and license as links.

Docs:

- `docs/getting-started.md`: the stages of `/peal:setup` and `/peal:next`, what each
  adds, how to undo it.
- `CONTRIBUTING.md`: the repository layout, harnesses, lint and CI, from today's
  "Working on Peal".

Signs of care:

- Issue templates (bug, idea) and a pull request template.
- Every command and config example in these documents is taken from a harness or checked
  by one, so they work when copied: `tools/docs.test.sh`, run by `tools/test-all.sh`.
- One voice: short sentences, the same words for the same things as the commands use.

## Done when

- A reader new to Peal can go from the README to a first worked task following only the
  README and getting started.
- Every example in README, CONTRIBUTING and docs/ (outside docs/milestones/ and
  docs/decisions/) is exercised by `tools/docs.test.sh` at the agreed level: marked blocks
  run or load, every command, subcommand and relative link named is validated.

## Raw

Filed as issue #31 (https://github.com/Maximilian-Walz/peal/issues/31); its text is carried over into the sections above.

## Notes

Revised 2026-09-29: split: 0105, 0106, 0107 hold the rest

The human's answers in planning (2026-09-29):

- Split as proposed: this task keeps README, getting-started, CONTRIBUTING, templates and
  the docs check; 0105, 0106, 0107 hold the rest.
- CHANGELOG: a generic feature, task 0107; this task creates no CHANGELOG.
- Docs check strictness: the middle level. Blocks marked `<!-- docs-check: run -->` run in
  a scratch repo, blocks marked `<!-- docs-check: config -->` load through `peal config`;
  every `peal <sub>`, `/peal:<cmd>` and relative link/anchor in README, CONTRIBUTING and
  docs/ (not milestones/, decisions/) is validated.
- 0058 is open: getting-started describes today's end of `/peal:setup`; 0058 gets
  "getting-started.md updated" in its Done when and touches.
- "What it is not": not a tracker UI; not a replacement for GitHub issues (it can store
  tasks there); does not need Belfry; not an autonomous agent (the human merges).
- The loop excerpt is composed from real CLI output lines (idea's `filed:`, claim's path,
  close's PR line), whose shapes the harness checks.
- Install: the two lines only (`/plugin marketplace add Maximilian-Walz/peal`,
  `/plugin install peal@peal`), default scope; the pin-a-release JSON moves to
  getting-started.
- Templates: `idea.md` replaces `task.md` (keeping its Security line and "a maintainer
  files it with /peal:idea"); new `bug.md`; no `config.yml`; the PR template only gains a
  link to CONTRIBUTING.
- Defaults accepted: HTML-comment markers; the bell-ringing etymology as one short line
  near the bottom; CONTRIBUTING carries layout, harnesses, lint, CI, running on itself
  (`PEAL_ROOT=$PWD/plugin`) and the commit grammar in one paragraph; undoing `/peal:next`'s
  feature suggestions is documented as deleting the file or key, nothing filed; issues are
  not tasks, kept in CONTRIBUTING and templates; status is a pre-v1 sentence and a link to
  docs/milestones/, no badge; the docs treat Peal as public; Belfry: its repository link
  plus design.md's section (0106 repoints it); CLAUDE.md left alone and mentioned in the
  Outcome.

## Plan

Approach:

1. README.md rewritten to the Scope. "Working on Peal" (README.md:59-104) moves to
   CONTRIBUTING.md. The pin-a-release JSON (README.md:28-33) moves to getting-started.
2. `docs/getting-started.md`: install, then `/peal:setup`'s stages (tasks, guardrails,
   milestones, belfry), what each adds (the `peal init` table, design.md:1011-1016), how
   to undo each (`peal init --remove <stage>`), then `/peal:next` and the features within
   the stages (design.md:1045-1070), undone by deleting the file or key. Ends with a
   first task: `/peal:idea`, `/peal:work`, `/peal:close`. Describes `/peal:setup`'s end
   as it is today (0058 is open).
3. `CONTRIBUTING.md`: layout, harnesses, lint, CI (ci.yml:83-89 sharding), running on
   itself, the commit grammar; issues are not tasks.
4. `.github/ISSUE_TEMPLATE/idea.md` replaces `task.md`; new `bug.md`;
   `.github/pull_request_template.md` gains a CONTRIBUTING link.
5. `tools/docs.test.sh`, in the pattern of plugin/commands/commands.test.sh:17-32, bash
   and awk only, no network, found by tools/test-all.sh:18-20. It checks:
   - every `peal <sub>` / `.peal/peal <sub>` in code spans and fenced blocks of README,
     CONTRIBUTING and docs/**/*.md (not docs/milestones/, docs/decisions/) is a
     subcommand of `peal --help` (plugin/bin/peal:69-90);
   - every `/peal:<cmd>` exists as plugin/commands/<cmd>.md;
   - every relative Markdown link and anchor resolves;
   - every block marked `<!-- docs-check: config -->` loads through `peal config` in a
     scratch repo (unknown key fails);
   - every block marked `<!-- docs-check: run -->` runs in a scratch repo through
     `PEAL_ROOT=$REPO/plugin`, and the output lines the doc quotes appear;
   - the README's `/plugin` lines match tools/install.test.sh:34-35 and the name in
     .claude-plugin/marketplace.json;
   - negative cases on scratch copies: a renamed subcommand, `/peal:nosuch`, a broken
     link, an unknown config key each fail.
   Keep tools/ci-changes.sh:25 as it is, so docs-only PRs still run the check.

Verification:

- `bash tools/docs.test.sh`, `tools/test-all.sh`, `tools/lint.sh` pass.
- getting-started's scenario (tasks stage, `peal next`, milestones stage,
  `peal init --remove milestones`) runs in the harness.
- A walk by hand on a scratch repository, following only the README and getting-started
  (install, `/peal:setup`, `/peal:idea`, `/peal:work`, `/peal:close` up to a PR, or a note
  on what needed GitHub), recorded in the Outcome.

Touches: README.md, CONTRIBUTING.md, docs/getting-started.md, docs/design.md (only where
the new install text contradicts it), tools/docs.test.sh, .github/ISSUE_TEMPLATE/*,
.github/pull_request_template.md.

Ranges relied on: README.md:1-109; docs/design.md:1-122, 124-241, 897-961, 963-999,
1001-1070, 1072-1115, 1117-1176; docs/migrating.md:1-30; docs/milestones/m2.md:1-31;
plugin/commands/setup.md; plugin/commands/release.md:1-87;
plugin/commands/commands.test.sh:1-47; plugin/bin/peal:69-90, 462-509;
plugin/lib/config-defaults.yml:1-49; .peal/config.yml:5-15; tools/test-all.sh:1-40;
tools/ci-changes.sh:1-37; tools/install.test.sh:26-40; .github/workflows/ci.yml:83-163;
.github/pull_request_template.md:1-6; .github/ISSUE_TEMPLATE/task.md:1-21;
tasks/done/0030-peal-next.md; tasks/backlog/0058-setup-points-at-next.md:1-40.

---

## Outcome

Built the first piece of the split: the README rewritten for a stranger, `docs/getting-started.md`,
`CONTRIBUTING.md`, the issue and pull request templates, and `tools/docs.test.sh`. The rest of
the original scope is in 0105 (reference, design.md pruned), 0106 (guides) and 0107 (CHANGELOG
kept by `/peal:release`, a generic feature).

- **README**: the loop excerpt, why (three points) and what Peal is not, Start (the two
  `/plugin` lines, then `/peal:setup`), a two-line status linking to docs/milestones/, Belfry in
  three sentences, links to contributing and license. "Working on Peal" moved to CONTRIBUTING;
  the pin-a-release JSON moved to getting-started.
- **getting-started**: install, the four stages (what each adds, `peal init --remove` to take it
  back), merging the setup branch before the first task, `/peal:next` and undoing its feature
  suggestions by hand, then `/peal:idea`, `/peal:work`, `/peal:close`. It describes the end of
  `/peal:setup` as it is today; 0058's Done when and touches now include updating this page.
- **Templates**: `idea.md` replaces `task.md` (Security line kept), new `bug.md`, the PR template
  links CONTRIBUTING by absolute URL (relative links do not resolve in a PR body).
- **tools/docs.test.sh** (13 checks, run by `tools/test-all.sh`): every `peal <sub>` and
  `/peal:<cmd>` in README, CONTRIBUTING and docs/ (not milestones/, decisions/) exists; relative
  links and anchors resolve; blocks marked `<!-- docs-check: config -->` load through `peal
  config`, `run` blocks run in a scratch repo and their quoted output must appear (a line ending
  in " …" matches by prefix), `shape` compares the README's composed loop excerpt with real
  `peal idea`/`claim`/close output, and `install` checks the `/plugin` lines against
  `.claude-plugin/marketplace.json`. Negative cases on scratch copies prove each check fails.
  design.md, migrating.md and security.md already pass.

The review found a duplicated paragraph in CONTRIBUTING, a missing "merge the setup first" step
in getting-started (`/peal:work` needs the setup commit on main), and unchecked install lines in
getting-started. All three were fixed on the branch.

Evidence for the first Done when: the CLI half of the path (init tasks, idea, claim, next, init
milestones, `--remove`) ran against a scratch repo with a local bare remote, and runs in the
harness. `/peal:setup`, `/peal:work` and `/peal:close` are Claude Code commands and could not be
walked from this session; nor was a pull request opened from a scratch repo. That walk by hand
is still open for the human, or for the m2 review (0046).

For the next session: CLAUDE.md is untouched and still repeats part of the old "Working on Peal"
text; 0106 repoints the README's Belfry link to its guide.
