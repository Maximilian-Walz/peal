---
description: Make a release from the tasks finished since the last one. Proposes the version, writes the notes from the tasks' titles and Outcomes, asks the human to confirm, then tags, pushes, makes the GitHub release and waits for the tag's CI when the project asks for it.
argument-hint: "[version]"
---

Arguments: `$ARGUMENTS`, the version to release (`1.2.0` or `v1.2.0`). Without one, the
proposed version.

`peal` is Peal's CLI, on the Bash tool's path. `peal ship` holds every step a script can
take; this command holds the one question for the human. It runs anywhere in the
repository (a Belfry action with a Release button runs it as `/peal:release
{version}`), claims no task and writes no task file. The tag goes on the remote's main
branch, whatever is checked out here.

## 1. What went in

Run `peal ship propose`. It prints `LAST <tag>` (or `LAST none`), one `ITEM kind id prs
title` line per finished task and per `feat` or `fix` commit of no task since then
(kind `breaking`, `feature`, `fix`, or `none` for a task marked `release-note: none`),
and last `PROPOSE <tag> <bump>` or `NOTHING since <tag>`.

- `NOTHING` and no version given: nothing calls for a release. Say so and stop, with
  nothing changed.
- A version given: that version, whatever the proposal. Still show the proposal to the
  human when they differ.

Then run `peal ship notes <version>` for the notes.

## 2. Ask

Ask the human exactly one `AskUserQuestion`: "Release <version>?". Put in it the last
release, the version and why (`major` for a breaking task, `minor` for a feature, `patch`
for fixes only, `first` without an earlier release), and the notes' sections, shortened
if long. Options: the version (first, as proposed or given), the other bumps that
make sense (the next patch, minor or major version), and not now. The human may name
another version as their own answer. Not now means stop, with nothing changed.

A version the human chose that differs from the notes shown: run `peal ship notes`
again for it; the first line and links change with the version, the items do not.

## 3. Tag and publish

1. `peal ship tag <version>`: the annotated tag on the remote's main branch, the notes'
   first line its message, pushed. It refuses a tag that exists already, here or on the
   remote, and a version not above the last release: tell the human, ask for another
   version once, and stop on a second refusal. A release is never moved.
2. `peal ship publish <version>`: the GitHub release with the notes, created or brought
   up to date. On a remote not on GitHub it says so, and the tag is the release. When it
   fails (no `gh`, not logged in), the tag stands: report the command to run again.

## 4. The release's CI

Run `peal config release.wait-ci`. When it is `true`, run `peal ship wait <version>`, and
again while it prints `WAIT:...`. Its verdict:

- `READY`: every workflow run of the tag succeeded.
- `FAILED:<run> <url>`: a run failed. The tag and release stand; report the run for the
  human to look at. Never delete or move the tag.
- `NONE:<why>`: no workflow ran for the tag. Report it: the project's release workflow
  may not run on tags.

The `RUN` lines name each run, and each `REPORT` line is what the project asked for in
`release.report` (an image digest, say) as the run's log printed it.

## 5. Report

End with the version, the tag's commit, the release URL (or that the tag is the
release), the CI's verdict with its `REPORT` lines, and the notes' first line.
