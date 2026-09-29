---
plan: skipped
touches: [.peal/peal]
milestone: m2
---

# 0098 — Refresh this repository's committed launcher and hook stubs

## Intent

This repository's committed `.peal/peal` has fallen behind `plugin/templates/launcher`:
`peal doctor version` no longer finds it byte-identical. Regenerate it with
`.peal/peal init --stage tasks` and commit the result. Check the installed git hook stubs
against `plugin/templates/githook` the same way (`peal doctor hooks`), and refresh them
if they differ.

## Scope

- `.peal/peal` regenerated from `plugin/templates/launcher` with `peal init --stage tasks`.
- The per-clone git hook stubs checked with `peal doctor hooks`; nothing of them is committed.

## Done when

- `cmp .peal/peal plugin/templates/launcher` finds them identical, and the branch's
  `peal doctor version` reports the launcher ok.
- The Outcome says what, if anything, refreshing the hook stubs needs.

## Raw

> Refresh this repository's committed .peal/peal launcher: `peal doctor version` finds it no longer byte-identical to plugin/templates/launcher (found by 0036's smoke run). Run `.peal/peal init --stage tasks` and commit the result; check the installed hook stubs the same way.

## Notes

- Found by task 0036's smoke run (`PEAL_ROOT=$PWD/plugin plugin/bin/peal doctor`).
- Open question: the hook stubs are installed per clone, not committed, so refreshing them
  is `.peal/peal hooks install` on each machine; is there anything to commit there at all?
- Open question: should CI run `peal doctor version` so the committed launcher cannot fall
  behind the template again?

---

## Outcome

Built: `.peal/peal` regenerated with the branch's CLI (`PEAL_ROOT=$PWD/plugin
plugin/bin/peal init --stage tasks`). `cmp .peal/peal plugin/templates/launcher` finds them
identical, and the branch's `peal doctor version` now reports the launcher ok (it
reported FAIL before).

Hook stubs: `peal doctor hooks` in this clone reports every stub stale. They are
installed per clone, not committed, so there is nothing to commit; the fix is
`.peal/peal hooks install` on each machine, run from `main` after this merges. It was not
run from this worktree: the hooks directory is shared with the main checkout and the other
worktrees, and installing from a branch would change the gates other sessions run under.

Left:
- CI does not check the launcher against its template yet: filed as an idea
  (ci-launcher-template-check, plan required: plain `cmp` step or a launcher-only
  doctor mode is its open question).
- The branch's `peal doctor` still reports FAIL for the installed plugin version (0.1.0
  installed, 0.2.0 on the branch; clears when the plugin is reinstalled from main) and
  for `belfry.list`, `belfry.board` and `belfry.offer`, which this task did not look into.
  Re-run `peal doctor` after the merge and the reinstall.
