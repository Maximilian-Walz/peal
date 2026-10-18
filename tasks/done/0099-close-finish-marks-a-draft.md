---
plan: required
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/lib/fake-gh, plugin/commands/close.md, docs/reference/cli.md]
milestone: m3
size: S
---

# 0099 — `close finish` marks a draft pull request ready

## Intent

Some tasks can only write their Outcome after a real CI run, because their Done when quotes one. CI runs only on pull requests, and `close finish` opens the pull request after the Outcome is written, so such a task has no CI result when it needs one. One session worked around this by opening a draft pull request by hand before the review. `finish` then found that pull request and updated its body, but left it a draft, and the session had to run `gh pr ready` by hand.

When this is done, `finish` marks an existing draft pull request for the branch ready for review and says it did. The close command also tells a session how to get a CI run early when its Outcome needs one: open a draft pull request before the review.

## Scope

- `close finish`: when it finds an open pull request for the branch that is a draft, mark it ready (and say so).
- `plugin/commands/close.md`: one line on opening a draft pull request before the review when the Outcome needs a CI result.

## Done when

- close.test.sh: finish on a branch with an open draft pull request leaves it ready for review.

## Raw

Belfry friction, 2026-09-28 (job 33b6933b2e19f581): "peal close has no step for getting CI before the Outcome ... finish updates the PR but leaves it a draft."

## Notes

- Open question: should the early draft be a step of its own (a `close draft` subcommand, or `finish` able to run twice) rather than a manual `gh pr create --draft`? Out of scope unless the planner and the human agree to it.
- Open question: does `finish` refresh the draft's body with the final Outcome? The friction suggests it does; check.
- Open question: check that close's wait for green checks still works when CI already ran on the draft.
- 2026-10-18, plan agreed with the human:
  - Body refresh (open question 2): finish already PATCHes the title and full body from the final Outcome (close.sh:524-540, tested in finish_cases). Nothing to build.
  - Wait for green (open question 3): verify reads the checks of the local HEAD's sha, so it works. Files storage pushes a new close commit and a new run; issues storage may push nothing, and the draft's checks on that sha stand.
  - Separate draft step (open question 1): no. A session runs `gh pr create --draft` by hand.
  - Order: the human left it to the session, which chose to mark the draft ready **before** the push. The close commit's CI then runs on a ready pull request, so a CI that skips drafts never leaves a skipped run that reads as passing.
  - If marking it ready fails: finish returns 1 and keeps the sentinel; a re-run resumes.
  - close.md line: push, `gh pr create --draft --base <main branch> --fill`, read the result with `gh pr checks` (`peal close wait` is blocked once `close begin` arms the sentinel).
  - Message: its own line, `marked pull request #N ready for review`.
  - Also touch plugin/lib/fake-gh (needed for the test) and docs/reference/cli.md (finish's description).
  - `close verify` stays unchanged; queue an idea for a `BLOCKED:draft` verdict.
  - Deleted the stale "No milestone" note: the frontmatter and m3 both name 0099.

## Plan

Approach, in `peal_close_finish` (plugin/lib/close.sh):
- Move the open-PR lookup for the branch ahead of the push, and widen its `--jq` to also return `.draft` and `.node_id`. The branch and repo are known before the push.
- If the lookup fails at that point, report it and return 1 with the sentinel armed. Do not print the by-hand fallback, which assumes the push happened.
- If the pull request found is a draft, mark it ready with `peal_gh graphql` and `markPullRequestReadyForReview(input: {pullRequestId: $id})`, the pattern of `enablePullRequestAutoMerge` in plugin/lib/main-write.sh:277-282. Print `marked pull request #N ready for review`. On failure, say so and return 1 with the sentinel kept.
- Then push as today. Then PATCH the title and body of the pull request found, or create one if none was found, as today.
- A pull request that is not a draft gets no extra call.
- Update the function's doc comment.
- Rejected: REST `draft: false` (GitHub ignores it), `gh pr ready` (bypasses `peal_gh` and the fake), a `close draft` subcommand.

Files:
- plugin/lib/close.sh: the lookup moved and widened, the mutation, the message, the doc comment.
- plugin/lib/close.test.sh: new `draft_cases` in `cases()`, so they run on both storages.
- plugin/lib/fake-gh: a `*markPullRequestReadyForReview*` branch in its graphql case. It refuses a node_id that is not an open pull request and otherwise sets `draft: false`. Update the header comment.
- plugin/commands/close.md: the line on opening a draft before the review when the Outcome needs CI (push, `gh pr create --draft --base <main branch> --fill`, read the result with `gh pr checks`).
- docs/reference/cli.md: finish "opens the pull request or updates the open one" gains "and marks a draft ready".

Verification, `bash plugin/lib/close.test.sh`:
- Draft: an open draft PR saved with `gh_save pulls` (`draft: true`, `node_id`, `head.ref`). Then begin, outcome, finish. Expect: status 0, `.[0].draft == false`, one PR, the "marked ... ready" and "updated the title and body" lines, the final Outcome in the body, the sentinel clear. On files storage, the graphql call comes before the push in `$FAKE_GH/log` where the log shows it.
- Not a draft: the existing re-run in finish_cases logs no `POST graphql` and prints no "marked" line.
- Mutation fails (`POST graphql` in `$FAKE_GH/fail`): status 1, the sentinel armed, still a draft, nothing pushed. Remove the fail file and run again: success, ready.
- `peal check` and shellcheck on the touched files.

Ranges: tasks/doing/0099-close-finish-marks-a-draft.md:1-40, docs/milestones/m3.md:8-27, plugin/lib/close.sh:423-558, plugin/lib/close.sh:644-679, plugin/lib/github.sh:1-4, plugin/lib/github.sh:46-112, plugin/lib/main-write.sh:277-282, plugin/lib/fake-gh:1-40, plugin/lib/fake-gh:107-135, plugin/lib/fake-gh:173-216, plugin/lib/fake-gh:252-273, plugin/lib/fake-gh:306-313, plugin/lib/close.test.sh:28-111, plugin/lib/close.test.sh:291-362, plugin/lib/close.test.sh:601-610, plugin/lib/close.test.sh:723-747, plugin/lib/issue-fixtures.sh:89-106, plugin/commands/close.md:46-60, plugin/commands/close.md:98-146, docs/reference/cli.md:436-450, .github/workflows/ci.yml:3-16

---

## Outcome

`peal close finish` now marks a draft pull request ready for review. After the close commit and **before the push**, it looks up the branch's open pull request, fetching `draft` and `node_id` along with the number and URL. If it is a draft, finish runs GraphQL `markPullRequestReadyForReview` through `peal_gh`, the same pattern as auto-merge in main-write.sh, and prints `marked pull request #N ready for review`. It then pushes and PATCHes the title and body, or creates the pull request when none was open, as before. A pull request that is not a draft gets no extra call.

The human left the order to the session, which put mark-ready before the push. The close commit's CI then always runs on a ready pull request, so a project whose CI skips drafts never gets a skipped run that verify reads as passing. Because the lookup now runs before the push, its failure no longer prints the by-hand `gh pr create` fallback, which assumed the branch was pushed. It now says the close is committed here and returns 1. A failed mark-ready does the same. Both keep the sentinel, so running finish again resumes.

The task's open questions:
- Finish already rewrote the draft's body with the final Outcome.
- `close wait` works on a draft that already ran CI. It reads the checks of the local HEAD's sha. Files storage pushes a new close commit and so starts a new run. Issues storage may push nothing, and the draft's checks on that same sha stand.
- No separate `close draft` step: one `gh pr create --draft` is enough.

Also changed:
- plugin/lib/fake-gh fakes the mutation. It refuses a node id that is not an open pull request.
- plugin/commands/close.md step 2 tells a session that needs a CI result for its Outcome how to get one: push, `gh pr create --draft --base <main branch> --fill`, then read it with `gh pr checks`, because `peal close wait` is refused once the sentinel is armed.
- docs/reference/cli.md describes the new behaviour.

Tests: new `draft_cases` in close.test.sh, on both storages. A failed mutation stops finish (status 1, sentinel armed, still a draft, nothing pushed). A re-run marks it ready, updates its body and pushes. The existing re-run case for a pull request that is not a draft checks that no graphql call is made. `bash plugin/lib/close.test.sh`: 915 passed, 0 failed.

Left: `close verify` still reports READY for an open draft with green checks, filed as the idea close-verify-draft-verdict (a `BLOCKED:draft` verdict). The test does not assert that the graphql call comes before the push in the fake's log, because the log does not record a push. "Still ahead of upstream after the failed mutation" covers the order instead.

The review found nothing. The only change after it was rewrapping an overlong doc-comment line in close.sh.
