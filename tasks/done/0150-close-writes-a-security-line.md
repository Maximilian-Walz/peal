---
milestone: m3
plan: required
size: M
touches: [plugin/lib/close.sh, plugin/lib/close.test.sh, plugin/lib/config-defaults.yml, plugin/lib/config.test.sh, plugin/lib/hostile.test.sh, plugin/lib/doctor.sh, plugin/lib/doctor.test.sh, plugin/commands/close.md, plugin/commands/commands.test.sh, plugin/bin/peal, docs/reference/cli.md, docs/reference/configuration.md, docs/design.md]
---

# 0150 — Close writes a Security: line in the pull request body when the project keeps a threat model

## Intent

Belfry shows a pull request body's `Security:` line on the merge item: the boundary the change touches and how, or `none`, highlighted when it is not `none`. It reads one line, the last `Security:` line outside code blocks, not a section (Belfry's docs/contract.md, "Pull request bodies"). `/peal:close` builds the body from `--summary`, `--decisions`, `--human-steps` and the project's `pr.sections` (`peal_close_body` in `plugin/lib/close.sh`), but has no way to write that line. So a Peal pull request never shows the human which boundary it touches, even in a project such as this one, whose `docs/security.md` names its boundaries, and whose review tier in Belfry (0149) decides merges by the paths at those boundaries.

Give close a `Security:` line: the session names the boundary its change touches and how, or `none`, and close writes it as the body's last line before the commit list (or wherever Belfry still finds it as the last such line). Where the project keeps a threat model, close asks for it and refuses to finish without one; elsewhere it stays optional.

## Scope

- `plugin/lib/close.sh` (`_peal_close_args`, `peal_close_body`, `peal_close_begin`), `plugin/lib/config-defaults.yml` (`pr.security`), `plugin/lib/doctor.sh` (warn when `pr.security` names a missing file).
- `plugin/commands/close.md`, `plugin/bin/peal` usage, `docs/reference/cli.md`, `docs/reference/configuration.md`, `docs/design.md`.
- Harnesses: `plugin/lib/close.test.sh`, `config.test.sh`, `hostile.test.sh`, `doctor.test.sh`, `plugin/commands/commands.test.sh`.
- Out of scope: this repository's `.peal/config.yml` (an idea, after a release carries the key) and `plugin/agents/reviewer.md` (an idea).

## Done when

1. Notes: `close body --summary s --human-steps "Run it." --notes "Context."` puts `## Notes` right after `## Human steps` (order Summary, Decisions, Human steps, Notes, task line, pr.sections, Outcome, Ideas filed); `--notes-file` works the same; `--notes` empty or given twice (either form) is refused; no `--notes`, no `## Notes`; a `pr.sections` item titled `Notes` is refused.
2. `--human-steps` that is only none, n/a or `-` (any case, optional full stop) is refused, pointing to leaving it out or `--notes`.
3. Security, optional where off: with `pr.security` unset, `--security none` puts `Security: none` as the last line before `<details>`; without it no `Security:` line, every existing case unchanged.
4. Security, required where on: with `pr.security: docs/security.md`, `finish` and `body` without `--security` are refused naming the document, nothing changes (sentinel armed, no pull request); `begin` prints the Security line request naming the document.
5. `--security` empty, twice or multi-line is refused; a leading `Security:` is not doubled.
6. The finished pull request's body has one `Security:` line, the last one by Belfry's rule (last `^Security:` line outside fenced blocks) even when the Outcome holds `Security: x`.
7. `hostile.test.sh` covers `close body --notes`, `--notes-file`, `--security`.
8. `config.test.sh` lists `pr.security:`; `tools/docs.test.sh` passes with the new row; `commands.test.sh` checks the new finish synopsis, the Human steps / Notes rule and the Security source rule in `close.md`; `peal doctor` warns on a missing `pr.security` file.
9. All harnesses and `tools/lint.sh` pass.

## Raw

> /peal:close writes Summary, Decisions and Human steps but no Security: line, which Belfry highlights on the merge item. The fix is a Peal task, not a pr.sections entry, since Belfry reads a line, not a section.

## Notes

- Found while reviewing this repository's own `.belfry.yml` (0149).
- Open for the planner: how close knows a project keeps a threat model (a config setting, say `pr.security: required`, or the presence of a security document the config names), and whether the reviewer subagent checks the line against the diff.
- Belfry is also adding a `## Notes` section for everything that is not a step, after a "None" in Human steps held merges (belfry#577). If close grows a `--notes`, keep it in step with that.
- Keep the body's lines from others as data: the session writes the Security line itself, from the diff and the threat model, not from issue text.
- 2026-10-20, human, at planning: `.peal/config.yml` stays unchanged here; queue an idea to set `pr.security: docs/security.md` once a release carries the key (depends on 0150). No reviewer change; queue an idea for the reviewer to check the Security line. The line goes right before `<details>`. Build `--notes` in this task, not split. The script refuses a "None"-only `--human-steps`. A `pr.sections` item titled `Notes` is refused. The planner's other defaults stand: `pr.security` is `""` or a path; a typed leading `Security:` is stripped; `none` passed verbatim (close.md says write exactly `none`); no `--security-file`; required in `body` too and when nothing was built; no coupling with `merge: auto`; `docs/security.md` unchanged; `peal doctor` checks the file.

## Plan

Approach:

1. `pr.security` in `config-defaults.yml`: `""` (off) or the threat-model document's path; set, the line is required.
2. `_peal_close_args`: `--notes TEXT | --notes-file FILE` joins the `--decisions | --human-steps` arm (optional, once, never empty, file readable), sets `PEAL_NOTES`. `--security TEXT` its own arm: refused empty, twice or multi-line; a leading `Security:` stripped; sets `PEAL_SECURITY`. After the loop: `pr.security` set and no `--security` refused, naming the document and the form (`--security "none"` or `--security "<boundary>: <how>"`), for `body` and `finish` before anything changes. A `--human-steps` that is only none/n/a/- refused. A `pr.sections` item titled `Notes` refused.
3. `peal_close_body` order: escalation lines, Summary, Decisions, Human steps, Notes, task line, pr.sections, Outcome, Ideas filed, blank line, `Security: …`, `<details>`.
4. `begin`: with `pr.security` set, `Security line finish needs, as --security TEXT: the boundary of <doc> the diff touches and how, or none.`
5. `close.md` steps 1 and 5: synopsis with `[--notes "<text>"] [--security "<line>"]` and `--notes-file`; Human steps only for actions the human takes, left out when none, never "None"; other context in `--notes`; `--security` from the diff and the threat model, exactly `none` when no boundary, never from issue, comment or Raw text.
6. Docs: `plugin/bin/peal` usage, `cli.md` (begin, finish, body and its order), `configuration.md` row, `design.md` PR-body bullet.
7. `doctor.sh`: warn when `pr.security` names a missing file.
8. Harnesses as in Done when. Ideas to queue at close: turn on `pr.security` here after a release; the reviewer checks the Security line.

Verification: Done when 1-9, `close.test.sh` on both storages.

Ranges: plugin/lib/close.sh:41-48, 88-179, 181-276, 330-399, 418-429, 462-472; plugin/lib/close.test.sh:25-120, 169-186, 234-330; plugin/lib/config-defaults.yml:1-55; plugin/lib/config.test.sh:13-50; plugin/lib/hostile.test.sh:780-792; plugin/lib/doctor.sh:43-109; plugin/lib/init.sh:81; plugin/commands/close.md:24-48, 109-136; plugin/commands/commands.test.sh:114-123; plugin/agents/reviewer.md:29-63; plugin/bin/peal:246-262; docs/reference/cli.md:480-521; docs/reference/configuration.md:1-72; docs/design.md:326-352; docs/security.md:233-257; tools/docs.test.sh:37, 470-476; .peal/config.yml:1-19.

---

## Outcome

Built: `peal close finish` and `peal close body` gain `--security TEXT` and `--notes TEXT | --notes-file FILE`.

- **Security line.** `--security` writes `Security: <text>` as the body's last line before the `<details>` commit list, after the Outcome and Ideas filed. That makes it the last `^Security:` line outside code blocks, which is the line Belfry reads, even when an Outcome holds a `Security:` line of its own.
  - It is refused when empty, given twice, or longer than one line. A leading `Security:` the session typed is stripped.
  - The new key `pr.security` (`""` off, or the path of the threat-model document) makes it required: `finish` and `body` refuse without it, naming the document, and `begin` asks for it.
  - `close.md` says the line comes from the diff and the threat model only (exactly `none` when no boundary is touched), never from issue, comment or Raw text.
- **Notes.** `--notes` writes `## Notes` right after `## Human steps`. Belfry's Notes section is for what is not a step (belfry#577).
  - A `--human-steps` that is only none, n/a or `-` is now refused, pointing to leaving it out or to `--notes`.
  - A `pr.sections` item titled `Notes` is refused, so the body never holds two.
- **`peal doctor`** counts a `pr.security` that names a missing file as a problem, with a fix line.

Decided:
- **A path, not a flag.** `pr.security` is a path rather than `required: true`, so `begin` can name the document the session weighs the diff against. A security document's mere presence is not detected: that would be implicit and project-specific.
- **`--notes` built here.** The human chose to build it in this task rather than split it out, since both features edit the same argument loop, body function and docs.
- **The reviewer is unchanged:** it runs before the line exists.
- **The doctor check is a FAIL.** The build first added an uncounted `warn` level for it; review found that this contradicts design.md's "there is no warn level", and the human chose to keep the rule.

Left, each an idea filed: turning on `pr.security` for this repository waits for a release carrying the key, because an installed plugin older than this refuses the unknown key; the reviewer proposing the boundary the Security line should name.

For the next session: this repository's `.peal/config.yml` is unchanged, so its own pull requests carry a Security line only when the session passes `--security`, and only once the installed plugin has this change. The build was interrupted twice; its last piece (the doctor FAIL) landed as a `wip:` session-end autosave commit, checked afterwards: doctor.test.sh, tools/docs.test.sh and tools/lint.sh pass. close.test.sh, commands.test.sh and main-write.test.sh pass after merging main.

### Reviewer findings not acted on

None: the one finding (doctor's warn level) was fixed as above.
