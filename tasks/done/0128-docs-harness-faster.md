---
plan: required
touches: [tools/docs.test.sh]
milestone: m3
size: S
merge: auto
---

# 0128 — The docs harness runs faster

## Intent

`tools/docs.test.sh` takes about six minutes after task 0119, most of it sys time. Each
negative case (`mutant`) copies the repository and reruns the check of every document,
and 0119 added eleven of them. Make the harness fast again. Either each mutant checks only
the document it changes, or the harness gets its own CI shard.

## Scope

`tools/docs.test.sh` only. Each negative case (mutant) checks only the document it
changes, plus the whole-repo reference checks. No check is removed or weakened;
`plugin/`, the documents and `ci.yml` are untouched (no CI shard).

## Done when

- `bash tools/docs.test.sh` and `tools/lint.sh` pass.
- All 30 negative cases are unchanged (name, file, sed, expected text) and still fail
  on their own.
- Three timings (real/user/sys) are recorded in the Outcome: `origin/main` before,
  the commit before 0119 with its own harness, and after.
- The after-time is at or below the pre-0119 time; if it misses, the gap is recorded
  and a follow-up idea filed.

## Raw

> The docs harness is slow: tools/docs.test.sh takes about 6 minutes after 0119 (mostly
> sys time), because each negative case (`mutant`) copies the repository and reruns the
> check of every document, and 0119 added eleven. A mutant could check only the document
> it changes, or the harness could get its own CI shard. Found in 0119.

## Notes

- Open: which of the two, or both. A mutant that checks one document still needs the
  whole-repo checks (every marker kind is used, the command headings) where its mutation
  bears on them.
- Open: the time before 0119 was not measured; measure both for comparison.
- 2026-10-21, human: one document per mutant only, no CI shard (A1). Bar: after-time
  at or below the pre-0119 time; a miss is recorded and filed as an idea, not a
  failure (A2, A3). Mutants check only the changed document; cross-document effects
  of a mutation are left to the positive pass on the real repository (A5).
  `reference_problems` runs for every mutant (A6). The `ci.yml` timing comment is left
  stale and mentioned in the Outcome (A4). The pre-0119 time is the older harness on
  the older documents, reported as such (A7). merge: auto agreed.
- 2026-10-21, implementer, timings (real/user/sys): origin/main before 5m46.7s / 1m33.8s / 4m33.9s; pre-0119 (ad16567^1, own harness, 26 checks) 2m36.3s / 0m47.3s / 2m11.6s; after 0m36.4s / 0m10.2s / 0m30.3s.

## Plan

Approach: `docs_problems ROOT [FILE...]`. With no FILE it works as now, over
`doc_files ROOT`; with FILEs the per-document loop (facts, links/anchors, blocks)
runs only over them. `reference_problems "$root"` still runs at the end of every
call. `mutant FILE SED` keeps its scratch copy (links resolve against the other
documents) and calls `docs_problems "$copy" "$1"`. The real-repo checks (document
counts, every marker kind used) stay as they are. The header comment (line 42) says
that each negative case rechecks only the document it edits, plus the reference
checks.

Rejected: a CI shard (leaves local runs slow), rechecking only the mutated block
(line bookkeeping, breaks migrate/unmarked-block context), parallel mutants (no less
work).

Files: `tools/docs.test.sh`.

Verification:
- `bash tools/docs.test.sh` passes with all 30 negative cases unchanged.
- A temporary, uncommitted check: a mutant on one document that expects text only
  another document produces (e.g. line 536 mutating `CONTRIBUTING.md` while expecting
  "the filed line is") must fail; then revert.
- `tools/lint.sh` clean.
- `time bash tools/docs.test.sh` on: `origin/main` before; the first parent of 0119's
  merge commit (`git log --oneline --grep='\[0119\]' origin/main`), extracted with
  `git archive <ref> | tar -x -C $TMPDIR/pre0119` (never `git worktree add`) and run
  with its own harness; after. Recorded in the Outcome.

Ranges: `tools/docs.test.sh:1-56`, `tools/docs.test.sh:85-91`,
`tools/docs.test.sh:382-455`, `tools/docs.test.sh:457-497`,
`tools/docs.test.sh:499-560`, `.github/workflows/ci.yml:85-177`,
`tools/test-all.sh:1-41`, `tasks/done/0119-docs-examples-all-checked.md:115-157`,
`CONTRIBUTING.md:49-55`.

---

## Outcome

Built: in `tools/docs.test.sh`, `docs_problems ROOT [FILE...]` now checks only the given
documents, or all of them when none are given. `reference_problems`, which checks the
command headings, still runs on every call. `mutant` passes the one document it edits, so
each of the 30 negative cases reruns only that document's checks and blocks, plus the
reference checks, instead of every document's. The real-repository pass is unchanged.
No CI shard was added. The human chose to make each mutant check one document only.

Timings, measured on the same machine with `time bash tools/docs.test.sh` (real / user / sys):

- `origin/main` before: 5m46.7s / 1m33.8s / 4m33.9s
- Before 0119 (`ad16567^1`, its own harness on its own documents, 26 checks):
  2m36.3s / 0m47.3s / 2m11.6s
- After: 0m36.4s / 0m10.2s / 0m30.3s, so about 4 times faster than before 0119.
  The reviewer measured 0m36.5s.

Checked: the harness passes 37 of 37 and `tools/lint.sh` is clean. All 30 negative cases
are unchanged and still fail on their own. A temporary case was also tried and not
committed: it pointed "the filed line is" at `CONTRIBUTING.md`, and it failed, which
shows the restriction is real.

Agreed trade-off: a mutant no longer reports a problem that its change causes in
another document, such as a broken anchor elsewhere. Only the pass on the real
repository catches those.

Left: the comment in `.github/workflows/ci.yml` about the "rest" shard's run time
("about 20 to 25 minutes") is now an overestimate. It was left alone because that file
is outside this task's scope, as agreed.

### Reviewer findings not acted on

None. The reviewer found nothing to block and kept `merge-auto`.
