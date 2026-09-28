---
milestone: m2
plan: required
depends: []
size: M
touches: [plugin/lib/claim.sh, plugin/lib/claim.test.sh, plugin/lib/config-defaults.yml, plugin/lib/init.sh, plugin/lib/init.test.sh, plugin/lib/config.test.sh, plugin/commands/setup.md, docs/design.md, docs/security.md]
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
- `docs/security.md` names the command under Limits, like `checks.commit`.

## Done when

- Harnesses: a claim runs the command in the new worktree with the variable set; a
  failing command fails the claim and removes nothing else; a second claim of the same
  task does not run it again.

## Raw

From an infrastructure repository evaluating Peal: its diff and apply commands need a
gitignored values file, and fail in every task worktree. Belfry gets the matching hook
for the worktrees it creates itself.

## Notes

The human's answers to the planner's questions (2026-09-28), each the proposed default:
- A1: a resumed parked claim that gets a new worktree runs the setup too, in both storages.
- A2: no retry. A claim whose setup failed is not re-run by a later "claimed here already" claim; the failure message says to run the command by hand.
- A3/A12: on failure nothing is rolled back (the branch stays pushed, the worktree stays), and the exit status is 2.
- A4: the key is `worktree-setup` and the variable `PEAL_PRIMARY`; no other variables.
- A5/A11: the command's output always goes to stderr; there is no timeout.
- A6: accept the command from the checkout's config, like `checks.commit`, and document it under Limits in docs/security.md.
- A7/A9: "local-looking" means ignored files present in the checkout whose basename matches `.env*` or `*.local.*`, at most 5. `/peal:setup` mentions the setting in any stage's report while it is unset, and never writes it.
- A8/A10: tests cover the files storage only; the setup runs after the git hooks are ensured and the turn budget starts, and before the scope-overlap warning (which a failure skips).

## Plan

Approach:
- `plugin/lib/config-defaults.yml`: add `worktree-setup: ""` with a comment. `peal init` writes it as a comment by itself.
- `plugin/lib/claim.sh`:
  - a new `_peal_claim_setup WT`, called in `_peal_claim_one` after `peal_store_claim` succeeds and `_peal_claim_started` has run. The "claimed here already" branch returns earlier, so it never runs twice.
  - it reads `peal_config_get worktree-setup`; an empty value does nothing.
  - the primary checkout is the first entry of `git worktree list --porcelain`, as in `peal_worktrees_dir`.
  - it prints `claim: running worktree-setup in WT` to stderr, then runs `(cd "$WT" && unset GIT_* vars && PEAL_PRIMARY=<primary> bash -c "$cmd") </dev/null >&2`, the pattern `_peal_close_checks` uses.
  - on failure: `claim: task N is claimed at WT, but worktree-setup failed (status S); the claim and its worktree stay: fix it and run it there by hand, or release the claim`, return 2, and no path line. `--next` stops.
  - update `peal_claim`'s header comment.
- `plugin/lib/init.sh` (`--survey`): a new line `local-files <comma list | ->` listing ignored files present in the checkout (`git ls-files --others --ignored --exclude-standard`) whose basename matches `.env*` or `*.local.*`, at most 5.
- `plugin/commands/setup.md`: step 1 describes the `local-files` key. When it is not `-` and `peal config worktree-setup` is empty, step 7's report adds one line naming the setting, with the symlink example.
- `docs/design.md`:
  - the Configuration defaults block gets the key;
  - the `peal claim` bullet gets a sentence on the setup run and its failure;
  - an example follows the settings block: `worktree-setup: 'for f in .env values.local.yaml; do ln -sf "$PEAL_PRIMARY/$f" "$f"; done'`;
  - the survey paragraph mentions `local-files`.
- `docs/security.md`: a Limits entry. `worktree-setup` is a command read from the checkout's `.peal/config.yml` and run by `peal claim`, the same class as `checks.commit`.

Verification:
- `plugin/lib/claim.test.sh`, a new function `worktree_setup`:
  1. The command runs in the worktree with `PEAL_PRIMARY` set to the primary checkout's physical path, the exit status is 0, and `--print-path`'s last line is still the path.
  2. A second claim ("claimed here already") does not run it again: a counter file stays at 1.
  3. A failing command (`echo broken >&2; exit 3`):
     - the claim exits non-zero, and stderr holds `broken` and the failure message;
     - the worktree and the local and remote branches remain, and `peal list` shows the task claimed-live with `wt:`;
     - other tasks are untouched, and stdout has no path line.
  4. An empty setting runs nothing.
  5. A resumed parked claim runs it.
  6. `--next` with a failing setup stops and claims no second task.
- `plugin/lib/init.test.sh`:
  - a bare project gives `local-files -`;
  - ignored `.env` and `config.local.yaml` give `local-files .env,config.local.yaml`;
  - tracked or unignored files are not listed;
  - update the full survey expectations (around lines 315-327).
- `plugin/lib/config.test.sh`: `peal config worktree-setup` prints the value, and unknown keys are still refused.
- `tools/lint.sh` and every `*.test.sh`.

Ranges: tasks/doing/0071-worktree-setup.md:1-45, docs/design.md:335-359, docs/design.md:520-579, docs/design.md:981-1023, docs/security.md:57-75, plugin/lib/claim.sh:17-37, plugin/lib/claim.sh:153-264, plugin/lib/store-files.sh:842-953, plugin/lib/store-issues.sh:847-898, plugin/lib/close.sh:407-421, plugin/lib/config.sh:1-46, plugin/lib/config-defaults.yml:1-47, plugin/lib/init.sh:77-85, plugin/lib/init.sh:484-608, plugin/commands/setup.md:22-41, plugin/commands/setup.md:203-216, plugin/lib/claim.test.sh:1-60, plugin/lib/init.test.sh:305-387.

---

## Outcome

Built as planned: `worktree-setup: <command>` (default empty) in `plugin/lib/config-defaults.yml`.
- **Where it runs.** `_peal_claim_setup` in `plugin/lib/claim.sh` runs it from `_peal_claim_one`, right after `peal_store_claim` and `_peal_claim_started` and before the scope-overlap warning. That is above both storages, so files and issues behave the same.
- **How it runs.** In the new worktree, `GIT_*` unset, stdin closed, `PEAL_PRIMARY` set to the primary checkout (the first entry of `git worktree list --porcelain`), and all its output on stderr. `--print-path`'s stdout contract is untouched.
- **When it runs.** Once, after a fresh claim and after a resumed parked claim. Never again on "claimed here already": the human chose no retry marker (A2).
- **Failure.** Status 2, the command's output, and `claim: task N is claimed at WT, but worktree-setup failed …`. Nothing rolls back (branch pushed, worktree kept), and `--next` stops there. On failure stdout still carries the store's `claimed N branch path` line, which is printed before the setup runs, but no bare path line.
- **Survey.** `peal init --survey` prints `local-files`: ignored files present in the checkout whose basename matches `.env*` or `*.local.*`, at most 5. `/peal:setup` names the setting in its report while it is unset, and never writes it.
- **Docs.** `docs/design.md` has the key, the claim sentence, a symlink example (`for f in .env values.local.yaml; do ln -sf "$PEAL_PRIMARY/$f" "$f"; done`) and the survey line. `docs/security.md` lists the command under Limits, the same class as `checks.commit` (A6).

Found at close and fixed: the survey walked every ignored directory (`git ls-files --others --ignored` without `--directory`). That is slow under a large `node_modules` and lists files like `deps/pkg/.env.example`. It now passes `--directory`, and a test covers it.

Tested in the files storage only (A8). The issues storage runs the same code path above the store, but no harness exercises it. Belfry's matching hook for worktrees it creates itself is Belfry's, and not in this repository.

### Reviewer findings not acted on

- `_peal_claim_setup` repeats `peal_worktrees_dir`'s one-line awk that finds the primary checkout (`plugin/lib/claim.sh`). Two copies in one file of an idiom used throughout the code base, which the agreed plan named; a helper adds nothing yet.
