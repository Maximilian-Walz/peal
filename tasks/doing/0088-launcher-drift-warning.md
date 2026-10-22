---
plan: required
milestone: m4
size: S
touches: [plugin/lib/session.sh, plugin/lib/session.test.sh, plugin/lib/doctor.sh, docs/security.md, docs/reference/cli.md, docs/design.md]
---

# 0088 — Warn when the committed launcher differs from the installed one

## Intent

The committed `.peal/peal` is repository content: a branch can replace it, and whatever
runs it (a session, a control plane's contract) then runs the branch's script. No check
inside the launcher can guard against its own replacement. Peal could warn, e.g. at
SessionStart or in `peal check`, when `.peal/peal` differs from the installed plugin's
`templates/launcher`. Filed from 0040's planning, where the human chose to record the
limit in `docs/security.md` and file this.

## Scope

- A SessionStart warning (stdout, every source) when the committed `.peal/peal` is not
  byte-identical to the running Peal's `templates/launcher`; silent when it matches or
  is missing.
- One shared helper, `peal_launcher_matches`, used by the hook and by `peal doctor
  version` (doctor's behaviour unchanged).
- `docs/security.md`, `docs/reference/cli.md`, `docs/design.md` updated.
- Not in scope: a `peal check` or `commit-msg` refusal; 0111's CI comparison.

## Done when

- SessionStart's orientation carries a `Launcher:` line when `.peal/peal` differs from the
  running Peal's template, and none when it matches or is missing; the hook still exits 0.
- `peal doctor version` behaves as before.
- `docs/security.md` says so, keeps the limit for hand runs and Belfry's contract, and
  names the harness (`plugin/lib/session.test.sh`).

## Raw

> A9: The committed launcher .peal/peal is itself repository content: a PR can replace it, and Belfry's contract runs it. No check inside the launcher can protect against that. — "Record limit + idea": record the limit in docs/security.md and file an idea for a warning when .peal/peal differs from the installed template.

## Notes

- Open: where the warning lives (SessionStart, `peal check`, or both), and whether a
  `commit-msg` refusal of a change to `.peal/peal` outside `chore(peal)` is wanted too.
- Context: `docs/design.md` (Distribution).
- Queued in 0040's Outcome (2026-09-25) as "not yet filed" pending a protected-main
  filing path; filed now by the m1 milestone review (0045), which found it never was.
- Human's answers (2026-10-22, planning): SessionStart only, no `peal check` warning;
  no `commit-msg` refusal (record it as rejected in the Outcome); compare against the
  installed template only, one line naming both causes; the line tells the session to
  report to the human, not refresh the launcher; accept the warning noise in Peal's own
  repository between a template change and its release; show it on every SessionStart
  source; doctor's inline `cmp` moves onto the shared helper; 0111 stays its own task;
  a session-only warning meets m4, with `docs/security.md` saying plainly that Belfry's
  contract path stays uncovered; silent when `.peal/peal` is missing.

## Plan

Approach: add `peal_launcher_matches` to `plugin/lib/session.sh` (0 when `.peal/peal`
is byte-identical to `$PEAL_ROOT/templates/launcher`, 1 when it differs, 2 when there is
no `.peal/peal`). `_peal_doctor_stage_version` uses it in place of its inline `cmp`.
`peal_session_start` prints, after the hooks line, on stdout and on every source, one line
when it returns 1, e.g.:

  `Launcher: .peal/peal differs from the installed Peal's launcher (vX.Y.Z). A branch may
  have changed it, or it is older than the plugin; tell the human. Refreshing it is
  .peal/peal init --stage tasks and a commit of its own.`

Nothing when it matches or is missing. Docs: `docs/security.md` rewrites the committed
launcher limit (still a limit for a hand run and Belfry's contract; now reported at
SessionStart and by `peal doctor version`; guard and harness named);
`docs/reference/cli.md` the `peal hook session-start` paragraph; `docs/design.md` one
sentence in Distribution.

Rejected: a `peal check` refusal (would fail closes of template-refreshing tasks and every
close after an upgrade; in CI it compares against the branch's template, 0111's job); a
`commit-msg` refusal (runs on the branch judged, invents a commit-type convention, misses
clones without hooks).

Files: `plugin/lib/session.sh`, `plugin/lib/session.test.sh`, `plugin/lib/doctor.sh`,
`docs/security.md`, `docs/reference/cli.md`, `docs/design.md`.

Verification: new `launcher` case in `plugin/lib/session.test.sh` through `hook_stdout`:
(a) launcher copied from the template and committed: no `Launcher:` line; (b) one byte
appended: the line, hook exits 0; (c) no `.peal/peal`: no line; (d) `resume` source shows
it. Existing `orientation` case, `plugin/lib/doctor.test.sh` version cases (incl. line
224), `tools/docs.test.sh` and `tools/lint.sh` pass.

Ranges: tasks/backlog/0111-ci-launcher-template-check.md:1-28, docs/milestones/m4.md:1-20,
docs/security.md:28-95, docs/design.md:368-370, docs/design.md:647-668,
docs/design.md:697-706, docs/reference/cli.md:64-92, docs/reference/cli.md:138-146,
plugin/lib/session.sh:133-229, plugin/lib/doctor.sh:116-155,
plugin/lib/doctor.test.sh:224, plugin/lib/session.test.sh:17-84, plugin/bin/peal:358-368,
plugin/templates/launcher:1-23, tools/lint.sh:36-37.

---

## Outcome

<!-- Written at close, replacing this comment. -->
