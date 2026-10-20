---
milestone: m3
plan: required
size: S
touches: [plugin/bin/peal, plugin/bin/peal.test.sh, plugin/lib/session.sh, docs/security.md, docs/reference/cli.md, docs/design.md]
---

# 0145 — Keep gh's telemetry off for the gh commands agents run from Peal's command markdown

## Intent

Task 0143 made `plugin/bin/peal` export `GH_TELEMETRY=0` (unless the user set it), so every gh Peal starts no longer posts gh's usage event to cafe.github.com. The gh commands an agent runs itself as the command markdown tells it to (`gh pr create` and `gh pr checks` in close.md, the gh calls in setup.md and next.md) do not go through `bin/peal`. They still send that event, and a network filter may deny it. Make those calls telemetry-free too: prefix them with `GH_TELEMETRY=0`, route them through peal subcommands, or accept the behaviour and document it.

## Scope

- Peal's SessionStart hook (`cmd_hook session-start` in `plugin/bin/peal`) appends the literal line `export GH_TELEMETRY="${GH_TELEMETRY:-0}"` to Claude Code's `CLAUDE_ENV_FILE` when that is set and the line is not there yet. It runs before `peal_session_start`, so it covers sessions outside a Peal project too (`/peal:setup`). It never fails the hook.
- Harness cases in `plugin/bin/peal.test.sh`.
- One sentence each in `docs/security.md` §"`gh` holds the token", the `peal hook session-start` entry of `docs/reference/cli.md` and the SessionStart bullet of `docs/design.md`.
- Command markdown unchanged, unless the headless check fails (see Notes).

## Done when

- The harness proves: running the hook twice appends the line exactly once and keeps what is already in the file; no `CLAUDE_ENV_FILE` means nothing written and exit 0; an unwritable `CLAUDE_ENV_FILE` exits 0; outside any repository the line is still written.
- Sourcing the file gives `GH_TELEMETRY=0` with the variable unset or empty and keeps a user's value (`log`).
- `bash plugin/commands/commands.test.sh` and `plugin/bin/peal.test.sh` pass.
- `docs/security.md` says which agent-run gh calls are covered (all, in a Claude Code session) and which are not (gh outside Claude Code is the user's own).

## Raw

> Run the gh commands agents issue from Peal's command markdown with gh's telemetry off. Found in 0143: plugin/bin/peal now exports GH_TELEMETRY=0 (unless set) for every gh Peal starts, but the gh calls an agent runs itself from plugin/commands/*.md (close.md's gh pr create / gh pr checks, setup.md, next.md) bypass bin/peal and still post gh's usage event to cafe.github.com, which a network filter may deny. Either prefix them with GH_TELEMETRY=0, route them through peal subcommands, or accept and document it.

## Notes

- Split off 0143, which is in m3; its Outcome has the evidence that cafe.github.com is gh's telemetry (gh 2.102.0).
- Open question: which of the three ways? A prefix in the markdown is cheap but easy to forget in new commands. Routing through peal keeps a single place.
- Context: `docs/security.md` §"`gh` holds the token".
- 2026-10-20, plan agreed with the human: the SessionStart hook writes the line to `CLAUDE_ENV_FILE` (hook only, no markdown prefixes); in every session where the plugin is enabled, not only Peal projects; if the implementer finds `CLAUDE_ENV_FILE` is not applied in headless sessions or subagents, it reports that and also adds `GH_TELEMETRY=0` prefixes to the markdown calls (close.md, setup.md, next.md) and the fallback printed at `plugin/lib/close.sh:593`. Defaults kept: literal line form (PowerShell then skips the env file; noted in the code); `close.sh:593` unchanged otherwise; `close.md`'s `gh pr checks` stays; no `GH_NO_UPDATE_NOTIFIER`. 0143 merged to main and was merged in before the build.

## Plan

Approach: in `cmd_hook` `session-start` (`plugin/bin/peal:393-400`), before `peal_record_root`/`peal_session_start`, call a small helper (in `plugin/bin/peal` or `plugin/lib/session.sh`) that, when `CLAUDE_ENV_FILE` is non-empty and the file does not already contain the exact line, appends `export GH_TELEMETRY="${GH_TELEMETRY:-0}"` (literal text: the hook itself runs under `bin/peal`, which already exported 0, so it cannot see the user's value; bash evaluates the literal in the session). Any error is swallowed (`|| true`, `2>/dev/null`). A comment names the PowerShell caveat.

The gh calls this covers: close.md:67-68 (`gh pr create --draft`, `gh pr checks`), setup.md:66-69 (issue sample `gh api`) and 206-208 (`gh pr create`), next.md:117-118 and 137-138 (`gh pr create`), the fallback printed by `plugin/lib/close.sh:590-594`, and gh calls an agent improvises. `gh auth login` (setup.md:77, 224) is the human's own terminal.

Headless check: the implementer checks whether the env file reaches Bash in a headless or subagent session (Claude Code sets `CLAUDE_ENV_FILE` only for hooks; the docs do not say whether headless sessions apply it). If it cannot be shown to work, it reports so and adds `GH_TELEMETRY=0` prefixes to the calls above.

Files: `plugin/bin/peal`, `plugin/lib/session.sh`, `plugin/bin/peal.test.sh`, `docs/security.md`, `docs/reference/cli.md`, `docs/design.md`.

Verification: harness cases per Done when, in `plugin/bin/peal.test.sh` (it already runs `hook session-start`, lines 25-37; the out-of-repo case near line 87); `bash plugin/commands/commands.test.sh`. Live check only after the merge (sessions run the installed plugin): a new session's `echo $GH_TELEMETRY` prints 0 and a sandboxed `gh pr checks` logs no deny for cafe.github.com; the Outcome says so.

Ranges: plugin/bin/peal:13-23, plugin/bin/peal:389-404, plugin/hooks/hooks.json:1-65, plugin/lib/session.sh:163-214, plugin/lib/close.sh:577-594, plugin/lib/git-guard.sh:20-28, plugin/commands/close.md:66-71, plugin/commands/close.md:142-189, plugin/commands/setup.md:63-77, plugin/commands/setup.md:201-224, plugin/commands/next.md:113-139, plugin/commands/release.md:75-77, plugin/commands/idea.md:130-143, plugin/commands/commands.test.sh:17-32, plugin/commands/commands.test.sh:43-44, plugin/bin/peal.test.sh:25-37, docs/security.md:303-314, docs/design.md:304-318, docs/reference/cli.md:132-143, docs/reference/cli.md:694-708, https://code.claude.com/docs/en/hooks (CLAUDE_ENV_FILE in SessionStart).

---

## Outcome

<!-- Written at close, replacing this comment. -->
