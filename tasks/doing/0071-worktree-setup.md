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

Proposed plan, NOT agreed (planner, 2026-09-28; the human could not be asked because Belfry's inbox returned 503):
- Key `worktree-setup: ""` in plugin/lib/config-defaults.yml; `_peal_claim_setup WT` in plugin/lib/claim.sh, called from `_peal_claim_one` after `peal_store_claim` succeeds (covers both storages; the "claimed here already" path returns before it).
- Runs `(cd WT && unset GIT_* && PEAL_PRIMARY=<primary> bash -c "$cmd") </dev/null`, with its output sent to stderr. The primary checkout is the first entry of `git worktree list --porcelain`.
- On failure: status 2, no path line, and nothing rolled back (branch pushed, worktree kept); the message says to run the command by hand. `--next` stops.
- `peal init --survey` gets a `local-files` line (ignored files present in the checkout matching `.env*` or `*.local.*`, at most 5); plugin/commands/setup.md mentions the key in its report while it is unset; docs/design.md gets the key, the claim sentence and a symlink example; docs/security.md gets an entry under Limits.
- Tests in claim.test.sh (runs with the variable set; not run on a second claim; failure keeps everything; empty setting; resumed parked claim; `--next` stops), init.test.sh (survey), config.test.sh (the key).
- Size M, model default, merge default.
- Open questions, each with its default: A1 run on a resumed parked claim (yes); A2 retry marker `peal-setup-done` (no, as literally specified); A3 exit status (2); A4 names (`worktree-setup`, `PEAL_PRIMARY`, no other variables); A5 output to stderr, shown on success; A6 security (accept like `checks.commit`, add an entry under Limits in docs/security.md); A7 local-looking files (present ignored files matching `.env*` or `*.local.*`, cap 5); A8 an issues-storage test (no); A9 `/peal:setup` mentions it in its report in any stage, never writes it; A10 runs after the hooks are ensured, before the overlap warning; A11 no timeout; A12 "removes nothing else" = no rollback at all.


---

## Outcome
