---
plan: skipped
priority: low
touches: [plugin/lib/backlog.sh, plugin/lib/apply.sh, plugin/lib/hostile.test.sh]
---

# 0260 — peal create caps the slug's length in bytes

## Intent

A task's slug is cut to its first five words, but nothing limits its length in bytes. A title made of one very long word therefore yields a file name past the file system's 255-byte limit: writing the task file fails, and every later main-write in that repository fails with it. `hostile.test.sh` currently works around this by trimming its hostile titles to 100 bytes.

Cap the slug in bytes, cutting on a character boundary (never inside a multi-byte UTF-8 character), at every place a slug is made, so that `peal create` and `peal apply` both get it.

## Scope

## Done when

## Raw

> peal create caps the slug's length in bytes
>
> ## Intent
>
> The slug is cut to five words (`cut -d- -f1-5` in `plugin/lib/backlog.sh` and `plugin/lib/apply.sh`), but there is no cap on its bytes. A very long `--title` (one long word, say) makes a file name past the 255-byte limit. The task file's write fails, and later main-writes in the same repository fail too. Found while building 0204: `hostile.test.sh` cuts its hostile titles to 100 bytes to work around it.
>
> Cap the slug in bytes, on a character boundary, everywhere a slug is made.
>
> ## Done when
>
> - `peal create` and `peal apply` file a task whose title is one 400-byte word, and the next main-write succeeds.
> - `hostile.test.sh` no longer cuts its titles.

## Notes

- Both slug sites (`plugin/lib/backlog.sh:168`, `plugin/lib/apply.sh:396`) go through `_peal_slug_normalise` in `plugin/lib/task-text.sh`; putting the cap there (or in one shared helper both call) would cover every slug at once. Check for other callers that build slugs without it.
- Open question: what cap? The file name is `0260-<slug>.md`, and directory paths or branch/worktree names built from the slug may have their own limits; a cap well under 255 bytes (and the trailing `-` trimmed after the cut) leaves room for those.
- Open question: should a repository that already holds an over-long name be recovered, or is preventing new ones enough? The idea asks only for the latter.
- `docs/reference/tasks.md` describes task file names; update it if it states the slug rule.

---

## Outcome

<!-- Written at close, replacing this comment. -->
