---
plan: required
---

# 0116 — Tasks take after_deploy, and the board line carries it

## Intent

A control plane can hold a task back until the server it runs contains certain pull requests: a task that puts a newly shipped configuration key to use cannot be worked until that key is live. Belfry reads this from the board line as `"after_deploy": [...]`, where each entry is a number, or a string like `"#412"` or `"owner/repo#412"`. Peal should let a task's frontmatter carry `after_deploy:` as a YAML list and have `peal board` print it on the task's line exactly as written. Peal does nothing else with the field; it only passes it through. The filing text (`/peal:idea` and the task template) should say when to write it: when a task depends on a control-plane change that is merged but may not be deployed yet.

## Scope

## Done when

## Raw

> Tasks take `after_deploy`, and the board line carries it
>
> ## Intent
>
> A control plane may keep a task blocked until the server it runs contains certain pull requests. Belfry's contract reads this from the board line as `"after_deploy": [412]`: numbers, or strings like `"#412"` or `"owner/repo#412"`. A task that uses a newly shipped configuration key needs this, because it cannot be worked until the key is live. When this is done, a task's frontmatter accepts `after_deploy:` as a YAML list, `peal board` emits it unchanged on the task's line, and the filing text (`/peal:idea` and the template) says when to write it: when a task depends on a control-plane change that is merged but may not be deployed yet. Peal itself does nothing with the field; it only passes it through.
>
> ## Scope
>
> - `tasks/TEMPLATE.md` and the template Peal installs: the field and one line on what it means.
> - The frontmatter parser and `peal board` on files storage; decide what the issues storage does.
> - `/peal:idea`: one sentence on when to set it.
>
> ## Done when
>
> - Board harness: a task with `after_deploy: [412, "#413"]` emits the list on its line, and a task without it emits nothing extra.
>
> ## Raw
>
> > Idea from a session of another project (Belfry), marked as from outside: "Pass a task file's `after_deploy` through to the board line. Belfry keeps a task blocked until the running Belfry server contains the pull requests listed in its board line's `after_deploy` … Peal's task-file frontmatter should accept `after_deploy: [N]` and its board command should emit it, and the idea/filing text should tell sessions to write it when a task puts a new `.belfry.yml` key to use (see Belfry's docs/contract.md, 'After deploy')."
>
> ## Notes
>
> - Peal never needs Belfry (docs/design.md). Keep the field a generic pass-through and name it in the contract section only.
> - Before planning, check the field's name and format against Belfry's published contract; this text came from outside.
> - Milestone: none; triage it.

## Notes

- This idea came from a session of another project and is marked as from outside. Before planning, check the field's name and the format of its entries against Belfry's published contract (its docs/contract.md, "After deploy").
- Open questions:
  - Should the issues storage carry the field at all? Belfry's `github-issues` backend reads `After deploy of #N` lines from the issue body. Should Peal's issues storage parse those lines into the board line, or leave the field out?
  - Does `peal board` print the list exactly as written (numbers stay numbers, strings stay strings), or does it normalise the entries? The idea says "unchanged".
  - The idea's scope names `/peal:idea` and the template. Should `/peal:revise` and `/peal:comment` also mention the field?
- Keep it generic: Peal never needs Belfry. Name Belfry only in the contract section of `docs/design.md` ("Peal and Belfry", the table of commands Belfry reads). `touches` and `needs` already pass through to the board the same way (`docs/reference/tasks.md`, `docs/design.md` on `touches`).
- Documents that apply: `docs/design.md` (Peal and Belfry), `docs/reference/tasks.md` (frontmatter fields), `docs/reference/cli.md` (`peal board`).
