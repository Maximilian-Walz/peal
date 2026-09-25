---
milestone: m2
plan: required
depends: [0030]
---

# 0031 — README and docs for newcomers: a first screen that explains, docs split by reader

## Intent

Peal is public, and its README is its first impression. Today the README's status is one
long sentence listing internals, half the page is about working *on* Peal rather than
*with* it, and there is no install section. `docs/design.md` is accurate but written for
us: design, reference and guide in one dense document. A visitor should understand
within one screen what Peal is, why it exists and how to start, and find everything else
where they would look for it.

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

Docs, split by reader:

- `docs/getting-started.md`: the stages of `/peal:setup` and `/peal:next`, what each
  adds, how to undo it.
- `docs/guides/`: one page per workflow (working a task, the backlog commands,
  milestones, running under Belfry, releases), each short, with a real example.
- `docs/reference/`: commands, the `peal` CLI, configuration keys, task frontmatter,
  storage settings; complete and terse, the place to look things up.
- `docs/design.md`: the why, kept, pruned of what moved to the reference.
- `CONTRIBUTING.md`: the repository layout, harnesses, lint and CI, from today's
  "Working on Peal".

Signs of care:

- `CHANGELOG.md`, kept by `/peal:release` from then on.
- Issue templates (bug, idea) and a pull request template.
- Every command and config example in the docs is taken from a harness or checked by
  one, so they work when copied.
- One voice: short sentences, the same words for the same things as the commands use.

## Done when

- A reader new to Peal can go from the README to a first worked task following only the
  README and getting started.
- Every example in the docs is exercised by a harness (a docs check in
  `tools/test-all.sh`).

## Raw

Filed as issue #31 (https://github.com/Maximilian-Walz/peal/issues/31); its text is carried over into the sections above.

## Notes

---

## Outcome

