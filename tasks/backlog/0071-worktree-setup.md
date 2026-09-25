---
milestone: m2
plan: required
depends: []
---

# 0071 — A worktree setup command: local files in every task worktree

## Intent

Many projects keep files out of git that their commands need: `.env`, `*.local.yaml`,
credentials for a local tool. A task worktree that `peal claim` creates lacks them, so
the project's build, diff or test commands fail in every worktree until someone copies
them in by hand. When this is done, a project names a setup command in its config, and
every worktree Peal creates runs it once, so a worktree works like the primary checkout.

## Scope

- A config key (for example `worktree-setup: <command>`), run in the new worktree after
  it is created by a claim, with the primary checkout's path in an environment variable
  so the command can link or copy from it. A failing command fails the claim, with its
  output; an already existing worktree does not run it again.
- `/peal:setup` mentions it when the repository ignores files that look local
  (`.env*`, `*.local.*`).
- The docs show the common case: symlinking gitignored files from the primary checkout.

## Done when

- Harnesses: a claim runs the command in the new worktree with the variable set; a
  failing command fails the claim and removes nothing else; a second claim of the same
  task does not run it again.

## Raw

From an infrastructure repository evaluating Peal: its diff and apply commands need a
gitignored values file, and fail in every task worktree. Belfry gets the matching hook
for the worktrees it creates itself.

## Notes


---

## Outcome
