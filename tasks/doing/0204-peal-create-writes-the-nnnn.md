---
plan: required
priority: high
milestone: m6
size: M
touches: [plugin/lib/task-text.sh, plugin/lib/backlog.sh, plugin/lib/apply.sh, plugin/lib/store-files.test.sh, plugin/lib/store-issues.test.sh, plugin/lib/apply.test.sh, plugin/lib/hostile.test.sh, docs/reference/cli.md, docs/security.md]
---

# 0204 — peal create writes the `# 0204 — Title` heading when the text comes without one

## Intent

The control plane's filing contract calls `tasks.commands.create` with a body that has no title heading (the title arrives separately, as `{title}`) and always with an owner, `ai` by default. On the files storage `peal create` refuses such a body ("the first heading must be '# 0204 — Title'") and exits 2. The proposal's dry run passes, so the refusal only surfaces after the human has accepted the proposal; two accepted plan proposals were lost this way. When this is done, a body with no heading is filed under the title it came with: `peal create` writes `# 0204 — <title>` from `--title` itself, still refuses a heading that disagrees with `--title`, accepts the owner the contract always sends, and the reference documentation for create says both.

## Scope

- `peal create --title` (both storages, in `peal_create_filed`) and `peal apply`'s `file` proposals (`_pa_item`): when the first non-blank line after the frontmatter is not an H1, write `# NNNN — <title>` there, the title made one line (control characters to spaces, runs of spaces collapsed, ends trimmed), through one shared helper.
- A body that brings its own heading keeps it, even when its title differs from `--title`; a malformed or wrong-number heading is still refused.
- The owner the contract sends is already accepted (`ai` adds no field, `human` writes `owner: human`): no code change.
- `docs/reference/cli.md` (create, apply's `file`) and `docs/security.md` say the title now also becomes the heading when the text has none.

## Done when

- A store-files.test.sh case files a text with no heading through `peal create --title` and gets the heading written.
- An apply.test.sh case files a heading-less `file` proposal and gets the heading from its `title`.
- A title with a newline and a tab yields a one-line heading, on both paths.
- The existing "another number" refusals still hold.

## Raw

> peal create writes the `# 0204 — Title` heading itself when the text comes without one
>
> ## Intent
>
> The control plane's contract hands `tasks.commands.create` a body without a title heading (the title comes as `{title}`) and always an owner (`ai` by default). `peal create` on the files storage refuses such a text with "the first heading must be '# 0204 — Title'" and exits 2. The proposal's dry run passes, so the failure only shows after the human has accepted the proposal: two accepted plan proposals were lost this way. When this is done, a text with no heading is filed under the title it was given.
>
> ## Scope
>
> - `peal create` (files storage): when the text has no first heading, write `# 0204 — <title>` from `--title`; keep refusing a heading that disagrees with `--title`.
> - Accept the owner the contract always sends (`ai` is the default, so it adds no field).
> - `docs/reference` for create says both.
>
> ## Done when
>
> - A store-files.test.sh case files a text with no heading through `peal create --title` and gets the heading written.
> - The existing "another number" refusals still hold.
>
> ## Notes
>
> - Friction from a plan run, and the second bullet of a control-plane change note (the first bullet, `apply_kinds`, is already in this repository's `.belfry.yml`; 0179 covers the template).

## Notes

- Open question: should the dry run (`peal create --dry-run` or whatever the proposal's check calls) catch the missing heading the same way, or is writing the heading enough that both paths agree again? Either way the dry run and the real filing must not diverge.
- Open question: does "accept the owner" mean only `--owner ai` is a no-op, or should `--owner human` also be honoured on the files storage?
- 0179 covers the related template change; not a prerequisite.
- Context: `docs/reference/cli.md` (create), `docs/reference/tasks.md` (the heading and frontmatter).
- 2026-10-23, the human's answers to the planner's questions:
  - Title check: no new refusal; a body's own heading wins over `--title`.
  - Apply file: yes, `peal apply`'s `file` proposals write the heading too, in this task.
  - Title in file: control characters and line breaks in the title become spaces; such a title is not refused.
  - The revised plan (apply included, size M, default model, merge by the human) agreed.
- Open questions answered by the plan: `--owner human` is already honoured on the files storage; Peal has no dry run on this path, and once it writes the heading Belfry's check and Peal's filing accept the same bodies.

## Plan

**Helper.** `peal_text_ensure_heading TITLE` in `plugin/lib/task-text.sh`, a stdin-to-stdout filter: if the first non-blank line after the frontmatter starts with `# `, the text passes byte for byte; otherwise `# NNNN — <one-line TITLE>` and a blank line go right after the frontmatter (at the top when there is none), the rest unchanged. The title is made one line inside the helper: control characters to spaces, runs of spaces to one, ends trimmed.

**Create.** In `peal_create_filed` (`plugin/lib/backlog.sh`), pass `$tmp` through the helper after the empty, delimiter and merge checks and before the outsider Plan/Outcome check; `peal_store_create`, `peal_task_check` and the `NNNN` replacement run unchanged, so both storages get it. The human's `peal create SLUG` still refuses a missing heading. Update the header comment (lines 103-122).

**Apply.** In `_pa_item`'s `file` branch (`plugin/lib/apply.sh`), run the text through the helper with the proposal's `title` before `NNNN` is replaced; keep the file ending in exactly one newline (no `$(...)` stripping). The batch-wide `peal_task_check` then sees the heading; the static outsider check stays on the raw text. Update the header comment on `file` (lines 13-16).

**Docs.** `docs/reference/cli.md` (create, the apply table's `file` row); `docs/security.md` (create's title/text guarantees, apply's "title only feeds a slug").

**Verification.**
- `bash plugin/lib/store-files.test.sh`, new `create_belfry` cases: frontmatter body with no heading filed with `--owner ai --title "Heading comes from the title"` equals `ID=<id> TITLE=... text "milestone: m1"`; no-frontmatter body starting `## Intent` gets the heading on top; a title with newline and tab gives a one-line heading; a body heading differing from `--title` is kept; `ID=0005 text` still refused; heading-less outsider body with a filled `## Plan` still refused; existing refusals (`store-files.test.sh:229,405`, `backlog.test.sh:79`, `store-issues.test.sh:702`) hold.
- `bash plugin/lib/apply.test.sh`: heading-less `file` gets `# <id> — <title>`; title with `\n`/`\t` gives one line; text with `# 0007 — X` is `done: false`, nothing written; the `mixed` batch's own heading still wins.
- `bash plugin/lib/store-issues.test.sh`: heading-less body via `create --owner ai --title` becomes an issue titled from `--title`.
- `bash plugin/lib/hostile.test.sh`: hostile title over a heading-less body, for create and apply's `file`; the "byte for byte" check (441-449) still passes.

**Ranges relied on:** tasks/doing/0204-peal-create-writes-the-nnnn.md:1-45; plugin/lib/backlog.sh:103-224; plugin/lib/tasks.sh:56-85; plugin/lib/task-text.sh:1-36; plugin/lib/apply.sh:1-30,388-406,590-643,995-1014; plugin/lib/apply.test.sh:20-89; plugin/lib/store-files.sh:418,463; plugin/lib/store-issues.sh:565,597; plugin/lib/store-files.test.sh:83-145,229,405; plugin/lib/hostile.test.sh:325-362,382-385,429-477,735-737; plugin/lib/task-fixtures.sh:39-46; plugin/lib/init.sh:409; docs/reference/cli.md:256-274,337-339; docs/security.md:162-185,200-224; docs/reference/tasks.md:12; docs/milestones/m6.md:1-15.


---

## Outcome

<!-- Written at close, replacing this comment. -->
