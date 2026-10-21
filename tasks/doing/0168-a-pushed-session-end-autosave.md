---
milestone: m3
plan: required
size: M
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/agents/implementer.md, docs/design.md, docs/reference/cli.md]
---

# 0168 — A pushed session-end autosave is never rewritten, so close finish's push is not refused

## Intent

The SessionEnd hook (`plugin/lib/session.sh`) commits a session's uncommitted work as `wip: session-end autosave [ID]` and pushes it to origin. When a later session's implementer soft-resets or amends that autosave into proper commits, the local branch no longer contains the pushed tip, and `peal close finish`'s push is refused as non-fast-forward. One session got past it by hand with `git merge -s ours` of the remote autosave (its tree matched) and ran finish again.

The aim is that this no longer happens, or no longer stops close: either the implementer brief forbids rewriting a pushed autosave (keep it, build on it), or finish recognises a remote tip whose tree matches a local ancestor and reconciles it with an `ours` merge, which loses nothing, or names the one command that does. Either way a harness case covers an autosave pushed and then rewritten locally.

## Scope

- `plugin/agents/implementer.md`: a rule that a pushed commit (the session-end autosave included) is never reset, amended, rebased or squashed; build on it.
- `plugin/lib/close.sh`: `peal close finish` fetches the task branch, detects a remote tip that is not an ancestor of HEAD, reconciles it with an `ours` merge when its tree equals the tree of a commit in base..HEAD, and refuses early otherwise.
- `plugin/lib/close.test.sh`: harness cases for both outcomes.
- `docs/reference/cli.md`, `docs/design.md`: the new finish behaviour and the autosave rule.

## Done when

- The implementer brief forbids resetting, amending, rebasing or squashing a pushed commit, the autosave by name, in the words of close begin's NOTE.
- A finish on a branch whose pushed autosave was rewritten locally into a commit with the same tree merges the remote tip with `-s ours`, pushes and opens the PR (harness, both storages).
- A finish on a branch diverged from its remote with no local tree matching, or with the remote strictly ahead, is refused before anything changes, naming the command (harness).
- `close.test.sh`, `session.test.sh` and `tools/lint.sh` pass.

## Raw

> A pushed session-end autosave is never rewritten, so close finish's push is not refused
>
> ## Intent
>
> The SessionEnd hook commits uncommitted work as `wip: session-end autosave [ID]` and pushes it to origin (`plugin/lib/session.sh`). A later implementer that soft-resets that autosave into proper commits leaves the branch diverged from origin, and `peal close finish`'s push fails non-fast-forward. The session got past it with `git merge -s ours` of the remote autosave (same tree) and ran finish again.
>
> ## Done when
>
> - The implementer brief (`plugin/agents/implementer.md`) says a pushed `wip:` autosave is kept and only built on, never reset or amended. Or:
> - finish notices a remote tip whose tree matches a local ancestor and either reconciles it (an `ours` merge, which loses nothing) or names the one command that does.
> - A harness case covers an autosave pushed and then rewritten locally.
>
> ## Notes
>
> - Rebasing a pushed branch is already against the rules (close.sh's behind NOTE says so). The brief should say the same about the autosave.

## Notes

- Open question: brief rule, finish-side reconciliation, or both? The idea offers them as alternatives; the brief alone does not help a session that already rewrote the autosave, while finish alone leaves the rewrite allowed.
- Open question: if finish reconciles, does it merge on its own or only print the command? An automatic `ours` merge is safe only when the remote tip's tree equals a local ancestor's tree exactly; anything else must stop as now.
- Rebasing a pushed branch is already against the rules (close.sh's behind NOTE); the brief's wording should match it.
- Files likely involved: `plugin/agents/implementer.md`, `plugin/lib/session.sh`, close.sh's finish. `docs/design.md` for the session-end autosave and close.
- 2026-10-21, the human's answers at planning: both halves (brief rule and finish repair); finish makes the `-s ours` merge itself when a tree matches; the rule is an exact tree match of the remote tip against a commit in base..HEAD, not `git merge-tree`; any matching tree qualifies, not only `wip:` subjects; finish fetches the task branch first, warning and using the known tracking ref when that fails; a remote strictly ahead of HEAD is refused early, naming `git merge <ref>`; the merge subject is `Merge <ref>: the pushed autosave, already here [ID]`, kept in the PR's commit list; the rule goes into the implementer brief only, not work.md or close.md; the SessionEnd hook's own failing push is left as is.

## Plan

Both halves.

1. **Brief** (`plugin/agents/implementer.md:21-43`): after "Commit as you go", a rule: a commit already on the remote, a `wip: session-end autosave` included, is never reset, amended, rebased or squashed; build on it with new commits. Wording matches close begin's NOTE (`plugin/lib/close.sh:116-138`, "never rebase a pushed branch").
2. **Finish detects, in the refusal phase** (`plugin/lib/close.sh:487-628`, after the dirty-tree and hooks checks, before `_peal_close_checks`): fetch the task branch from `$PEAL_REMOTE` quietly (on failure warn and go by the known ref, as begin does); `_peal_close_remote_ref` (`close.sh:21-39`). If there is a remote ref that is not an ancestor of HEAD: when HEAD is an ancestor of it (remote strictly ahead), refuse with status 2 naming `git merge <ref>`; otherwise compare `<ref>^{tree}` with the trees of `$PEAL_BASE..HEAD`, HEAD included. A match means reconcile; no match refuses with status 2 before anything changes, saying origin holds commits this branch rewrote or lacks, naming `git merge <remote>/<branch>` (and `git merge -s ours` only once every change of theirs is here), and to finish again.
3. **Finish reconciles, in the change phase** (after the flush, before `peal_decisions_commit` and the storage's finish commit, so `docs(tasks): close` stays last; `close.sh:662-674`, `703-711`, `757-761`): `git merge -q -s ours --no-edit -m "Merge <ref>: the pushed autosave, already here [ID]" <ref>`, one line printed. A rerun finds the ref already an ancestor: idempotent. Update `peal_close_finish`'s header comment.
4. **Docs**: `docs/reference/cli.md:153-160`, `486-509` (`peal close finish`: the refusal under Refuses, the merge under Then); `docs/design.md:308-357` ("Closing a task": one sentence under finish; one under the SessionEnd bullet: the autosave is pushed, so it is built on, never rewritten).
5. **Harness** (`plugin/lib/close.test.sh`; see `20-120`, `234-265`, `350-415`, `502-524`, `928-955`): `autosave_rewritten_cases` in `cases()`, both storages.
   - Repaired: ready, build, push; commit `b.txt` as `wip: session-end autosave [ID]`, push; `git reset --soft HEAD~1`, commit as `feat: b [ID]`; begin, outcome, finish: status 0, the old wip sha an ancestor of the remote branch, no "the push failed", one PR, last commit still the close commit, verify not `BLOCKED:unpushed`.
   - Refused: the same, but the rewrite changes a file: `check_refused` with the new message, sentinel armed, no PR, nothing moved.
   - Remote ahead: refused early.
   - Optional: stale tracking ref (autosave pushed from a second clone) proves the fetch.

Verification: `bash plugin/lib/close.test.sh`, `bash plugin/lib/session.test.sh`, `tools/lint.sh`.

Other ranges relied on: `plugin/lib/session.sh:290-327`, `plugin/lib/githooks.sh:13-14`, `plugin/lib/githooks.sh:470-573`, `plugin/commands/close.md:26-39`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
