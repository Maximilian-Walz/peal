---
plan: required
size: M
depends: []
touches: [docs/adopting.md, docs/migrating.md, docs/getting-started.md, docs/reference/README.md, plugin/commands/setup.md, README.md]
milestone: m8
---

# 0192 — docs/adopting.md absorbs docs/migrating.md: coexisting with an existing setup, migrating step by step, backing out

## Intent

A heavy Claude Code user with their own CLAUDE.md, commands, hooks, commit convention and tracker has no page that says what Peal imposes on an existing setup, how it coexists, and how to back out. The facts exist but are scattered: their `CLAUDE.md` is kept and the planner and implementer follow it; their commands and agents are untouched (Peal's are namespaced `/peal:`); their Claude Code hooks and Peal's both run; their git hooks are chained (`peal hooks install` chains to the previous hooks path, a foreign `core.hooksPath` is only warned about); once `guardrails` is on, every commit on every branch must read `<type>(<area>): <what>` (`wip:` and git's own subjects pass; the `[0192]` id only on task branches) and a commit on main is refused by the git guard in any Peal repository; GitHub issues are supported as the `issues` storage, other trackers are not. `docs/migrating.md` is a good procedure for one kind of project, a task-file process with `key: value` headers, pools and numbered milestone docs; step 2 says `peal init --stage tasks` without installing the plugin first (outside a session `peal` is not on the path); back-out (`peal init --remove STAGE`, `peal hooks uninstall`, `/plugin uninstall`, the worktrees folder, `tasks/` staying as Markdown) is only in the setting-up guide's stage table. When this is done there is one adoption page for both readers.

## Scope

- Part 1, "Alongside what you have": the table of what Peal does to each of their things, what `guardrails` imposes and how to stay at the `tasks` stage without it, step-by-step adoption (install, `/peal:setup`, merge the setup, first task, then stages through `/peal:next`), and back-out.
- Part 2, "A task-file process of your own": today's `migrating.md` in generic wording, starting with the `/plugin` lines and `/peal:setup` before the converters; the scope tables shortened to categories with a generic example each (the longer tables leave `docs/design.md`, see the task on the doc's inaccuracies).
- `docs/migrating.md` is removed; the five links to it (README, getting-started, `docs/reference/README.md`, `docs/design.md`, `plugin/commands/setup.md`) are updated. A short paragraph "What Peal adds to your session, and what it leaves alone" (hooks cost 35 to 90 ms and are silent outside a Peal project; `init` merges into an existing `.claude/settings.json`; a user's own agents do not collide).

## Done when

- `docs/adopting.md` exists with both parts and the back-out list; `docs/migrating.md` does not, and no link to it is dead (`tools/docs.test.sh`).
- Every command in the page's examples is run by the docs harness.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Documentation review, section 4, 8.3 and 8.4; usability review (the commit grammar and the main guard are what a heavy user must know before installing).
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
