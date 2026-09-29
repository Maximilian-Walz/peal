---
plan: skipped
touches: [plugin/commands/idea.md, plugin/commands/commands.test.sh]
milestone: m2
priority: high
---

# 0109 — /peal:idea under Belfry passes the whole composed text to task_create

## Intent

`/peal:idea` step 3, in its "`BELFRY_SESSION` set" branch off a task branch, tells the session to call `task_create` with `body` "the composed text (from `## Intent` on; not the frontmatter or heading)". Belfry hands that body to this project's `tasks.commands.create`, `peal create`, which refuses it with "the first heading must be '# 0109 — Title'" and files nothing. Leaving out the frontmatter would also lose the triage (plan, touches, milestone, depends). When this is done, the step says that `body` is the whole composed text, frontmatter and `# 0109 — Title` heading included, the same text `peal idea` and the `idea` tool fallback get, and a session following it files on the first try.

## Scope

- `plugin/commands/idea.md` step 3, the `task_create` sentence.
- Any other command that gives `task_create` a body the same way (`/peal:split`, `/peal:defer`, close's queued ideas): the same fix there.

## Done when

- `plugin/commands/commands.test.sh` checks that idea.md's Belfry branch names the whole composed text as `task_create`'s body and no longer says "not the frontmatter or heading".

## Raw

> /peal:idea under Belfry passes the whole composed text to task_create
>
> (The human supplied this task's text in full: frontmatter `plan: skip`, `touches: [plugin/commands/idea.md, plugin/commands/commands.test.sh]`, and the Intent, Scope, Done when and Notes above, verbatim.)
>
> Belfry friction, 2026-09-28 (jobs cd1bdefa6d7719ec, 931d0562a1ccd955): "/peal:idea's task_create instructions contradict what peal's filing command accepts... Filing only worked when the body was the whole composed text, frontmatter included."

## Notes

- The workaround both sessions used (calling task_create again with the full text) filed 0102 correctly, so `peal create` already takes the full text as it is. Only the prompt needs to change.
- Plan: the human wrote `plan: skip`, kept as `skipped` although `plugin/` is in `plan.required-paths`; the change is one sentence of a prompt.
- At filing, `grep task_create plugin/commands/` finds it only in `idea.md` (and its check in `commands.test.sh`); the second Scope bullet may have nothing to change. The existing check `idea: calls Belfry's task_create` counts 3 occurrences and must stay in step with the edit.

---

## Outcome

<!-- Written at close, replacing this comment. -->
