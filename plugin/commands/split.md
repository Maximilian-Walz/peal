---
description: Split this worktree's task into pieces, filed in one push with part-of, then narrow the task to its first piece or close it as split.
argument-hint: "[how to split it]"
---

Anything the human said about the split: `$ARGUMENTS`

`peal` is Peal's CLI, on the Bash tool's path. Run this in the worktree of the task to
split, the *origin*; its number is the split's identity. One task is still one branch and
one pull request: a split gives the other pieces tasks of their own, linked to the origin
by `part-of`, instead of prose.

How to cut the work is your judgement: do not ask the human about it. What a piece leaves
unclear goes into that piece's `## Notes`. Only the choice in step 4 may go to the human.

## 1. The origin

Run `peal work`. Its `TASK <id> <file>` line names the origin and its text; anything
else (a refusal, a claim, an offer) means this is no task's worktree: say so and stop.
Read the text, and the plan in its `## Plan` if there is one.

## 2. The pieces

Decide first whether the origin keeps working on the first piece (the usual case: step
4) or closes as split. When it keeps the first piece, file only the others; when it
closes, file them all.

Each piece is a task text:

- **Title**, and an **Intent** restating its own slice of the origin's work. The origin's
  Intent stays the record of the whole.
- **Scope** and **Done when**: the headings only, left empty; the session that claims the
  piece writes them.
- **Raw**: the origin's own words (its Raw or Intent) this piece carves out, verbatim and
  quoted, then the line `Split from ORIGIN`.
- **Notes**: what the piece leaves unclear, and a size estimate as prose if you have one.

Frontmatter, per piece:

- `part-of: ORIGIN`, always; `ORIGIN` becomes the origin's id.
- `milestone`: the origin's, written out. A piece gated on something no other piece
  builds may go into a `parked` milestone; only a split may do that.
- `plan`: `required` when the piece's work touches one of `peal config
  plan.required-paths` (unsure counts as required), else `skipped`.
- `depends`: `ORIGIN` when the piece needs the origin's own work; `PART1`..`PARTn` for a
  sibling filed in this same push, numbered in the order of the slugs below; real ids,
  `human`. Judge each piece on its own: one that builds on a sibling's work depends on
  that sibling, not only on the origin.
- `size`: left out, the planner's.

Write `NNNN` for the piece's own number in its heading, as `/peal:idea` does:

```markdown
---
milestone: <the origin's>
plan: <required | skipped>
depends: [ORIGIN, PART2]
part-of: ORIGIN
---

# NNNN — <Title>

## Intent

<this piece's slice>

## Scope

## Done when

## Raw

> <the origin's words for this slice>

Split from ORIGIN

## Notes

---

## Outcome

<!-- Written at close, replacing this comment. -->
```

## 3. File them, in one push

A slug per piece, two to five kebab-case words, in the pieces' order:

```bash
peal create --part-of <origin id> <slug-1> <slug-2> <<'PIECES'
<piece 1's text>
-----NEXT TASK-----
<piece 2's text>
PIECES
```

Nothing is filed unless every piece passes; a refusal names what to fix. A piece's
`depends` that closes a cycle (`refused: depends cycle PART1 → 0042 → PART1`), often a
piece waiting for a task that itself waits for the origin, is one to drop. Report every
`filed ...` line as printed, and the `pull request #N <url>` line when main takes writes
through pull requests: the numbers are final once it merges.

## 4. Narrow the origin, or close it as split

When the conversation does not already say which, ask the human with `AskUserQuestion`,
narrowing first and marked "(Recommended)":

- **Narrow and keep working.** Rewrite the origin's text to its first piece: Scope and
  Done when become that piece's, the Intent stays or is trimmed to the piece with the
  whole noted in Notes ("the rest is split into <ids>"). Raw, `part-of` and the Outcome
  stay as they are; the origin never gets a `part-of`. Record it on the claim:

  ```bash
  peal revise <origin id> --reason "split: <ids> hold the rest" <<'TEXT'
  <the narrowed text>
  TEXT
  ```

  A `## Plan` agreed for the whole is trimmed to the first piece in the same text, or
  emptied so the narrowed task is planned again. Then continue with `/peal:work`.
- **Close as split.** Nothing else is built in this session: `/peal:close`, with an
  Outcome saying the task was split into the pieces just filed, naming them.

A task that depends on the origin needs no change: depending on a split task waits for
the origin and all its pieces. Re-point it (`/peal:revise`) only if it needs just one
piece.

## 5. Report

Say what was filed, with ids and triage as printed, and whether the origin was narrowed
(and to what) or is closing as split.
