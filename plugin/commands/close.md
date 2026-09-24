---
description: Close this worktree's task. Review the diff, route every finding, write the Outcome, then finish (the queued ideas filed, the task moved to done, the pull request opened) and wait until its checks are green.
argument-hint: "[what the human says about this close]"
---

Arguments: `$ARGUMENTS`. Anything given is the human's word on this close (most often
that the task is decided against, see the end); take it into the Outcome.

Run in the task's worktree once every `## Done when` line of the task is true, or once
the task is decided against. `peal` is Peal's CLI, on the Bash tool's path.
Every step a script can check, `peal close` checks; this command holds the judgement.

## 1. Begin

Run `peal close begin`. It arms the Stop hook: from now on, this session cannot end a
turn with the task's Outcome empty or its work uncommitted or unpushed, until `peal close
finish` has run (or the close is called off, below). It refuses outside a task's
worktree, without Peal's git hooks installed, with more than one task under `doing/`, and
on a branch that adds a backlog task file: fix what it names, never work around it.

Read all it prints:

- `NOTE` lines. Behind the main branch, or conflicting with it: merge the main branch in
  now if the task's work depends on what changed there (`git merge`, never a rebase of a
  pushed branch), cheaper now than after the Outcome. Milestone files changed: only a
  milestone's review changes them; take the change out or say why in the Outcome. Queued
  ideas: they are filed at finish; drop or add one now. `## Scope` or `## Done when`
  empty: fill them in from the agreed plan or from what was built, unless nothing was
  built.
- `Outcome:`, the file to write the task's Outcome in (for tasks kept elsewhere than in
  files, a file of the close's own).
- `PR sections`, the project's own sections of the pull request body, each with what to
  write in it.
- The diff since the main branch, and the task's `## Done when`.

## 2. Review

Run `peal config review.skip-paths`. Unless every path of the diff (`git diff --name-only
<main branch>...HEAD`) lies under one of them, run `peal brief reviewer` and start the
`peal:reviewer` subagent on the reviewer's model (`peal work` prints it: `MODEL reviewer`),
its prompt the brief followed by "Review task <id>." Otherwise skip the review and say in
the Outcome that the diff lies only in the skip paths. Review before writing the Outcome:
a finding caught now is an edit, one caught later a rewrite.

## 3. Route every finding

Each finding goes into exactly one of:

- **Fix** it on the branch, as a commit of its own (`peal commit`). A fix that is more
  than a small change is the implementer's: resume it, or start a fresh
  `peal:implementer` with the finding, as `/peal:work` does.
- **File** it as an idea (`/peal:idea`), only if leaving it would cost a future session;
  it queues on this branch and is filed at finish.
- **Escalate** it under `### Escalations` in the Outcome, one bullet each: only for what
  contradicts a recorded decision or needs a new one, or a `## Done when` line that cannot
  be met. More than three means the task was underspecified: finish refuses; ask the human
  about them with `AskUserQuestion` before going on.
- **Rebut** it under `### Reviewer findings not acted on` in the Outcome, one line each,
  with why.

## 4. Write the Outcome, and a decision entry if one was made

Under `## Outcome` in the file `begin` named, replacing the placeholder comment: what was
built, what was decided and why, what was found and left (each an idea filed), and what
the next session needs to know, written for someone who remembers nothing of this one;
then the Escalations and the rebuttals of step 3. Leave the Outcome uncommitted: finish
commits it with the task's move. Anything else changed now is committed now.

When the project records decisions (`peal config decisions` names a directory) and the
task made an architectural call, record it: `peal decision reserve <slug>` reserves its
number and scaffolds the entry; never take a number by reading the directory. Fill in
its title and paragraphs. If it replaces an earlier decision, it says `**Supersedes**
decision NNNN.` and that entry's `Status:` line becomes `superseded by <its number>`, the
one edit a merged entry ever gets. Never touch the directory's `index.md`: it is
regenerated on the main branch after the merge. Leave the entry uncommitted too: finish
checks it and commits it on its own, right before the task's move.

Do not end a turn between this step and finish: the Stop hook reads the uncommitted
Outcome as unfinished work.

## 5. Finish

Write the summary: three to five bullets, one change each, at most twenty words, the
first naming what the human should look at. Write each PR section `begin` listed, as its
instruction says. Then:

```
peal close finish --summary "<bullets>" [--section "<title>" "<text>"]...
```

(`--summary-file FILE` and `--section-file TITLE FILE` read a text from a file outside the
work tree, for long ones.) It refuses, before anything changes, a missing summary or
section, an empty Outcome or one with a placeholder left, more than three escalations,
an uncommitted path other than the Outcome's and the decision entries', a decision entry
out of order (`peal decision check` says the same), and a failing close check of the
project (`checks.close`): fix what it names and run it again. Then it files the queued ideas in
one push, commits the task's move to done, pushes and opens the pull request, or updates
the one open for this branch; its body is the summary, the sections, the Outcome, the
ideas filed and the branch's commits (`peal close body` with the same arguments prints it
first, if you want to see it). A failure after the ideas are filed leaves the close in
progress and says so: fix it and run finish again; it goes on where it stopped.

If the close is off instead (the scope changed, the task needs more work), call it off:
`peal close abort "<why>"`. The reason is logged; the queued ideas stay queued. Begin
again when the task is done.

## 6. Wait for green

Run `peal close wait` in the foreground, with the Bash tool's timeout at 600000: it asks
`peal close verify` again until the verdict is not `WAIT`, for up to nine minutes. Act on
its one line:

- **`READY`** (also `READY:merged`, `READY:pr-closed`, `READY:no-checks`): the pull
  request is open and green, or settled. Report its URL and the verdict. The session is
  done; the merge is the human's. In a worktree this session entered with
  `EnterWorktree`, leave it with `ExitWorktree`, keeping it: Peal removes it once the
  task has landed.
- **`WAIT:<why>`**: the checks have not settled within the budget. Run `peal close wait`
  again, the same way; nothing is wrong.
- **`BLOCKED:<why>`**: stay and fix it here, where the context is. `checks-failing`,
  `conflicts`, `uncommitted`, `unpushed`: fix, commit, push (the close is finished, so
  this is ordinary work on the branch), then wait again. `close-unfinished`: finish did
  not run through; run it again. `no-pr`: finish opened none; run it again. `no-gh`,
  `gh-failed`: report it and stay. The others (`not-a-repo`, `detached-head`, `on-main`,
  `no-upstream`): find out where this session is first.

## Closing without building

A task decided against (not wanted, not possible, split with nothing left to build here)
closes the same way, its Outcome saying why nothing was built and what, if anything,
replaces it. Its diff is the task's own, so the review is skipped. Its pull request is the
task's move to done (or, for a task kept elsewhere, an empty commit whose merge closes
it).
