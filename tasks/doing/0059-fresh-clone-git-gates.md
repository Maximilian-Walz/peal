---
plan: required
priority: high
touches: [plugin/hooks/hooks.json, plugin/lib/claim.sh, plugin/lib/claim.test.sh, plugin/lib/close.sh, plugin/lib/commit.sh, plugin/lib/githooks.sh, plugin/lib/session.sh, plugin/lib/session.test.sh]
milestone: m1
---

# 0059 — A fresh clone whose config records the guardrails stage gets its git gates without a manual step

## Intent

When the `guardrails` stage is recorded in the config and `peal_hooks_installed` fails, run `peal_hooks_install` at the start of the work instead of refusing at the end:

- In `peal_session_start`, install the hooks when the stage is recorded and they are missing, and add one line to the orientation (`installed Peal's git hooks in …`). This covers sessions that never claim.
- In `peal_claim`, do the same before the worktree is created, so a CLI-only claim is covered too.
- Leave `core.hooksPath` alone when it points at a path other than Peal's stubs and the stage is recorded, and keep `peal.projectHooks` chaining working. Whether to install on top of it (chaining, as `peal hooks install` already does) or only warn is for the implementer to decide and record. Never install in a project whose config does not record `guardrails`.
- If the install fails, say so up front in the orientation and in the claim output, with the exact command. Do not let the problem surface later at close.
- Update the sentence in `docs/design.md` and the "once per clone" line in `README.md` to match.

## Done when

- In a fresh clone with `guardrails` in `stages` and no `core.hooksPath`, `peal claim N` leaves `peal_hooks_installed` true, and `peal close begin` in that claim's worktree gets past the hooks check.
- The SessionStart hook in such a clone installs the hooks and names that in its output. A second session start installs nothing and prints nothing about hooks.
- A project without `guardrails` in `stages` gets no hooks from claim or session start.
- A clone whose `core.hooksPath` points elsewhere is handled as documented (chained, or warned about), and a harness case covers it.
- A failed install is reported at claim and session start with the command to run.
- `plugin/lib/claim.test.sh` and `plugin/lib/session.test.sh` cover the cases above. `docs/design.md` and `README.md` describe the new behaviour.

## Raw

Filed as issue #59 (https://github.com/Maximilian-Walz/peal/issues/59) from an idea a session had; its text is carried over into the sections above.

## Notes

`core.hooksPath` belongs to each clone, not to the repository. `docs/design.md` ("Setup", the end of the stages section) says so: "A `guardrails` stage recorded in the committed config says the project wants the hooks; `core.hooksPath` is each clone's own, so a fresh clone runs the stage again." Today nothing runs it for that clone:

- `plugin/lib/githooks.sh`: `peal_hooks_install` writes the stubs to `<git-common-dir>/peal/hooks`, sets `core.hooksPath`, and records the Peal root in `peal-root`. `peal_hooks_installed` checks the result. Worktrees share the common dir, so one install covers every claim worktree of the clone.
- `plugin/lib/close.sh` refuses `close begin` (line ~104) and `close finish` (line ~462) when `peal_hooks_installed` fails. `plugin/lib/commit.sh` (line ~53) refuses `peal commit` for the same reason. Each refusal says to run `peal hooks install`.
- `plugin/lib/claim.sh` (`peal_claim`) and `plugin/lib/session.sh` (`peal_session_start`, the SessionStart hook in `plugin/hooks/hooks.json`) never check the hooks.

So in a fresh clone of a project whose `.peal/config.yml` lists `guardrails` in `stages` (as this repository does), a session claims a task, works it, and only finds out at `/peal:close` or its first `peal commit` that the gates are missing. The README tells a human to run `.peal/peal hooks install` once per clone. An unattended worker (for example, a control plane's fresh clone of this repository) has no human to do that step, so the job stops mid-task.

Draft plan (2026-09-25, planner; **not agreed**. The session could not reach the human: AskUserQuestion timed out twice). It is for the next session to put to the human:

- A helper `peal_hooks_ensure` in `plugin/lib/githooks.sh`. It does nothing without `guardrails` in `stages` or when `peal_hooks_installed` succeeds. Otherwise it runs `peal_hooks_install` and prints its `installed Peal's git hooks in …` line. On failure it prints the reason and `.peal/peal hooks install`. It never fails its caller.
- It is called from `peal_session_start` (`plugin/lib/session.sh:98-136`), with the line right after `Peal:`, and once at the top of `peal_claim` (`plugin/lib/claim.sh:159-199`), before the worktree. Success goes to stdout before the path; warnings go to stderr.
- `close.sh:104-107,462-465` and `commit.sh:53-56` stay refusals and name `.peal/peal hooks install`. `hooks.json` needs no change.
- Docs: `docs/design.md` (930-932, 346-350, 328-338, 601-613) and `README.md:61`. Possibly also `docs/security.md:44-50`, `plugin/commands/setup.md:78-81`, and the usage text in `plugin/bin/peal` (88-90, 145-148). `CLAUDE.md:22` goes to an idea rather than an edit.
- Tests: about 11 cases, a `gates()` in each of `claim.test.sh` and `session.test.sh`, on a fresh clone with `stages: [tasks, guardrails]`:
  - the hooks get installed, and `close begin` gets past the hooks check;
  - a second run is silent;
  - a project without guardrails gets nothing;
  - a foreign `core.hooksPath`;
  - a forced failure (`<common>/peal` made a plain file).
- Size M, model default, merge default.

Open questions for the human (recommended default first):
1. A foreign `core.hooksPath`: warn only, with the chaining command, or chain automatically?
2. Close and commit: pure refusals naming `.peal/peal hooks install`, or should they also try the install themselves?
3. Docs outside the task: fix security.md, setup.md and the usage text, and file an idea for CLAUDE.md? Or fix all four, or only design.md and README?
4. Security: auto-install from a committed `stages` line, documented in security.md. Acceptable?

Minor defaults:
- the working tree's loaded config decides;
- the hooks are installed once, at the top of claim;
- warnings repeat on every session start;
- a stale path to Peal's own stubs is re-installed, while another Peal path counts as foreign.

---

## Outcome

