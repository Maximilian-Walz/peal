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

- Audit every place a value from a task reaches a command line, `eval`, a here-doc, a
  file name or a git ref in `plugin/lib/` and `plugin/bin/peal`; quote or validate, and
  refuse values that cannot be made safe (an id is digits, a slug is `[a-z0-9-]`, a ref
  is checked with `git check-ref-format`, a relative path has no `..` component, no
  leading `/` or `-`).
- `plugin/lib/hostile.test.sh`: runs every `peal` CLI dispatch target (`hook *` and
  `githook` included) with hostile values (`$(touch pwned)`, backticks, `;`, newlines,
  `-` leading arguments, `../`, very long strings, invalid UTF-8) through every channel
  of the files storage (CLI arguments, task texts on stdin, task file and branch names,
  milestone fields), and fails if anything is executed or written outside where it
  belongs; `tools/test-all.sh` runs it.
- Not here: the issues storage's read paths and outsider text in prompts; those are
  split off (see Notes).

## Done when

- The hostile-input harness runs in CI over every `peal` CLI command for the files
  storage; it fails when a command has no hostile case; `shellcheck` is clean.
- Up to about ten fixes; any further findings are in the harness's `KNOWN` list, each
  naming the idea filed for it.

## Raw

Filed as issue #39 (https://github.com/Maximilian-Walz/peal/issues/39); its text is carried over into the sections above and below.

## Notes

Revised 2026-09-25: split: hostile-github-content and outsider-text-in-prompts (queued ideas) hold the rest

Decided up front, so a session need not ask:

- shellcheck already runs in CI (`tools/lint.sh`); keep it.
- Fix what the harness finds in this task; if that is more than about ten fixes, fix the
  worst and file the rest as ideas.

Split (2026-09-25, agreed with the human): this task keeps the harness and the
shell/git/awk/gh fixes for the files storage and CLI arguments. Two pieces are queued as
ideas on this branch, filed at close: `hostile-github-content` (the issues storage's
channels in the harness, and the write-access rule on every issues read path; depends on
0039) and `outsider-text-in-prompts` (outsider text quoted as data in the command and
agent prompts). `part-of` could not be written: the split cannot be filed onto the
protected main (0061).

The human's answers while planning:

- A stranger's issue that no filter label admits is refused by read, claim and work
  (the `hostile-github-content` piece's concern).
- `.peal/config.yml` (checks.commit/checks.close) is trusted, the maintainer's; a branch's
  config running code is 0040's. Merged task and milestone files are hostile in shape
  (names, frontmatter), never a source of commands.
- More than about ten findings: fix the worst (code execution, then writes outside the
  repository, then ref or option injection, then missing refusals); the rest go into one
  `KNOWN` list in the harness, each naming its idea.
- "Where it does not belong": only the clone's `.git`, the tasks and milestones
  directories, the worktrees directory and temp files the command removes; `TMPDIR`
  points inside the scratch root, and a leftover temp file fails.
- The full matrix runs under the first awk found; the awk-sensitive channels (task
  texts, frontmatter, file names) under every awk.
- A task file on main whose slug breaks the rule is skipped with a warning on stderr by
  list and read; `peal check` names it.
- Length: refuse only where git or GitHub would fail anyway (refs; labels over 50
  characters); free text only has to pass safely.
- "Every command" is every CLI dispatch target in `plugin/bin/peal`; slash commands are
  the `outsider-text-in-prompts` piece's.
- Invalid UTF-8 in free text passes through byte for byte.
- One sentence in `docs/design.md` on refusing malformed ids, slugs and refs; nothing in
  `docs/security.md` (0038's).
- No coupling to 0038's threat model.

---

## Outcome

