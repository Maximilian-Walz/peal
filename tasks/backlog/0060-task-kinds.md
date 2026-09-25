---
plan: required
---

# 0060 — Task kinds: a kind field from the config, shown as a pill, mapped to labels, and used by close and release

## Intent

A `kind:` frontmatter field whose allowed values are defined in `.peal/config.yml`, e.g.

```yaml
kinds:
  feature: {colour: ..., commit: feat,  section: Features,      label: enhancement}
  bug:     {colour: ..., commit: fix,   section: Fixes,         label: bug}
  docs:    {colour: ..., commit: docs,  section: Documentation, label: documentation}
  chore:   {colour: ..., commit: chore, section: Maintenance,   label: chore}
```

(the exact shape is the planner's call; the defaults are those four kinds, each with a colour, a commit type for PR titles, a release-notes section and an issue label).

- **Validation**: a `kind` not in the config is refused when filing, revising or checking, like any other field's bad value. Absent means no kind.
- **Display**: `peal list` and `peal overview` show the kind as a pill in its colour; `peal board` reports it as `kind` (and the colour, if Belfry's contract wants it) so Belfry can show its own pill (belfry#162).
- **Issues storage**: a kind maps to its label (default `enhancement`, `bug`, `documentation`, `chore`), read and written both ways, in place of a `kind: <value>` label.
- **`/peal:idea`** (and `/peal:split`, `/peal:revise`) set the kind from the idea's wording.
- **`peal close finish`** titles the PR with the kind's commit type: `fix: Title [0042]`; no kind keeps today's title.
- **`/peal:release`** groups its notes by kind, one section per kind in config order, instead of guessing from commit subjects; `breaking` and `release-note: none` keep their meaning, and a task without a kind falls back to today's guess. The bump follows the kind (a `feat`-typed kind is minor, the rest patch unless breaking).
- **Docs**: `docs/design.md` (fields table, the issue mapping table, board fields, Releases), the task template's field comment, and the config's commented defaults.

## Done when

- `.peal/config.yml` accepts a kinds setting; `plugin/lib/config-defaults.yml` holds the four defaults (feature, bug, docs, chore) with colour, commit type, release section and issue label, and the config harness asserts they print and can be overridden.
- A task with an unknown `kind` is refused when filed and named by `peal check`; a harness asserts it.
- `peal list` and `peal overview` show the kind as a coloured pill; `peal board` emits `kind` only when set; harnesses assert both.
- On issues storage, a kind is written and read as its label (`bug` ↔ `kind: bug` by default, `enhancement` ↔ `feature`, ...); `store-issues.test.sh` asserts the round trip.
- `/peal:idea` sets `kind` from the idea's wording; `commands.test.sh` checks the command text asks for it.
- `peal close finish` titles the PR `<commit type>: Title [ID]` for a task with a kind, and `Title [ID]` without one; `close.test.sh` asserts both.
- `peal ship notes` groups items into one section per kind in config order; a task without a kind falls back to today's rule; `ship.test.sh` asserts both, and the bump for each case.
- `docs/design.md`, `tasks/TEMPLATE.md`, `plugin/templates/task.md` and the commented defaults in `.peal/config.yml` describe the field.

From the idea box, filed by max.

## Raw

Filed as issue #60 (https://github.com/Maximilian-Walz/peal/issues/60) from an idea a session had; its text is carried over into the sections above.

## Notes

Today a task has no kind. What comes nearest:

- **Fields** (`docs/design.md`, "Peal's fields"; `tasks/TEMPLATE.md`; `plugin/templates/task.md`): `milestone`, `plan`, `size`, `depends`, `needs`, `priority`, `owner`, `merge`, `touches`, `breaking`, `release-note`. A project can declare its own under `task.fields` in `.peal/config.yml` (`plugin/lib/config-defaults.yml`), but those are plain values with no meaning to Peal.
- **List, overview and board**: `peal list` details and `peal overview` (`plugin/lib/overview.awk`) mark priority and owner; `peal board` (`plugin/lib/board.awk`) prints one JSON object per task with the fields of Belfry's contract. None carries a kind.
- **Issues storage** (`plugin/lib/store-issues.sh`, `docs/design.md` "An issue as a task"): fields become labels `<field>: <value>`; the conventional GitHub labels (`bug`, `enhancement`, `documentation`) mean nothing to Peal, apart from `bug` in the release.
- **`/peal:idea`** (`plugin/commands/idea.md`) sets title, milestone, plan, size, priority and touches, no kind.
- **`peal close finish`** (`plugin/lib/close.sh`) titles the PR `Title [ID]`, no commit type.
- **`/peal:release`** (`plugin/commands/release.md`, `plugin/lib/ship.sh`, `docs/design.md` "Releases") guesses a task's kind: a fix when its commit subject starts `fix` or the issue is labelled `bug`, a feature otherwise; the notes have only the sections Breaking, Features and Fixes (`PEAL_SHIP_SECTIONS`).

---

## Outcome

