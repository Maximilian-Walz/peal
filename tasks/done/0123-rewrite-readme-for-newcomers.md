---
milestone: m3
plan: skipped
touches: [README.md, docs/getting-started.md]
---

# 0123 — Rewrite the README and getting-started guide for a reader new to Peal

## Intent

The human read README.md and docs/getting-started.md as task 0118's walk from the README
to a first task. They agree with what the two documents say, but not with how they say
it: to someone who has never heard of Peal (or Belfry), they do not read well. Rewrite
both for that reader, keeping their information: the same facts, told so that a newcomer
can follow them. The human could not yet name exactly what bothers them, so the first
step is finding it with them.

## Scope

- Rewrite README.md and docs/getting-started.md in the agreed style (Notes, 2026-10-18),
  keeping every fact.
- Move the getting-started guide's optional material (version pinning, the stage table,
  the `peal init` transcript, "What to adopt next") into a guide or the reference, linked
  from where it was.

## Done when

- The README opens with the problem Peal solves, then one task's round trip explained in
  plain words, and explains each term (task, worktree, claim, plan, subagent, milestone,
  Belfry) where it first appears.
- docs/getting-started.md reads Install, Set up, Your first task (what you see and do at
  each step), Next; the moved material is reachable through links and nothing is lost.
- The docs harness passes (every `docs-check:` block still valid).

## Raw

> I have looked at the README and the getting started guide. While I agree with the
> information itself I don't like how it is written at all. It is hard to point to what
> is bothering me but I just think it does not read well as someone who has never heard
> of peal (or belfry) before.
(the human's note handing in task 0118)

## Notes

- Split off task 0118 (m3, criterion 4 carried from m2: a reader new to Peal gets from
  the README to a first worked task with the README and the getting-started guide alone).
- Open question: what exactly reads badly. Worth asking the human before rewriting, e.g.
  with a draft of one section in two styles, rather than guessing. Candidates to check:
  terms used before they are explained (task file, claim, offer, pool, milestone,
  worktree, Belfry), the order (what Peal is and why before how), sentence density.
- The slash-command half of 0118's walk (`/peal:setup`, `/peal:work`, `/peal:close` in a
  live session on a scratch repository) was not done in 0118; it may be worth walking
  once the rewrite lands.
- Context: README.md, docs/design.md.
- 2026-10-18, the human's answers, after the implementer's diagnosis and two drafts of
  the README opening:
  - Style A: narrative and problem-first. Start from the reader's problem, walk the
    transcript in plain words, explain each term where it first appears, and put "what
    Peal is not" and Belfry after the walk. Lookup-style tables stay in docs/reference.
  - All the diagnosed problems are real: order (mechanism before motivation, transcript
    before explanation), jargon used before explained, optional detours before the first
    task, and a thin "Your first task" section.
  - Move the optional material out of getting-started into a guide or the reference,
    linked. Nothing is dropped.
  - The name's meaning becomes a one-line aside near the top. Use second person, plain
    words, no emojis.
  - The live slash-command walk is a separate follow-up idea, not this task.

---

## Outcome

The plan was skipped, but the first step was finding out with the human what read
badly. The implementer read both documents as a newcomer would. It found they were
ordered the way Peal is built, not the way someone uses it: mechanism before motivation,
the transcript before any explanation, terms used before they were explained,
Belfry introduced only as a denial, and getting-started's first task arriving after
about 80 lines of optional material. It drafted the README opening in two styles. The
human chose style A (narrative, problem-first, terms explained where they first appear),
agreed with every diagnosed problem, and agreed to move the optional material out of
getting-started (Notes, 2026-10-18).

Built:
- README.md: it opens with the name's meaning as a one-line aside, then the problem Peal
  solves, then one task's round trip (idea, work, close) explained in plain words. Each
  term is explained where it first appears: task with its YAML frontmatter, worktree,
  milestone, planner and implementer subagents. Then come "What Peal is not" (Belfry
  explained in place, with a link down) and "Peal and Belfry".
- docs/getting-started.md: now Install, Set up, Your first task (each step says what you
  see and do), Next.
- docs/guides/setting-up.md (new, listed in docs/guides/README.md): version pinning, the
  stage table, the `peal init` transcript and "What to adopt next", moved word for word
  and linked from getting-started.
- tools/docs.test.sh: the guide count goes from 6 to 7, and the negative-case mutants for
  the moved `docs-check` blocks now point at the new guide. The harness passes, 37 of 37.

The review found two terms (milestone, Belfry) used before they were explained, a wrong
command (`peal list` in a shell; it is `.peal/peal list` there), two dropped facts (an
idea filed on a task branch is queued until that task closes; a task's YAML
frontmatter), and the README contradicting getting-started on who writes the plan. All
six were fixed on the branch.

For the next session: the slash-command half of task 0118's walk (`/peal:setup`,
`/peal:work`, `/peal:close` live on a scratch repository) is filed as an idea
(walk-slash-commands-live). It is the natural check that a newcomer gets through with
these two documents alone. The tone of the other guides was not touched; they may want
the same treatment.
