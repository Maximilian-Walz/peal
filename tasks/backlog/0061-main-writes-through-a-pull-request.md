---
milestone: m1
plan: required
priority: urgent
touches: [plugin/lib/main-write.sh, plugin/lib/store-files.sh]
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

---

## Outcome

