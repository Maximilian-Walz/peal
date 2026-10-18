---
plan: required
touches: [tools/lint.sh, tools/lint.test.sh]
milestone: m3
size: S
---

# 0100 — tools/lint.sh lists the repository's files only, not sandbox placeholders

## Intent

`tools/lint.sh`, which `checks.close` runs at every close, collects its shell scripts with `find . -type f` and runs `head -n1` on every non-`*.sh` file to look for a shell shebang. In a sandboxed worktree, `find` also meets placeholder mounts the session cannot read (`./.claude/...`, `./.zshrc` and the like), so `peal close finish` prints a screenful of "head: cannot open ... Permission denied" lines. The close succeeds, but the output reads as a failure. When this is done, lint considers only the repository's own files (tracked, plus untracked ones that are not ignored), says nothing about files it cannot open, and still finds every script it finds today.

## Scope

- `tools/lint.sh`'s file list: `git ls-files -co --exclude-standard` instead of `find`, skipping anything that is not a readable regular file.
- A `--list` flag on `tools/lint.sh` and a harness, `tools/lint.test.sh`.

## Done when

- `tools/lint.sh` in a worktree with an unreadable untracked file prints no `head:` error and still finds every script it found before (compare the old and new script lists in a clean checkout).
- `bash tools/lint.test.sh` passes: `--list` shows exactly the repository's readable scripts, quietly.

## Raw

Belfry friction, 2026-09-28 (jobs 82475d7e2bf6a2dd, f95455300fd56365, 8fd4e894f5ebad08): "peal close finish prints `head: cannot open './.zshrc'` and similar lines"; "floods its output with sandbox head: cannot open ./.claude/... Permission denied lines".

## Notes

- Open question (answered below): `git ls-files -co` also lists tracked files deleted from the worktree, and symlinks; skip those quietly. Should a tracked script that exists but cannot be read be reported rather than skipped?
- The same reports' other points are tasks of their own: the upstream that cannot be recorded in a sandbox, and 0067 (close waits with wait_ci).
- 2026-10-18, the human: a tracked script that exists but cannot be read is skipped quietly, like anything that is not a readable regular file. `git ls-files`' own stderr is silenced (a real git failure still ends in the empty-list exit 2). Add a harness, `tools/lint.test.sh`, with a `--list` flag on lint.sh. Accepted: ignored files drop out of the list, symlinks are skipped (as `find -type f` did), paths lose their `./` prefix.

## Plan

Approach:
- `tools/lint.sh`: replace `find . -type f -not -path './.git/*' | sort` with `git ls-files -co --exclude-standard -z 2>/dev/null | sort -zu`, read with `while IFS= read -r -d '' file`. At the top of the loop skip anything that is not a readable regular file: `[ -f "$file" ] && [ ! -L "$file" ] && [ -r "$file" ] || continue` (drops deleted tracked files, symlinks, submodule gitlinks, sandbox devices and unreadable files, quietly). An empty list still hits the existing "the search is broken" exit 2. Update the header comment to say the list is git's tracked and untracked-but-not-ignored files.
- `tools/lint.sh --list`: print the scripts found, one per line, and exit 0 without running shellcheck, pins or `peal check`.
- `tools/lint.test.sh` (new, runnable with `bash`): copy lint.sh into `tools/` of a scratch git repository holding a `.sh` file, a file with a bash shebang, a file with a `#!/bin/sh` shebang, an ignored script, an unreadable untracked script (`chmod 000`; skip that case when running as root), an untracked symlink to a script, and a deleted tracked non-`.sh` file; run `--list` and assert exactly the expected scripts and an empty stderr; also assert the empty-list exit 2 outside a git repository.

Files: `tools/lint.sh`, `tools/lint.test.sh`.

Verification:
1. In a clean scratch clone (`git clone --shared`, never `git worktree add`), print the old loop's list (from `git show origin/main:tools/lint.sh`) and `tools/lint.sh --list`; strip the old `./`, sort, diff: empty. Record both counts in the Outcome.
2. `bash tools/lint.test.sh` passes.
3. `tools/lint.sh` in this sandboxed worktree prints no `head:` and no "Permission denied"; `bash -n` and shellcheck (lint lints itself and its harness) pass.

Ranges relied on: tools/lint.sh:1-28, .gitignore:1-30, .github/workflows/ci.yml:187-192, .peal/config.yml:13, CONTRIBUTING.md:47-60, tasks/done/0087-sandbox-mount-placeholder-outside-sandbox.md:137-144, docs/design.md:326.

---

## Outcome

<!-- Written at close, replacing this comment. -->
