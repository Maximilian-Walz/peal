---
milestone: m3
plan: skipped
depends: [0123]
---

# 0129 — Walk the slash commands live on a scratch repository

## Intent

Task 0118 walked the README to a first task with the CLI only. Walk `/peal:setup`, `/peal:work` and `/peal:close` in a live Claude Code session on a scratch repository, following the rewritten README and docs/getting-started.md alone, and record where a newcomer would stall.

## Scope

- The live walk and fixes to the two documents for what it finds.

## Done when

- The walk reached a closed task using only those two documents, or each stall is fixed or filed.

## Raw

> The slash-command half of 0118 walk was not done; walk it once the rewrite lands.
(task 0123 Notes)

## Notes

Deferred 2026-10-18 after a claim: the rewrite it walks (0123, PR #216) has not merged

- Queued by the implementer of 0123.
- Depends on 0123 (README and getting-started rewrite, PR #216): the walk follows the
  rewritten documents, and fixes to them would conflict with that pull request while it
  is open. Claimed once before 0123 merged and given back with nothing built.

Walk, 2026-10-19 (implementer). Live: `claude -p` nested sessions with `--plugin-dir plugin/`
(not the marketplace install, which would load main's plugin, not this checkout's) in a
scratch repository under the sandbox's temporary directory, origin a local bare repository.
Live: `/peal:setup`, `/peal:idea`, `/peal:work 0001` (claim, implementer) and a second
`/peal:work` in the worktree, which went on to the review and `peal close finish` through
the loaded `/peal:close` skill. Not exercised: the plugin marketplace install, the
interactive questions (`AskUserQuestion` does not exist in `-p`; the sessions printed their
questions with defaults instead), the pull request and the wait for checks (no GitHub
remote; the close stopped at `BLOCKED:close-unfinished` after pushing the branch). The
nested sessions inherited `BELFRY_*` variables and took the Belfry branch of `/peal:idea`
until they were unset: an artifact of the walk, not a stall.

Stalls found:

- After `/peal:idea` on the main branch the file is on the remote, not in the checkout
  (`behind 1`); getting-started said to open the file. Fixed in getting-started.
- An idea is `plan: skipped` with empty Scope and Done when, so no planner runs and the
  implementer stops with questions; both documents promised a plan to agree. Fixed in
  both.
- After the `tasks` stage alone, `peal commit` and `peal close begin` refuse until
  `.peal/peal hooks install` runs. Stopgap line added to getting-started; the code gap is
  queued as idea tasks-stage-hooks-gap.
- Test runs left `__pycache__` that blocked the close's clean-tree check: the project's
  own `.gitignore` job; not documented.
- Setup did not offer a first task here (a repository with a bare README, no TODOs): as
  the command describes; no stall.

---

## Outcome

- The live walk ran `/peal:setup` (tasks stage), `/peal:idea` and `/peal:work` in nested `claude -p` sessions. The sessions loaded this checkout's plugin with `--plugin-dir`, in a scratch repository whose origin was a local bare repository.
  - The second `/peal:work`, inside the worktree, built the task, reviewed it, wrote its Outcome and ran `peal close finish`.
  - The walk stopped at `BLOCKED:close-unfinished`: there was no GitHub remote for the pull request.
  - Not exercised: the marketplace install, the interactive `AskUserQuestion` (it does not exist in `-p`), and the pull request with its checks. A later walk with a real GitHub scratch repository could cover these.
- Fixed in docs/getting-started.md:
  - An idea filed from the main branch lands on the remote's main, not in the checkout, so update the checkout to see it. When main refuses direct pushes, the idea arrives as a pull request instead; the reviewer found that case and it is fixed in its own commit.
  - An idea comes out `plan: skipped` with empty Scope and Done when. No planner runs, and the implementer asks its questions with proposed answers.
  - A stopgap: run `.peal/peal hooks install` after merging the setup.
- README step 2 now says a small task can skip the plan.
- Filed as idea tasks-stage-hooks-gap: only the `guardrails` stage installs the git hooks (`peal_hooks_ensure` returns early otherwise), yet `peal commit` and `peal close` refuse without them. A tasks-only project therefore stalls at its first commit. The reviewer confirmed this in plugin/lib/githooks.sh, commit.sh and close.sh. When that idea lands, remove the stopgap line from getting-started.
- Left as is: test runs left `__pycache__` in the scratch project and blocked the clean-tree check. That is the project's own `.gitignore` job, and the refusal names the files.
- For the next session: the repository's CLAUDE.md line "a fresh clone installs the git gates itself" holds only for projects that set up `guardrails`. Peal itself does.
