---
plan: skipped
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/commands/close.md]
---

# 0261 — close finish under a sandboxed control plane: the session pushes the close commit, finish goes on

## Intent

Under a control plane whose sandbox lets only the session's own standalone `git push` reach the remote, the push of the task branch inside `peal close finish` (`plugin/lib/close.sh`) runs from a script and fails. Finish already skips its push when the remote ref is at HEAD, but finish makes the close commit itself, so the tip can never have been pushed beforehand: today the session sees the raw push error, pushes by hand and runs finish again.

Give finish a flag in the line of `--pr-by-tool` and `--ideas-by-tool` that makes the close commit and stops before the push, or stops with one clear line naming the push to run instead of the raw push error. `close.md` then has the session push the branch itself and run finish again, which goes on from the already-pushed tip.

## Scope

## Done when

## Raw

> `close finish` under a sandboxed control plane: the session pushes the close commit, finish goes on
>
> ## Intent
>
> Under a control plane whose sandbox lets only the session's own standalone `git push` reach the remote, the push of the task branch in `peal close finish` (`plugin/lib/close.sh`) runs inside a script and fails. Finish already skips its push when the remote ref is at HEAD, but finish makes the close commit itself, so the tip is never pushed beforehand. Today the session has to push after the failure and run finish again.
>
> Give finish a flag, like `--pr-by-tool` and `--ideas-by-tool`, that commits and stops before the push, or stops with one clear line instead of the raw push error. `close.md` then has the session push the branch itself and run finish again.
>
> ## Done when
>
> - A `close.test.sh` case with a remote finish cannot push to succeeds once the session has pushed the branch, with no raw push error printed on the way.
> - `close.md` names the step.

## Notes

- Open question: a new flag (commit, print the push command, stop) or no flag at all (detect the failing push and replace its error by one line)? The idea allows either; a flag keeps the behaviour explicit, like the other `--*-by-tool` flags.
- Open question: should the second finish run need the flag too, and should the stop leave a marker so a second run knows the commit is already made (finish must not make a second close commit)?
- The current failure message is at `close.sh` "the push failed (above): the close is committed here, not on $PEAL_REMOTE"; the skip when the remote ref is at HEAD is just above it.
- `docs/design.md` and `docs/reference/cli.md` (the `close finish` flags) bear on it.

---

## Outcome

<!-- Written at close, replacing this comment. -->
