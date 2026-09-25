---
plan: required
---

# 0058 — /peal:setup ends by pointing at /peal:next, once it exists

## Intent

When `/peal:next` exists, change `/peal:setup`'s ending to hand over to it instead of naming `/peal:setup <next>`:

- step 7: replace the "what exists for later" line with one pointing at `/peal:next` ("`/peal:next` suggests what to adopt next, when you want it"), without naming a stage or its description;
- step 1, "No argument, `tasks` already set up": say what is set up and point at `/peal:next` the same way;
- keep `/peal:setup <stage>` itself unchanged: `/peal:next` runs it on a yes.

This cannot start before `/peal:next` exists: task 0030, a task file, not an open issue.

## Done when

- `plugin/commands/setup.md` step 7 points at `/peal:next` and no longer names `/peal:setup <next>` or the next stage's description.
- Step 1's "`tasks` already set up" case points at `/peal:next` the same way.
- Nothing else in `plugin/` or `docs/` tells the human to run `/peal:setup <next>` after a setup (`git grep 'setup <next>'` is empty); the survey's `next` line stays if `/peal:next` or anything else still reads it, and is removed otherwise.
- A setup run on a scratch project ends by pointing at `/peal:next`, and `/peal:next` there suggests a stage that is not set up.

## Raw

Filed as issue #58 (https://github.com/Maximilian-Walz/peal/issues/58) from an idea a session had; its text is carried over into the sections above.

## Notes

`/peal:setup` (`plugin/commands/setup.md`) names the next stage itself in two places:

- step 7 (Report): "what exists for later, without setting it up: `/peal:setup <next>`, with the next stage and in a few words what it brings" (`guardrails`, `milestones`, `belfry`), with `<next>` taken from `peal init --survey`'s `next` line;
- step 1, the case "No argument, `tasks` already set up": says that `/peal:setup <next>` sets up the next stage, and stops.

That is a fixed order of stages. `/peal:next` (task 0030, `tasks/backlog/0030-peal-next.md`, filed from #30, milestone m2) is planned to suggest the one next thing with the best evidence for this repository, across stages and the features within them, and to respect what the human declined (`declined:` in `.peal/config.yml`). Once it exists, setup naming a stage itself duplicates it and can contradict it (suggesting a stage the human declined, or not the one with the best evidence).

---

## Outcome

