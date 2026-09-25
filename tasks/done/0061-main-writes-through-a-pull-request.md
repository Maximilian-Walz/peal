---
milestone: m1
plan: required
priority: urgent
touches: [plugin/lib/main-write.sh, plugin/lib/main-write.test.sh, plugin/lib/store-files.sh, plugin/lib/store-files.test.sh, plugin/lib/store-issues.sh, plugin/lib/decisions.sh, plugin/lib/github.sh, plugin/lib/close.sh, plugin/lib/fake-gh, plugin/lib/config-defaults.yml, plugin/lib/config.test.sh, plugin/templates/decisions.yml, docs/design.md]
size: L
model: opus
---

# 0061 — Writes onto a protected main go through a pull request

## Intent

The task-file storage writes onto the main branch directly: `/peal:idea` files a task,
`/peal:revise`, `/peal:retire`, `/peal:defer` and `peal set-milestone` edit one,
`peal milestone-state` changes a milestone, and the decisions module publishes its index,
all through `peal_push_main` (`plugin/lib/main-write.sh`). A repository whose main is
protected (a ruleset or branch protection that requires pull requests, as Peal's own
repository has) refuses every one of those pushes, so its backlog cannot change at all.
When this is done, such writes still happen: Peal pushes the same commit to a short-lived
branch, opens a pull request for it, and lets it merge once the required checks pass,
without a human step.

## Scope

- `plugin/lib/main-write.sh` and its callers; a new setting `main-writes: push | pr | auto`
  in the config (`auto`, the default: push, and on a refusal by a repository rule or
  branch protection switch to a pull request, remembered for the clone).
- The pull request: branch `peal/main-write-<short sha>`, the build's subject as its title,
  a body saying which command made it; merged by GitHub's auto-merge
  (`gh pr merge --auto --squash`, which needs "Allow auto-merge" in the repository's
  settings), or, when auto-merge is off, by the command itself once the checks pass,
  within a time limit it reports when it runs out.
- `peal create --part-of` (the pieces of `/peal:split`) goes the same way. Today it has no
  queued fallback either, and `peal idea` refuses `part-of`, so a split on a protected main
  loses the pieces' link to their origin (friction from 0039's session).
- Races: two writes built on the same main, e.g. two filings taking the same number. The
  second pull request conflicts or its number is taken; the command rebuilds on the new
  main (as a lost push race does today) and replaces its pull request.
- The command's output says a pull request was opened and where, and waits for it only
  as long as the caller needs the result (filing prints the task id at once; the id is
  final once the pull request merges).

## Done when

- A harness with a bare remote whose `pre-receive` hook refuses pushes to main, and
  `fake-gh`, covers: a filing through a pull request, `main-writes: push` failing as
  today, a race of two filings with the second rebuilt, and a merge waiting for checks.
- `docs/design.md` explains the three settings and why `auto` is the default.
- In Peal's own repository, `/peal:idea` files a task end to end (a human check, listed
  under "Human steps" in the pull request).

## Raw

From a review of Peal running on itself: every filing, revision and milestone change
since the switch to task files was refused by the ruleset on main.

## Notes

- Peal's ruleset on main: pull requests required, required status checks, no bypass.
  A bypass for admins would work around it here, but every project with a protected
  main has the same problem, so Peal handles it.
- Human step: enable "Allow auto-merge" in the repository's settings.
- Plan settled with the human (headless, through the inbox):
  - Whole, as L; no split. Races stay in this task.
  - Edits return once auto-merge is on, like filing; a conflict after the command
    returned is left for a human. `PEAL_MAIN_WRITE_WAIT=merged` waits for callers that
    need main to hold the change.
  - Number race: the lower pull request number wins; branch stays
    `peal/main-write-<short sha>`.
  - `auto` switches on any server-side `[remote rejected] <main>`, never on a local gate
    refusal or a non-fast-forward.
  - `pr` is remembered in `git config peal.mainWrites`; `git config --unset` forgets it
    (documented, no subcommand).
  - Time limit out: report the pull request as open, status 3; no resume subcommand.
  - Auto-merge refused because the PR is already clean: merge directly (PUT, squash).
  - Auto-merge through GraphQL `enablePullRequestAutoMerge` via `peal_gh`, not
    `gh pr merge` (the clean solution over the Scope's wording).
  - Decisions publish in CI is in scope: the workflow template uses an optional
    `PEAL_TOKEN` secret when set, else `GITHUB_TOKEN`.
  - A read before the write merged fails as today, with a hint that a Peal pull request
    may still be open.
  - The squash subject's ` (#N)` is acceptable.
  - Body: `peal <command>` plus the task id from `[NNNN]`; no label.
  - The checks logic moves from `close.sh` into `github.sh` as `peal_pr_checks`.
  - The issues storage warns when `main-writes` is set.

## Plan

**Core, `plugin/lib/main-write.sh`.** `peal_push_main BUILD [COMMAND]` picks the route
from `main-writes: push | pr | auto` (default `auto`; `auto` with `git config
peal.mainWrites pr` means `pr`). `push` is today's loop unchanged. Under `auto`, a failed
push that is not a lost race (`new = base`) and whose stderr shows a server-side
`[remote rejected] <main>` switches to a pull request; anything else stays status 1.
The pull request route:
1. push `$sha:refs/heads/peal/main-write-<short sha>`;
2. `POST repos/{repo}/pulls` through `peal_gh`/`peal_json` (as `close.sh:536-541`),
   title `PEAL_SUBJECT`, body "Made by `peal <command>`" plus the task id from `[NNNN]`
   and that Peal merges it;
3. enable auto-merge (squash) with GraphQL `enablePullRequestAutoMerge` through
   `peal_gh`;
4. when auto-merge is not allowed or the PR is already clean: poll `peal_pr_checks`
   every `PEAL_MAIN_WRITE_INTERVAL` (20) s within `PEAL_MAIN_WRITE_BUDGET` (540) s, then
   `PUT pulls/<n>/merge` squash and delete the branch; a failing check leaves it open
   and reports it; budget out prints the PR URL as open, status 3.
Remember `pr` in `git config peal.mainWrites` once a first PR has opened.

**Races.** A filing, after opening its PR, lists open `peal/main-write-*` PRs with a
lower number, fetches their branches and checks them and main for its ids; if one is
taken it closes its PR, deletes the branch, rebuilds with the next free id and opens a
replacement ("replaces #N"). `_peal_files_next_id` (`store-files.sh:274-286`) also counts
ids on open main-write branches. An unmergeable PR (`mergeable: false`) is closed, its
branch deleted, main fetched and the write rebuilt (stale edits refused as today,
`store-files.sh:415-425`) and replaced. Bounded by `PEAL_PUSH_ATTEMPTS`.

**Return.** Filing prints its `filed NNNN ...` lines once the id check passes, plus
`pull request #N <url>; the number is final once it merges`, and returns (unless it
must merge itself). Edits return once auto-merge is on. `PEAL_MAIN_WRITE_WAIT=merged`
waits until merged. "no task NNNN" errors hint that a Peal PR may still be open.
Builders' status codes pass through (3, 4, 2); PR opened is 0; budget out is 3.

**Callers.** `store-files.sh` (lines 332, 476, 596, 651, 759, 1065) and
`decisions.sh:366` pass their command name and print the PR line; `peal create
--part-of` takes the same path. `store-issues.sh` warns when `main-writes` is set.

**Checks.** `peal_pr_checks REPO SHA` (READY / WAIT / BLOCKED) extracted from
`peal_close_verify` (`close.sh:667-691`) into `github.sh`, used by both.

**CI.** `plugin/templates/decisions.yml` uses an optional `PEAL_TOKEN` secret (PAT or
app token) when set, else `GITHUB_TOKEN`; without it a protected main's publish PR
waits for a human.

**fake-gh.** GraphQL auto-merge (refused when `$FAKE_GH/no-auto-merge`), `PUT
pulls/N/merge` squashing into the bare remote in `$FAKE_GH/remote`, `DELETE
git/refs/heads/...`, closing a PR, a `$FAKE_GH/checks-pending` counter.

**Files.** `plugin/lib/main-write.sh`, `main-write.test.sh` (new), `store-files.sh`,
`store-files.test.sh` (refusal case at 172-179 gets `main-writes: push`),
`store-issues.sh`, `decisions.sh`, `github.sh`, `close.sh`, `fake-gh`,
`config-defaults.yml` (`main-writes: auto`), `config.test.sh` (15-42),
`plugin/templates/decisions.yml`, `docs/design.md` (Configuration 495-532, the lock
principle 19-21, the pre-push note 555-561: the three settings, why `auto` is the
default, the CI token, the issues-storage warning).

**Verification.** `plugin/lib/main-write.test.sh`, a bare remote whose `pre-receive`
refuses `refs/heads/main`, and `fake_github`:
1. a filing through a PR: branch holds exactly the new file, title/body, auto-merge
   requested, `peal.mainWrites` is `pr`, a second filing skips the direct push,
   worktree untouched;
2. `main-writes: push` fails as today (status 1, git's reason, no PR);
3. a merge waiting for checks (`no-auto-merge`, `checks-pending=2`, interval 0): main
   holds one squash commit; a failing check leaves it open; budget out gives 3;
4. two filings racing (a pre-push hook pushes a rival branch adding 0002 with a lower
   PR number): the filing ends as 0003, its first PR closed, a replacement open;
5. an unmergeable edit PR closed and the rebuild refused "changed meanwhile".
`tools/test-all.sh` and `tools/lint.sh` pass (bash 3.2 compatible). Human steps in the
PR: enable "Allow auto-merge" in Peal's repository; then `/peal:idea` files a task end
to end.

Ranges: `plugin/lib/main-write.sh:1-70`; `plugin/lib/store-files.sh:7-45`, `272-380`,
`412-484`, `541-658`, `715-780`, `1044-1070`; `plugin/lib/decisions.sh:352-398`;
`plugin/lib/ideas.sh:56-95`; `plugin/lib/close.sh:518-552`, `624-715`;
`plugin/lib/github.sh:9-78`; `plugin/lib/fake-gh:1-30`, `81-202`;
`plugin/lib/issue-fixtures.sh:29-42`; `plugin/lib/store-files.test.sh:1-60`, `136-180`;
`plugin/lib/close.test.sh:17-42`; `plugin/lib/config.test.sh:15-43`;
`plugin/lib/config-defaults.yml:1-41`; `plugin/lib/githooks.sh:114-136`, `193-206`;
`plugin/bin/peal:121-137`, `348-356`; `plugin/commands/split.md:86-126`;
`docs/design.md:12-31`, `471-481`, `483-537`, `555-561`;
`tasks/backlog/0066-release-bumps-plugin-version.md:1-28`;
`.github/workflows/ci.yml:1-41`.

---

## Outcome

Built as planned. `peal_push_main` (`plugin/lib/main-write.sh`) picks the route from
`main-writes: push | pr | auto` (default `auto`). Under `auto`, a server-side
`[remote rejected] <main>` switches the write to a pull request, and the clone remembers
the switch in `git config peal.mainWrites pr`. `git config --unset peal.mainWrites`
forgets it. A lost push race or a local gate refusal never switches the route.

The pull request route works like this:
- It pushes branch `peal/main-write-<short sha>` and opens the pull request through the
  REST API.
- It turns on auto-merge (squash) through GraphQL. When auto-merge is not allowed or the
  pull request is already clean, Peal merges it itself once `peal_pr_checks` is ready,
  within `PEAL_MAIN_WRITE_BUDGET`. Running out of time reports the pull request as open,
  with status 3.
- A filing returns once its id check passes and prints `pull request #N <url>`.
  `PEAL_MAIN_WRITE_WAIT=merged` waits for the merge.
- Races: when an open main-write pull request with a lower number took the same id, the
  filing closes its own pull request and opens a replacement with the next free id. An
  unmergeable pull request is closed and the write rebuilt, and a stale edit is refused
  as before.

Other changes:
- `peal create --part-of` (the pieces of a split) goes the same way.
- `store-issues.sh` warns when `main-writes` is set.
- The checks logic moved from `close.sh` into `github.sh` as `peal_pr_checks`.
- The decisions workflow template uses an optional `PEAL_TOKEN` secret, falling back to
  `GITHUB_TOKEN`, and gains `pull-requests: write`.
- `docs/design.md` has a new section, "Writes onto main". `fake-gh` learned auto-merge,
  merge, branch delete, closing a pull request and pending checks.
- `plugin/lib/main-write.test.sh` covers the plan's five cases: a filing through a pull
  request, `push` failing, a merge waiting for checks, a race and a conflict.
  `tools/test-all.sh` and `tools/lint.sh` pass.

Outside the touches list, all for the Scope's "says a pull request was opened and where":
- `plugin/commands/idea.md` and `plugin/commands/split.md` report the pull request line.
- `.peal/config.yml`'s commented defaults list `main-writes: auto`.

For the next session:
- The third Done-when line (`/peal:idea` end to end in Peal's own repository) can only be
  checked after the merge. It is a human step: first turn on "Allow auto-merge" in the
  repository's settings.
- For a split, the pull request body names the origin task (taken from the commit
  subject's `[NNNN]`), not the new piece.
- Right after a pull request opens, GitHub usually reports `mergeable` as null, so the
  immediate unmergeable check rarely fires against the real API. A conflict found after
  the command returned is left for a human, as agreed in the plan.

### Human steps

- In the repository's settings, turn on "Allow auto-merge" (General → Pull Requests).
- After the merge, from the main checkout, run `/peal:idea` with any small idea. Check that it prints `pull request #N <url>`, that the pull request merges by itself once the checks pass, and that the task shows up on main.
- Optional: add a `PEAL_TOKEN` secret (a PAT or app token) so that the pull requests the decisions workflow opens also run their required checks.
