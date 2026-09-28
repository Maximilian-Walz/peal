---
plan: required
touches: [tools/lint.sh]
---

# 0100 — tools/lint.sh lists the repository's files only, not sandbox placeholders

## Intent

`tools/lint.sh`, which `checks.close` runs at every close, collects its shell scripts with `find . -type f` and runs `head -n1` on every non-`*.sh` file to look for a shell shebang. In a sandboxed worktree, `find` also meets placeholder mounts the session cannot read (`./.claude/...`, `./.zshrc` and the like), so `peal close finish` prints a screenful of "head: cannot open ... Permission denied" lines. The close succeeds, but the output reads as a failure. When this is done, lint considers only the repository's own files (tracked, plus untracked ones that are not ignored), says nothing about files it cannot open, and still finds every script it finds today.

## Scope

- `tools/lint.sh`'s file list: `git ls-files -co --exclude-standard` instead of `find`, skipping anything that is not a readable regular file.

## Done when

- `tools/lint.sh` in a worktree with an unreadable untracked file prints no `head:` error and still finds every script it found before (compare the old and new script lists in a clean checkout).

## Raw

Belfry friction, 2026-09-28 (jobs 82475d7e2bf6a2dd, f95455300fd56365, 8fd4e894f5ebad08): "peal close finish prints `head: cannot open './.zshrc'` and similar lines"; "floods its output with sandbox head: cannot open ./.claude/... Permission denied lines".

## Notes

- Open question: `git ls-files -co` also lists tracked files deleted from the worktree, and symlinks; skip those quietly. Should a tracked script that exists but cannot be read be reported rather than skipped?
- The same reports' other points are tasks of their own: the upstream that cannot be recorded in a sandbox, and 0067 (close waits with wait_ci).

---

## Outcome

<!-- Written at close, replacing this comment. -->
