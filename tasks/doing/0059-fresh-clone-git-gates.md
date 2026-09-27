---
plan: required
priority: high
touches: [plugin/lib/githooks.sh, plugin/lib/session.sh, plugin/lib/session.test.sh, plugin/lib/claim.sh, plugin/lib/claim.test.sh, plugin/lib/close.sh, plugin/lib/commit.sh, docs/design.md, README.md, docs/security.md, plugin/commands/setup.md, plugin/bin/peal]
milestone: m1
size: M
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
- A clone whose `core.hooksPath` points elsewhere gets a warning naming `.peal/peal hooks install`, and its `core.hooksPath` is left unchanged. A harness case covers it.
- A failed install is reported at claim and session start with the command to run.
- `plugin/lib/claim.test.sh` and `plugin/lib/session.test.sh` cover the cases above. `docs/design.md`, `README.md`, `docs/security.md`, `plugin/commands/setup.md` and the usage text in `plugin/bin/peal` describe the new behaviour.

## Raw

Filed as issue #59 (https://github.com/Maximilian-Walz/peal/issues/59) from an idea a session had; its text is carried over into the sections above.

## Notes

`core.hooksPath` belongs to each clone, not to the repository. `docs/design.md` ("Setup", the end of the stages section) says so: "A `guardrails` stage recorded in the committed config says the project wants the hooks; `core.hooksPath` is each clone's own, so a fresh clone runs the stage again." Today nothing runs it for that clone:

- `plugin/lib/githooks.sh`: `peal_hooks_install` writes the stubs to `<git-common-dir>/peal/hooks`, sets `core.hooksPath`, and records the Peal root in `peal-root`. `peal_hooks_installed` checks the result. Worktrees share the common dir, so one install covers every claim worktree of the clone.
- `plugin/lib/close.sh` refuses `close begin` (line ~104) and `close finish` (line ~462) when `peal_hooks_installed` fails. `plugin/lib/commit.sh` (line ~53) refuses `peal commit` for the same reason. Each refusal says to run `peal hooks install`.
- `plugin/lib/claim.sh` (`peal_claim`) and `plugin/lib/session.sh` (`peal_session_start`, the SessionStart hook in `plugin/hooks/hooks.json`) never check the hooks.

So in a fresh clone of a project whose `.peal/config.yml` lists `guardrails` in `stages` (as this repository does), a session claims a task, works it, and only finds out at `/peal:close` or its first `peal commit` that the gates are missing. The README tells a human to run `.peal/peal hooks install` once per clone. An unattended worker (for example, a control plane's fresh clone of this repository) has no human to do that step, so the job stops mid-task.

The human agreed the plan below on 2026-09-27. The session that agreed it could not record it: its sandbox failed to start, so no command ran. The next session commits this file with `peal record 0059 plan < tasks/doing/0059-fresh-clone-git-gates.md`, which sets `plan: agreed`, and builds. It does not plan again.

The human's answers (2026-09-27):
- A foreign `core.hooksPath`: warn only, naming `.peal/peal hooks install` (which chains). The automatic install never rewrites it. The decision is recorded in `docs/design.md` (Git gates) and in the Outcome.
- The command: `.peal/peal hooks install` everywhere. Close and commit stay pure refusals, as the backstop.
- Docs outside the Intent: fix `docs/security.md`, `plugin/commands/setup.md` and the usage text in `plugin/bin/peal` here. File an idea for the `CLAUDE.md` rule ("Each clone installs the git gates once") rather than editing it.
- Security: auto-install from a committed `stages` line is accepted, and documented in `docs/security.md`.
- Minor defaults accepted:
  - the config loaded in the current checkout decides;
  - the hooks are installed once, at the top of `peal_claim`;
  - warning and failure lines repeat on every session start until fixed;
  - a stale path to Peal's own stubs is re-installed, while another Peal hooks path counts as foreign;
  - claim prints success on stdout (before the path) and warnings and failures on stderr;
  - `hooks.json` is unchanged.

## Plan

Agreed 2026-09-27. Size M, model default, merge default.

- `plugin/lib/githooks.sh`: a new `peal_hooks_ensure`, run after the config is loaded.
  - It returns silently when `peal_config_get stages` has no `guardrails` line, or when `peal_hooks_installed` succeeds.
  - When `core.hooksPath` is set and differs from `_peal_hooks_dir`, it prints one warning and installs nothing: `Peal's git hooks are not installed: core.hooksPath is <path>; to install them chained to it, run: .peal/peal hooks install`.
  - Otherwise it runs `peal_hooks_install` and passes on its `installed Peal's git hooks in …` line.
  - On failure it prints `Peal's git hooks could not be installed (<reason>); run: .peal/peal hooks install`.
  - It always returns 0.
- `plugin/lib/session.sh` (`peal_session_start`, 98-136): calls it after `peal_hook_project` and `peal_store_load`, and puts its line directly after `Peal:`.
- `plugin/lib/claim.sh` (`peal_claim`, 159-199): calls it once, after argument validation and before `_peal_claim_one` or the `--next` loop. Success goes to stdout before the path, so `--print-path` still ends with the path. Warnings and failures go to stderr. The header comment is updated.
- `plugin/lib/close.sh` (104-107, 462-465) and `plugin/lib/commit.sh` (53-56): the remedy text becomes `.peal/peal hooks install`.
- Docs:
  - `docs/design.md` (328-338 claim, 346-350 SessionStart, 601-613 Git gates with the warn-not-chain decision, 930-932 fresh clone);
  - `README.md:61`;
  - `docs/security.md:44-50` (a committed `stages` line makes Peal set `core.hooksPath` in the clone);
  - `plugin/commands/setup.md:78-81`;
  - `plugin/bin/peal` usage (88-90, 145-148).
- Also: file a `/peal:idea` for `CLAUDE.md:22`.

Verification. The fixture is `repo()` from `task-fixtures.sh` plus a committed `.peal/config.yml` with `stages: [tasks, guardrails]`, published, then a fresh `git clone` of `remote.git` with no `core.hooksPath`.
- `plugin/lib/claim.test.sh`, a new `gates()`:
  - `claim --print-path` installs the hooks: the install line is printed, the last line is still the worktree, and `core.hooksPath` is `<common>/peal/hooks` with executable `commit-msg` and `pre-push`;
  - `close begin` in that worktree is not refused with "hooks are not installed";
  - a second claim prints no hooks line;
  - without `guardrails`, `core.hooksPath` stays unset and there is no line;
  - `core.hooksPath=custom-hooks` gets the warning with the command and is left unchanged;
  - a forced failure (`<common>/peal` made a plain file) still claims and names the command.
- `plugin/lib/session.test.sh`, a new `gates()`:
  - the first `hook session-start` installs the hooks and prints the line after `Peal:`;
  - a second start prints the same as an already-installed clone, with no hooks line;
  - without `guardrails`, nothing;
  - a foreign path gets the warning;
  - a failure prints the line with the command and exits 0.
- Then the full `bash plugin/lib/*.test.sh` and `tools/lint.sh`.

Ranges relied on:
- plugin/lib/githooks.sh:15-83, 341-351
- plugin/lib/session.sh:94-136
- plugin/lib/claim.sh:153-253
- plugin/lib/close.sh:88-107, 462-465
- plugin/lib/commit.sh:1-56
- plugin/lib/work.sh:31-46
- plugin/lib/init.sh:102-114, 331-339
- plugin/bin/peal:88-90, 145-148, 297-301, 372-381
- plugin/hooks/hooks.json:1-65
- plugin/lib/session.test.sh:1-63, 137-144
- plugin/lib/claim.test.sh:1-31
- plugin/lib/task-fixtures.sh:12-72
- plugin/lib/test-lib.sh:1-60
- docs/design.md:328-350, 599-613, 895-932
- docs/security.md:30-55
- README.md:56-63
- plugin/commands/setup.md:76-81
- .peal/config.yml:1-13
- CLAUDE.md:22

---

## Outcome

