---
description: Compare the documents the project lists in .peal/drift.md against the repository, and file one idea for each discrepancy. Fixes nothing.
argument-hint: "[what to look at, when not everything]"
---

Arguments: `$ARGUMENTS`. Anything given narrows the check to those documents or
questions of `.peal/drift.md`. Without arguments, check everything the file lists.

This command reads and files. It never edits a document or the code, even when the fix
is one line: a fix is a task of its own, with its own review. `peal` is Peal's CLI, on
the Bash tool's path.

## 1. What to compare

Read `.peal/drift.md` at the top of the repository. It is the project's list: which
documents describe the repository (a README, design documents, decision records, the
current milestone), and which specific questions to ask of them. If the file does not
exist, say so, suggest what it could list from the documents you see, and stop. Without
the project's list there is nothing to compare against.

## 2. Compare

For each document and question on the list, read the document, then check what it says
against what the repository actually holds: the code, the scripts, the configuration,
the task files or issues (`peal list`, `peal milestones`). A discrepancy is a claim that
is no longer true in either direction: the document describes something that is gone or
works differently, or the repository does something the document forbids or never
mentions where it should.

Be specific: name the document and its section, and the file or command that disagrees.
What you could not check (it needs a running build, a machine you do not have) is not a
discrepancy. Say it in the report instead.

## 3. File, one idea each

For every discrepancy, run `/peal:idea` with one idea: what the document says, what the
repository does, and where, in your own words. That holds also when the code is right and
the document is stale. One discrepancy per idea: two unrelated findings in one task make
a task nobody can close. Before filing, check `peal list` for an open task that already
covers the discrepancy, and skip the ones that have one.

On a task's branch the ideas queue and are filed when the task closes. Anywhere else they
are filed at once.

## 4. Report

List what was filed (as `peal idea` printed it), what was skipped because a task already
covers it, and what could not be checked. Nothing else changes.
