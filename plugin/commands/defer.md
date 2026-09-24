---
description: Give this worktree's claim back when the task turns out blocked and nothing was built, keeping its number and what this session learned; then delete the claim.
argument-hint: "<why the task cannot go on now>"
---

Why: `$ARGUMENTS`

`peal` is Peal's CLI, on the Bash tool's path. Defer is the inverse of a claim: for a task
that cannot go on (a prerequisite its `depends` missed, something that does not exist
yet, scope that belongs to another task) and on whose branch nothing was built. What this
session learned goes back onto the task under the same number, then the claim's branch
and worktree are deleted, and the task is free again, or blocked on what it now depends
on. Real work on the branch is not deferred: it ends through `/peal:close`, with an
Outcome.

A reason is required. If `$ARGUMENTS` gives none, ask the human for it with
`AskUserQuestion`.

## 1. The task

Run `peal work`. Its `TASK <id> <file>` line names the task this worktree holds; anything
else means this is no task's worktree: say so and stop. Read the task's text with
`peal read <id>`.

## 2. What was learned, written into the task

Compose the task's text anew from what `peal read` printed:

- Under `## Notes`, what the next claim should know before it starts.
- `depends` corrected when the block is really another task: its id. `human` when only
  the human can lift it (a hand-over, a decision). Never leave that in prose only: no
  claim reads prose.
- `## Scope` and `## Done when` tightened, if planning found them narrower or wider.
- `## Raw` unchanged, `part-of` unchanged, `## Outcome` left empty: a filled Outcome
  means work happened, which is a close.
- The milestone is not moved into a `parked` one: that is a milestone review's call.
  Suggest it in Notes instead.

## 3. Ideas still queued

Run `peal ideas`. Ideas queued in this worktree go with it: file them now with
`peal ideas --flush`, or tell the human which are dropped.

## 4. Give the claim back

```bash
peal defer --reason "<why>" <<'TEXT'
<the composed text>
TEXT
```

It refuses, and changes nothing, when: this is not the task's worktree; the branch holds
anything beyond the claim (for task files, anything but the claim commit and commits of
the task's own file alone, as an autosave or `peal record` makes them; for issues, any
commit at all); something is uncommitted besides the task's own file; the remote's branch
holds commits this worktree lacks; or the text fails the checks a revise makes. A
refusal for work means `/peal:close` is the way out, not this.

On success the task's text, with a dated line `Deferred <date> after a claim: <why>`, is
where the storage keeps it (the task file on the main branch, or the issue with the
reason as a comment), and the claim is marked deferred. Its last line names the
release to run.

## 5. Delete the claim

A session cannot remove the worktree it stands in. Call `ExitWorktree` with
`action: "keep"`, never `"remove"`, then run the release `peal defer` printed, from the
main checkout:

```bash
peal release <id>
```

It keeps the branch's tip under `refs/reaped/` and deletes the worktree, the branch and
its remote copy (and, for an issue, the `in progress` label). If `ExitWorktree` is
missing or refuses (the session did not start this worktree), do not remove anything
yourself: the claim is deferred already, and the next session start on this machine
releases it once this session has been idle for half an hour. Say so, and give the
human the release line to run sooner.

## 6. Report

Say what `peal defer` and `peal release` printed, and the task's state now (`peal list
<id>`): free again, or blocked on what it depends on. `/peal:work <id>` claims it afresh,
with the corrected text.
