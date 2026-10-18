---
milestone: m3
plan: skipped
owner: human
---

# 0118 — Walk from the README to a first closed task by hand

## Intent

Carried forward from milestone m2's review (0046), acceptance criterion 4: "A reader new
to Peal gets from the README to a first worked task with the README and the
getting-started guide alone". The harness covers the CLI half of that path; the
slash-command half (`/peal:setup`, `/peal:work`, `/peal:close` in a live Claude Code
session, and a pull request opened from a scratch repository) has never been walked.
The human walks it on a scratch repository with only README.md and
docs/getting-started.md at hand, and reports where the docs were unclear or wrong.

## Scope

## Done when

## Raw

> Criterion 4's README → first worked task walk through /peal:setup, /peal:work and
> /peal:close has never been done by hand. (carried forward, the human's answer in the
> m2 review, 0046)

## Notes

- Left open by 0031's Outcome ("That walk by hand is still open for the human, or for
  the m2 review") and 0058's escalation (a live `/peal:setup` run).
- Each gap found becomes an idea of its own.
- Context: README.md.

---

## Outcome

The human did this task themselves and handed it in. Nothing was built: the diff is only
the task's own move.

What they did: they read README.md and docs/getting-started.md as a reader new to Peal.
What they found, in their words:

> I have looked at the README and the getting started guide. While I agree with the
> information itself I don't like how it is written at all. It is hard to point to what
> is bothering me but I just think it does not read well as someone who has never heard
> of peal (or belfry) before.

So the two documents are right in substance and wrong in how they are written: criterion
4 (a newcomer gets from the README to a first worked task with these two documents alone)
is not met yet. Per the task's Notes, that gap is an idea of its own: a rewrite of both
documents for a reader who has never heard of Peal or Belfry, keeping their information
(rewrite-readme-for-newcomers, m3). The human has not named what reads badly yet, so that
task's Notes suggest finding it with them before rewriting.

Not done here: the slash-command half of the walk (`/peal:setup`, `/peal:work`,
`/peal:close` in a live session on a scratch repository, ending in a pull request). The
handed-in note covers reading only. The rewrite task's Notes suggest walking it once the
rewrite lands.

The review was skipped: the diff lies only in `tasks/`, one of the skip paths.
