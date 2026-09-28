---
milestone: m2
plan: required
size: M
touches: [plugin/lib/next.sh, plugin/lib/next.test.sh, plugin/commands/next.md, plugin/commands/commands.test.sh, plugin/bin/peal, plugin/lib/config-defaults.yml, plugin/lib/session.sh, plugin/lib/session.test.sh, docs/design.md, README.md]
---

# 0030 — /peal:next: what to adopt next

## Intent

After `/peal:setup` a project uses a small part of Peal. Nobody reads all the docs
first, so the rest should find the user when it would help, one thing at a time, with the
evidence for it, and never by changing things unasked.

## Scope

- `/peal:next` reads the project's state: stages set up (`.peal/config.yml`), the
  backlog and its history (tasks done, splits, deferrals), milestones, git history,
  whether Belfry is configured.
- It suggests **one** next thing, the one with the best evidence, in a few lines: what it
  is, why this repository would profit ("12 tasks closed and no milestones: milestones
  would let you and Belfry's auto mode work the important ones first"), and how to try it
  (`/peal:setup milestones`). It lists up to three runners-up in one line each.
- It knows the stages of `peal init` (tasks, guardrails, milestones, belfry) and the
  milestone review task, each with a short check of whether it would help here. The
  features within the stages (decisions, drift, releases, the reviewer's settings) are
  split into 0097.
- The user can accept (it runs the setup step), decline (recorded under `declined:` in
  `.peal/config.yml`, with the date, and not suggested again for 90 days unless asked),
  or ask for more.
- It never changes anything without an explicit yes.
- The SessionStart orientation gets a one-line hint when `peal next` has a suggestion.

## Done when

- Harnesses cover the `declined:` bookkeeping. (`peal doctor` is 0036.)
- On two scratch projects in different states, `/peal:next` suggests different, fitting
  next steps, and none after everything this task knows is set up.
- Harnesses cover the SessionStart hint: shown on startup/clear outside a task's
  worktree, silent otherwise, and no extra `gh` calls.

## Raw

Filed as issue #30 (https://github.com/Maximilian-Walz/peal/issues/30), "/peal:next and peal doctor: what to adopt next, and what is
broken"; its text is carried over into the sections above.

## Notes

Revised 2026-09-28: split: 0097 holds the rest

Split: the features within the stages (decisions, drift, releases, reviewer settings)
are 0097, part-of 0030.

The human's answers while planning (2026-09-28):

- `declined:` is a map of one-item lists: `declined: {milestones: [2026-09-28]}`;
  `config-merge.awk` stays untouched.
- Catalogue thresholds as drafted: guardrails when tasks are done or main has commits
  without `[ID]`; milestones at >=10 done or >=8 open; review-task when the current
  milestone has none; belfry at >=5 done. Splits and deferrals are facts only.
- A decline expires from day 90 inclusive, UTC dates.
- An unknown declined item warns and is ignored; a malformed date is refused (status 2).
- `/peal:next all` (`peal next --all`) shows declined items; `/peal:next <item>` offers
  that item regardless.
- A decline is committed like setup: on main, branch `peal/next-decline-<item>` with
  `chore(peal): decline <item>`, then offer push and PR; elsewhere on the branch.
- No config yet: `SUGGEST tasks /peal:setup` only; decline refused.
- SessionStart hint: yes, in this task.
- Issues storage: facts through the storage, done count capped at what `list` returns,
  deferrals for files only; one `fake-gh` case.
- Runners-up: always, up to three `ALSO` lines.
- Ranking: fixed order, the stages in `peal init` order, then review-task.
- No Belfry action; `.belfry.yml` unchanged.
- `peal next` is independent of `peal init --survey`.
- Names: `peal next`; items `tasks guardrails milestones review-task belfry` (0097 adds
  `decisions drift releases reviewer`).
- Hint: no `BELFRY_SESSION` check, worded as information for the human; shown also when
  the config records no `stages:`; only on `startup`/`clear`; an engine error drops the
  hint silently.

- At close (2026-09-28), the human settled the ranking: guardrails, milestones, belfry,
  review-task (the `peal init` order, then review-task), overriding the Plan's catalogue
  paragraph and its state B example. State A (`stages: [tasks]`, 12 done) therefore
  suggests guardrails with milestones as a runner-up; the Plan's `SUGGEST milestones`
  there was inconsistent with any fixed order.

## Plan

**Engine, `plugin/lib/next.sh`.** A pure core takes the storage's list records
(store.sh:8-17 format), the milestone lines from `peal_store_milestones` and the loaded
config (`stages`, `declined`, `storage.kind`), applies the catalogue in fixed order and
prints `SUGGEST <item> <try> <evidence>`, up to three `ALSO` lines, `DECLINED <item>
<date>` lines, or `NONE`. Catalogue: `tasks` (no `stages`: only `SUGGEST tasks
/peal:setup`); `guardrails` (not recorded, and tasks done or non-merge commits on main
without `[ID]`, counted with one local `git log -n 200 --first-parent` of the configured
main, no fetch); `milestones` (not recorded, >=10 done or >=8 open); `review-task` (a
current milestone and no record with that milestone and `milestone` in its depends);
`belfry` (not recorded, >=5 done). Evidence holds counts and ids only, never stored text.
Declines block an item while fewer than 90 days have passed (UTC civil-date arithmetic in
awk, today from `PEAL_TODAY` when set); unknown items warn and are ignored; a malformed
date is status 2 naming the line.

CLI: `peal next [--all | ITEM]` gathers the facts itself (`peal_store_list --no-pr`,
milestones, the git log) then runs the core. `peal next --decline ITEM` validates ITEM
and rewrites the `declined` block through `config-block.awk` as `_peal_init_record` does
(init.sh:116-140); a repeat refreshes the date, never a second entry; refused without
`.peal/config.yml`. `config-defaults.yml` gets `declined: {}` (open map, list children
admitted, config-merge.awk:49-56).

**Command, `plugin/commands/next.md`.** Runs `peal next`, presents the suggestion and the
`ALSO` lines, asks one `AskUserQuestion`: try it / not for this project / tell me more.
Yes runs `/peal:setup <stage>` (`review-task`: `/peal:setup milestones`, whose step 3
offers it, setup.md:106-113). Decline runs `peal next --decline ITEM` and commits as setup
does (setup.md:43-52, 192-200; the `chore(peal)` gate allows `.peal/`,
githooks.sh:361-364). Arguments `all` and `<item>`. Carries the text-from-others
paragraph (commands.test.sh:84-103).

**SessionStart hint.** `peal_session_start` (session.sh:94-140, hook at
hooks.json:4-13, bin/peal:326-333) already holds `records` (session.sh:119), `milestones`
(session.sh:120) and the config (session.sh:62-70); the hint runs the core on those, no
second list, no fetch, no `gh`. Only for `startup`/`clear` (session.sh:107-118) and only
when `$task` is empty. One line, last, after the open splits; the early `return 0` at
session.sh:133 becomes a guarded block so the hint still prints with no records. Text:
`Next to adopt: <item>, <evidence>. For the human: /peal:next says more; nothing changes
unasked.` Silent for `NONE`, declined items and any engine error (the hook never fails a
session, session.sh:49-50).

**Docs.** design.md: a `/peal:next` subsection under "Setting up a project", `declined:`
in the Configuration defaults (528-566), the hint in the SessionStart bullet (367-377) and
the orientation row (220). README: status paragraph and command list.

**Verification.** `plugin/lib/next.test.sh`, scratch repositories with task-fixtures and
`PEAL_TODAY` pinned: state A (`stages: [tasks]`, 12 done, no milestones) gives `SUGGEST
milestones` with 12 in the evidence and `ALSO guardrails`; state B (tasks, guardrails,
milestones; current milestone without a review task; no belfry) gives `SUGGEST
review-task`, `ALSO belfry`; state C (all four stages, review task present) gives `NONE`,
status 0; no config gives only `SUGGEST tasks /peal:setup` and `--decline` refused.
Declined: `--decline milestones` writes `milestones: [<today>]`, rest of the config byte
for byte, `peal config` still loads; skipped at day 89, suggested at day 90, shown with
`--all` and `peal next milestones`; repeat decline keeps one entry; a second item keeps
the first; `--decline bogus` status 2, no change; unknown item warns; malformed date
status 2 with the line. One issues case through `fake-gh` when `jq` is present.
`plugin/lib/session.test.sh` (next to session.test.sh:52-82, `hook_stdout` 23-30): state
A main checkout `startup` ends with the hint naming milestones; `resume` no hint; a task
worktree no hint and the exact orientation check still passes; milestones declined names
guardrails; state C no hint; malformed date no hint, status 0, orientation unchanged;
issues through `fake-gh`: the same number of `gh` calls with and without the hint.
`commands.test.sh`: `next.md` exists (frontmatter, `$ARGUMENTS`, subcommands, the
paragraph). By hand: `/peal:next` with `PEAL_ROOT=$PWD/plugin` on scratch states A and B
(different suggestions) and C (none), recorded in the Outcome.

Size M. Model default. Merge default.

Ranges: tasks/doing/0030-peal-next.md; docs/design.md:111-116, 220, 367-377, 528-566,
975-979; plugin/lib/session.sh:49-70, 94-140; plugin/lib/session.test.sh:15-82;
plugin/hooks/hooks.json:4-13; plugin/bin/peal:63-80, 326-341, 391-452;
plugin/lib/store.sh:8-17; plugin/lib/init.sh:116-140; plugin/lib/config-block.awk:1-49;
plugin/lib/config-defaults.yml:1-45; plugin/lib/config-merge.awk:49-56;
plugin/lib/githooks.sh:361-364; plugin/commands/setup.md:43-52, 106-113, 192-200;
plugin/commands/commands.test.sh:17-44, 84-103; plugin/lib/init.test.sh:1-48;
.peal/config.yml:5-11.

---

## Outcome

