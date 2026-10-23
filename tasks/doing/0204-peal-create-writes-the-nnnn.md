---
plan: required
priority: high
milestone: m6
---

# 0204 — peal create writes the `# 0204 — Title` heading when the text comes without one

## Intent

The control plane's filing contract calls `tasks.commands.create` with a body that has no title heading (the title arrives separately, as `{title}`) and always with an owner, `ai` by default. On the files storage `peal create` refuses such a body ("the first heading must be '# 0204 — Title'") and exits 2. The proposal's dry run passes, so the refusal only surfaces after the human has accepted the proposal; two accepted plan proposals were lost this way. When this is done, a body with no heading is filed under the title it came with: `peal create` writes `# 0204 — <title>` from `--title` itself, still refuses a heading that disagrees with `--title`, accepts the owner the contract always sends, and the reference documentation for create says both.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
