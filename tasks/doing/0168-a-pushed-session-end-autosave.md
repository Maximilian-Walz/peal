---
milestone: m3
plan: required
---

# 0168 — A pushed session-end autosave is never rewritten, so close finish's push is not refused

## Intent

The SessionEnd hook (`plugin/lib/session.sh`) commits a session's uncommitted work as `wip: session-end autosave [ID]` and pushes it to origin. When a later session's implementer soft-resets or amends that autosave into proper commits, the local branch no longer contains the pushed tip, and `peal close finish`'s push is refused as non-fast-forward. One session got past it by hand with `git merge -s ours` of the remote autosave (its tree matched) and ran finish again.

The aim is that this no longer happens, or no longer stops close: either the implementer brief forbids rewriting a pushed autosave (keep it, build on it), or finish recognises a remote tip whose tree matches a local ancestor and reconciles it with an `ours` merge, which loses nothing, or names the one command that does. Either way a harness case covers an autosave pushed and then rewritten locally.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
