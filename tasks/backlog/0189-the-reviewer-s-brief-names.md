---
plan: auto
size: S
depends: []
touches: [plugin/lib/work.sh, plugin/agents/reviewer.md, plugin/lib/close.sh, tools/lint.sh, .peal/config.yml]
milestone: m7
priority: low
---

# 0189 — The reviewer's brief names the last milestone review, and close finish runs shellcheck only on the files the diff changed

## Intent

Two small savings found by the performance review. (a) The reviewer spends a third of its turns locating the last milestone review for the "repeat rot" check (`plugin/agents/reviewer.md`: find the last done milestone, its review task, read its Outcome): across 103 reviews it ran `peal milestones` 79 times, `peal board` 36 times and `peal read` 12 times, about 2.5 minutes per review; and 173 harness runs against its one-test rule. `peal brief reviewer` (`plugin/lib/work.sh`) should print the last milestone review's Outcome section. (b) `peal close finish` runs `checks.close` (`tools/lint.sh`), which runs shellcheck over about 100 scripts (48 seconds locally, 42 seconds median in finish, 59 minutes over 103 closes) for a diff that is often docs-only, while CI runs the same shellcheck job anyway. Give `checks.close` the `PATH...: COMMAND` form `checks.commit` already has (`plugin/lib/githooks.sh`), or have `tools/lint.sh` shellcheck only the changed paths when given a base.

## Scope

- `peal brief reviewer` prints the last milestone review's Outcome, and `reviewer.md` names it so no lookup is needed.
- `close finish`'s checks run shellcheck on changed files only (path-scoped `checks.close` entries, or `tools/lint.sh BASE`); CI keeps the full run.

## Done when

- A test: the reviewer's brief holds the Outcome of the last done milestone's review task.
- A test: `close finish` on a docs-only diff does not run shellcheck; on a changed `*.sh` it runs it on that file.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Performance review findings 5 and 6.
- Security: none; `checks.close` is still read from main's tip (`docs/security.md`), keep that.

---

## Outcome

<!-- Written at close, replacing this comment. -->
