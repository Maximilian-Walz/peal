---
plan: required
touches: [plugin/commands/setup.md, plugin/commands/commands.test.sh, docs/getting-started.md, docs/reference/cli.md, docs/reference/commands.md, plugin/lib/init.sh, plugin/lib/init.test.sh, plugin/lib/setup.test.sh]
milestone: m2
depends: [0030]
size: S
---

# 0058 — /peal:setup ends by pointing at /peal:next, once it exists

## Intent

When `/peal:next` exists, change `/peal:setup`'s ending to hand over to it instead of naming `/peal:setup <next>`:

- step 7: replace the "what exists for later" line with one pointing at `/peal:next` ("`/peal:next` suggests what to adopt next, when you want it"), without naming a stage or its description;
- step 1, "No argument, `tasks` already set up": say what is set up and point at `/peal:next` the same way;
- keep `/peal:setup <stage>` itself unchanged: `/peal:next` runs it on a yes.

This cannot start before `/peal:next` exists: task 0030, a task file, not an open issue.

## Scope

- `plugin/commands/setup.md`: the intro, step 1's "already set up" case and step 7 point at `/peal:next` instead of naming a next stage.
- The survey's `next` line removed (`plugin/lib/init.sh`, `plugin/lib/init.test.sh`, `docs/reference/cli.md`): nothing reads it.
- `docs/getting-started.md` and `docs/reference/commands.md` describe setup's new ending.
- Checks in `plugin/commands/commands.test.sh` and `plugin/lib/setup.test.sh`.

## Done when

- `plugin/commands/setup.md` step 7 points at `/peal:next` and no longer names `/peal:setup <next>` or the next stage's description.
- Step 1's "`tasks` already set up" case points at `/peal:next` the same way.
- Nothing else in `plugin/` or `docs/` tells the human to run `/peal:setup <next>` after a setup (`git grep 'setup <next>'` is empty); the survey's `next` line stays if `/peal:next` or anything else still reads it, and is removed otherwise.
- `docs/getting-started.md` updated: it describes the end of `/peal:setup` as it is after this task (0031 wrote it as it is today), and `tools/docs.test.sh` passes.
- A setup run on a scratch project ends by pointing at `/peal:next`, and `/peal:next` there suggests a stage that is not set up.

## Raw

Filed as issue #58 (https://github.com/Maximilian-Walz/peal/issues/58) from an idea a session had; its text is carried over into the sections above.

## Notes

Deferred 2026-09-28 after a claim: stale claim: its session stopped; given back so auto mode picks it up again

`/peal:setup` (`plugin/commands/setup.md`) names the next stage itself in two places:

- step 7 (Report): "what exists for later, without setting it up: `/peal:setup <next>`, with the next stage and in a few words what it brings" (`guardrails`, `milestones`, `belfry`), with `<next>` taken from `peal init --survey`'s `next` line;
- step 1, the case "No argument, `tasks` already set up": says that `/peal:setup <next>` sets up the next stage, and stops.

That is a fixed order of stages. `/peal:next` (task 0030, `tasks/backlog/0030-peal-next.md`, filed from #30, milestone m2) is planned to suggest the one next thing with the best evidence for this repository, across stages and the features within them, and to respect what the human declined (`declined:` in `.peal/config.yml`). Once it exists, setup naming a stage itself duplicates it and can contradict it (suggesting a stage the human declined, or not the one with the best evidence).

2026-09-29, the human's answers in planning:
- The survey's `next` line is removed in this task: once setup stops reading it, nothing does (`/peal:next` works out stages from the config).
- Done when #5 is proved by the harness checks plus one manual `/peal:setup` run on a scratch repo, recorded in the Outcome.
- Step 7 keeps the task's wording ("`/peal:next` suggests what to adopt next, when you want it"), with no hedge for `/peal:next` printing NONE, and the line is always included, even when every stage is set up.
- `docs/reference/commands.md`'s `/peal:setup` entry gets a short phrase pointing at `/peal:next`.
- Step 1's "already set up" case says the stages set up and where tasks live (files/issues) in one line, then the `/peal:next` pointer.
- The intro of `setup.md` ("the later ones are named at the end") is reworded to point at `/peal:next`.
- `git grep 'setup <next>'` is checked over `plugin/` and `docs/` only; `CHANGELOG.md` is left to the release.

## Plan

Approach:
1. `plugin/commands/setup.md`: the intro (11-13) says `/peal:next` suggests what to adopt later, when the human wants it; step 1 drops `next` from the survey keys (25); step 1's "No argument, `tasks` already set up" case (35-36) says in one line what is set up (stages and storage) and that `/peal:next` suggests what to adopt next, when you want it, and stops; step 7's "what exists for later" bullet (212-215) becomes the one line "`/peal:next` suggests what to adopt next, when you want it", always, with no stage name or description.
2. Remove the survey's `next` line: `plugin/lib/init.sh` (comment 510, `next=-` 530, loop 533-538, echo 541); its expectations in `plugin/lib/init.test.sh` (319, 389-394, 399-401); `docs/reference/cli.md:29-30` ("the stages set up and the next" becomes "the stages set up"). `PEAL_INIT_STAGES` stays (used elsewhere).
3. `docs/getting-started.md:33-34`: setup ends by saying what you can do now and that `/peal:next` suggests what to adopt next.
4. `docs/reference/commands.md:120`: "ends in five lines, pointing at `/peal:next` for what comes later".
5. `plugin/lib/setup.test.sh`, in `files()` after the tasks stage (83): the first line of `peal next` starts with `SUGGEST guardrails`, and `peal init --survey` prints no `^next ` line.
6. `plugin/commands/commands.test.sh` (next to 37-45): `setup.md` names `/peal:next` at least twice, and never contains `setup <next>`.

Verification: `plugin/lib/init.test.sh`, `plugin/lib/setup.test.sh`, `plugin/commands/commands.test.sh`, `plugin/lib/next.test.sh`, `plugin/lib/hostile.test.sh` and `tools/docs.test.sh` pass, and the project's full suite; `git grep 'setup <next>' -- plugin docs` is empty; one manual `/peal:setup` run on a scratch repo with the branch's plugin (`PEAL_ROOT=$PWD/plugin`) ends pointing at `/peal:next`, recorded in the Outcome.

Ranges:
- tasks/done/0030-peal-next.md:16-33
- plugin/commands/setup.md:6-43, 204-220
- plugin/commands/next.md:21-66, 75-78
- plugin/lib/next.sh:9-26, 294-299, 337-344, 379-401
- plugin/lib/init.sh:507-545
- plugin/lib/init.test.sh:308-403
- plugin/lib/setup.test.sh:18-100
- plugin/commands/commands.test.sh:37-45
- docs/getting-started.md:28-93
- docs/reference/cli.md:29-32
- docs/reference/commands.md:112-137
- docs/design.md:610-632
- tools/docs.test.sh:353-385
- plugin/bin/peal:83-86

---

## Outcome

