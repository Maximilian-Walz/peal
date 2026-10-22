---
plan: required
---

# 0212 — peal milestone-state prints no raw config-lock errors and says when the new milestone becomes current

## Intent

Run in a sandboxed session, `peal milestone-state m3 done --review FILE` printed git's raw `error: could not lock config file .../.git/config: File exists`. Task 0167 quieted those lines only for close's push and the read-only commands; milestone-state's push, and the main-write path it goes through, were left out. They should get the same quiet upstream handling close finish has (0101, 0167).

Its last line is misleading too. It read the state from main before the pull request had merged, so it said `current milestone: m3` just after printing `milestone m4: current`. When main takes writes through a pull request, the last line should say the new milestone becomes current once that pull request merges ("m4 becomes current once PR #N merges").

## Scope

## Done when

## Raw

> peal milestone-state prints no raw config-lock errors and says when the new milestone becomes current
>
> ## Intent
>
> In a sandboxed session, `peal milestone-state m3 done --review FILE` printed `error: could not lock config file .../.git/config: File exists`; 0167 quieted this only for close's push and the read-only commands. Its last line, read from main before the pull request merged, said `current milestone: m3` right after it had printed `milestone m4: current`.
>
> ## Scope
>
> - milestone-state's push (and the main-write path it uses) goes through the same quiet upstream handling as close finish (0101, 0167).
> - When main takes writes through a pull request, the last line says "m4 becomes current once PR #N merges".
>
> ## Done when
>
> - A locked-config harness case (copied from 0167's) shows no raw git lines from milestone-state.
> - A case asserts the last line names the pull request while it is still open.
>
> ## Notes
>
> - Related: 0169 (the same lock errors at hook install).

## Notes

- Related: 0169 (the same lock errors at hook install, `plugin/lib/githooks.sh`); 0167 (the quiet handling and its locked-config harness case to copy); 0101.
- Open question: other commands that write main through the same path (e.g. idea filing, retire, revise) may print the same raw lines; whether the fix belongs in the shared main-write path rather than in milestone-state alone is the planner's call.
- Context: `docs/reference/cli.md` (milestone-state's output).

---

## Outcome

<!-- Written at close, replacing this comment. -->
