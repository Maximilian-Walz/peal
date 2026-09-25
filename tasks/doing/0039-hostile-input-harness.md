---
milestone: m1
plan: required
priority: high
---

# 0039 — Hostile input: shell, awk, gh and prompts

## Intent

Task titles, slugs, frontmatter, milestone names and issue bodies flow through awk, shell
and `gh` in `plugin/lib`, and into prompts. On a public repository some of that text
comes from strangers. None of it may be executed, written where it does not belong, or
reach a prompt as anything but quoted data.

## Scope

- Audit every place a value from a task or an issue reaches a command line, `eval`, a
  here-doc, a file name or a git ref in `plugin/lib/`; quote or validate, and refuse
  values that cannot be made safe (a slug is `[a-z0-9-]`, a ref is checked with
  `git check-ref-format`).
- `plugin/lib/hostile.test.sh`: runs every command with hostile values (`$(touch
  pwned)`, backticks, `;`, newlines, `-` leading arguments, `../`, very long strings,
  invalid UTF-8) and fails if anything is executed or written outside where it belongs;
  `tools/test-all.sh` runs it.
- Check that every read path of the issues storage applies the write-access rules
  (issues, comments, PRs), and that text from outsiders reaches a prompt only quoted as
  data.

## Done when

- The hostile-input harness runs in CI over every command; `shellcheck` is clean.

## Raw

Filed as issue #39 (https://github.com/Maximilian-Walz/peal/issues/39); its text is carried over into the sections above and below.

## Notes

Decided up front, so a session need not ask:

- shellcheck already runs in CI (`tools/lint.sh`); keep it.
- Fix what the harness finds in this task; if that is more than about ten fixes, fix the
  worst and file the rest as ideas.

---

## Outcome

