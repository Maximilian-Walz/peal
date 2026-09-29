---
plan: required
size: M
touches: [plugin/lib/task-*.awk, plugin/lib/board.awk, plugin/lib/json.awk, plugin/lib/issues-*.awk, plugin/lib/store*.sh, plugin/lib/*.test.sh, plugin/templates/task.md, tasks/TEMPLATE.md, plugin/commands/idea.md, plugin/commands/revise.md, docs/**, tools/docs.test.sh]
---

# 0116 — Tasks take after_deploy, and the board line carries it

## Intent

A control plane can hold a task back until the server it runs contains certain pull requests: a task that puts a newly shipped configuration key to use cannot be worked until that key is live. Belfry reads this from the board line as `"after_deploy": [...]`, where each entry is a number, or a string like `"#412"` or `"owner/repo#412"`. Peal should let a task's frontmatter carry `after_deploy:` as a YAML list and have `peal board` print it on the task's line exactly as written. Peal does nothing else with the field; it only passes it through. The filing text (`/peal:idea` and the task template) should say when to write it: when a task depends on a control-plane change that is merged but may not be deployed yet.

## Scope

- `tasks/TEMPLATE.md` and the template Peal installs (`plugin/templates/task.md`): the field and one line on what it means.
- The frontmatter check (`task-check.awk`) and `peal board` on files storage: `after_deploy` is a known field, passed through to the board line.
- The issues storage: `After deploy of #N, repo#M` lines in the issue body round-trip to and from `after_deploy`, like `Depends on #N`.
- `/peal:idea`: one sentence on when to set it; `/peal:revise`: one clause that it may add the field.
- Docs: `docs/reference/tasks.md`, `docs/reference/cli.md`, `docs/reference/storage.md`, one sentence in `docs/design.md` "Peal and Belfry"; `tools/docs.test.sh` sees underscored fields.

## Done when

- Board harness: a task with `after_deploy: [412, "#413"]` emits `"after_deploy":[412,"#413"]` on its line, and a task without it (or with `[]`) emits nothing extra; `peal list` is unchanged.
- Filing refuses an entry that is not `N` or `[[owner/]repo]#N`; a scalar is a one-item list.
- Issues harness: an issue body line `After deploy of #412, belfry#9` shows on the board line and as frontmatter in `peal read`, and filing a text with the field writes that line.
- `tools/docs.test.sh` checks the `after_deploy` row.

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
- 2026-09-29, the human agreed with the planner's defaults:
  - The field name and entry format were checked against Belfry's published contract ("After deploy", board table): `after_deploy`, with numbers or `#N`, `repo#N`, `owner/repo#N`. They match.
  - Issues storage: round trip, `After deploy of ...` body lines (several comma-separated, several lines add up), as with `Depends on`.
  - Spelling: `after_deploy` in frontmatter, as on the board; widen `tools/docs.test.sh`'s field regex to `[a-z_-]*`.
  - Validation: filing refuses anything but `N` or `[[owner/]repo]#N`, and accepts a scalar as a one-item list. The board passes everything through: all-digit entries become JSON numbers (so `"412"` becomes `412`, with leading zeros stripped), everything else becomes a JSON string. No warnings.
  - Mentions: one clause in `/peal:revise`. No marker in `peal list` or `overview` (board only, like `touches`). `/peal:comment` is untouched. The filing text uses generic words, and Belfry is named only in `docs/design.md`'s "Peal and Belfry".
  - Key placed after `touches` on the board line, printed whenever set, whatever the state. No session writes it on its own; `/peal:idea` sets it only when the idea says so.
  - Milestone left unassigned. Merge by the human (it extends the board's JSON contract).

## Plan

Agreed 2026-09-29. Size M, model default, merge default.

**Files storage**
1. `plugin/lib/task-check.awk`: add `after_deploy` to the known fields (l.53) and to the unknown-field message (l.57). Check each entry as the `touches` loop does (l.89-97): it must match `^[0-9]+$` or `^([A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)?)?#[0-9]+$`. A scalar is a one-item list.
2. `plugin/lib/task-scan.awk`: `v["after_deploy"]` becomes a new last column (header comment l.8-25, printf l.104-106).
3. `plugin/lib/task-state.awk`: read the column (l.162) and print it as column 21 of the list record (l.13-16, l.219-221). A record without the column reads it as empty, as `origin` does.
4. `plugin/lib/board.awk`: after `touches`/`merge`, `if ($21 != "") line = line ",\"after_deploy\":" json_refs($21)`.
5. `plugin/lib/json.awk`: new `json_refs`. An all-digit item becomes a bare number with leading zeros stripped; anything else goes through `json_str`.
6. `plugin/lib/store.sh`: update the record-column description, if it has one.

**Issues storage**
7. `issues-lib.awk` `body_refs()` (l.115-146) parses `After deploy of #412, belfry#9` lines (all of them) into `AFTERDEP` and takes them out of `BODY_REST`. `issues-scan.awk` carries it as a column, and `store-issues.sh` (the `cut` at l.168) passes it through to the board. `issues-text.awk` renders it as `after_deploy:` frontmatter. `_peal_issues_from_text` (store-issues.sh l.373-383) writes the `After deploy of ...` line.

**Docs and prompts**
8. `docs/reference/tasks.md`: a row in the fields table. `docs/reference/cli.md`: the `peal board` key. `docs/reference/storage.md`: a row in the issue mapping. `docs/design.md`: one sentence in "Peal and Belfry" (l.83-103).
9. `plugin/templates/task.md` and `tasks/TEMPLATE.md`: the field in the field comment, with one line on its meaning.
10. `plugin/commands/idea.md`: one bullet in the field rules (near l.52-66), using generic words ("depends on a control-plane change that is merged but may not be deployed yet"), and the field in the example frontmatter (l.71-78). `plugin/commands/revise.md`: one clause.
11. `tools/docs.test.sh` l.328-329: widen `[a-z-]*` to `[a-z_-]*`.

**Verification**
- `plugin/lib/tasks.test.sh`, a new `after_deploy()` case modelled on `touches()`/`origin()` (l.464-517):
  - `[412, "#413"]` gives `[412,"#413"]`;
  - `["belfry#9", 'owner/repo#10']` gives strings;
  - no field and `[]` give no key;
  - `peal list` is unchanged.
- Filing checks: `[abc]` is refused and the message names the entry; a scalar `412` is accepted; the field is no longer unknown.
- `store-issues.test.sh`:
  - a body line gives the board key and `peal read` frontmatter, and the line is gone from the body;
  - filing a text with the field writes the line.
- `tools/docs.test.sh` passes, and deleting the row is reported.
- Every board line stays valid JSON.

Ranges: board.awk:1-33; task-scan.awk:1-126; task-state.awk:1-16,151-163,219-222; yaml-lib.awk:1-15,84-130; json.awk:1-24; task-check.awk:1-97; frontmatter-write.awk:1-21; tasks.test.sh:464-517; store-issues.sh:1-26,151-177,340-395; issues-lib.awk:1-22,109-146; issues-scan.awk:1-62; issues-text.awk:1-66; templates/task.md:1-35; tasks/TEMPLATE.md:1-35; commands/idea.md:45-107; commands/revise.md:1-17; tools/docs.test.sh:327-331,392; docs/design.md:38-103,218-232,450-487; docs/reference/tasks.md:17-62; docs/reference/cli.md:222-232; docs/reference/storage.md:25-42 (the `.awk` and `.sh` files are under `plugin/lib/`).
