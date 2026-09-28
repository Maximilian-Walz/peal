---
plan: skipped
size: S
priority: high
milestone: m2
---

# 0079 — CLAUDE.md's "each clone installs the git gates once" line is now only the fallback

## Intent

`CLAUDE.md:22` says "Each clone installs the git gates once: `.peal/peal hooks install`."
Task 0059 gave `peal claim` and the `SessionStart` hook a `peal_hooks_ensure` step: a
fresh clone whose `.peal/config.yml` records the `guardrails` stage now installs its own
git gates automatically, at the first claim or session start, without a human running
anything. `.peal/peal hooks install` is still there, but only as the manual fallback (a
foreign `core.hooksPath` only warns rather than being overwritten; a failed automatic
install names the same command). The `CLAUDE.md` line should say what actually happens
now, not send every session to a step Peal itself already took.

## Scope

`CLAUDE.md` only (the "Each clone installs the git gates once" bullet).

## Done when

- The bullet describes the automatic install (`peal_hooks_ensure`, `plugin/lib/githooks.sh`,
  task 0059) as the normal path, and keeps `.peal/peal hooks install` as the fallback for
  a foreign `core.hooksPath` or a failed install.

## Raw

Filed from task 0059 ("A fresh clone whose config records the guardrails stage gets its
git gates without a manual step"). Its Notes, from the human's own answers: "Docs outside
the Intent: fix docs/security.md, plugin/commands/setup.md and the usage text in
plugin/bin/peal here. File an idea for the CLAUDE.md rule ('Each clone installs the git
gates once') rather than editing it."

## Notes

Revised 2026-09-28: priority high: goes into Peal's next patch release (daily-use fixes after m1)

None beyond the Raw section.

---

## Outcome

Rewrote the `CLAUDE.md` bullet that said "Each clone installs the git gates once:
`.peal/peal hooks install`." It now says a fresh clone installs its git gates itself, at
the first `peal claim` or session start (`peal_hooks_ensure` in `plugin/lib/githooks.sh`,
task 0059), and that `.peal/peal hooks install` is the fallback for a foreign
`core.hooksPath` or a failed automatic install. The wording follows the already-accurate
phrasing in README.md and docs/security.md, and was checked against `peal_hooks_ensure`:
it runs only when the config records the `guardrails` stage (Peal's own config does), it
warns instead of overwriting a foreign `core.hooksPath`, and both failure messages name
`.peal/peal hooks install`.

The review found nothing. No ideas were filed; the next session needs nothing from this one.
