---
milestone: m1
plan: required
priority: high
size: L
model: opus
touches: [plugin/lib/*.sh, plugin/lib/*.awk, plugin/bin/peal, docs/design.md]
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

## Plan

Approach:

- Validation helpers in `plugin/lib/common.sh`: `peal_valid_id` (files `^[0-9]{4}$`,
  issues `^[0-9]+$`), `peal_valid_slug` (`^[a-z0-9]+(-[a-z0-9]+)*$`), `peal_valid_ref`
  (`git check-ref-format "refs/heads/$NAME"`), `peal_valid_relpath` (no leading `/` or
  `-`, no `..` component, no newline). Called where a value first enters (`plugin/bin/peal`
  dispatch and the `peal_store_*` functions); a value that fails exits 2 with
  `refused: ...`.
- Free text (reasons, titles, bodies) is not validated, only passed safely: quoted
  arguments, `ENVIRON[]` or files instead of `awk -v` (which interprets backslashes),
  `--` before git operands, JSON through `peal_json`.
- Known suspects to confirm with the harness: unvalidated ids into awk `-v` and git
  refspecs (`peal_store_read`, store-files.sh:233-246); `-`-leading values reaching git
  or `gh api` (`peal_gh`, github.sh:48-73); task file names on main matched as `[^/]+`
  (store-files.sh:71-92); branch names under `task/`; worktree paths built from slugs;
  `peal_slugify`'s error echo (task-text.sh:81-90). No `eval` runs text (git-guard.sh:85
  only parses); no awk file runs `system()` or piped `getline`; the `bash -c` of
  checks.commit/checks.close runs trusted config (out of scope).
- `plugin/lib/hostile.test.sh`: a scratch origin and clone from `task-fixtures.sh`;
  hostile values, each canary writing into `$CANARY_DIR` if run (`$(touch ...)`,
  backticks, `;`, `&&`, `|`, newline + command, `-rf`, `--output=...`,
  `--upload-pack=...`, `../../escape`, `/abs`, globs, a 64 KiB string, `$'\xff\xfe'`,
  awk escape bait `\n` and `a=b`); through every channel (CLI arguments, task texts on
  stdin with title/frontmatter/depends/touches/needs, task file and branch names seeded
  in the origin, milestone fields; hostile JSON on stdin for `hook *`, hostile ref lines
  and message files for `githook`). After each command: no canary file; a `find` +
  size snapshot of everything outside the allowed places unchanged; no ref outside the
  expected namespaces; exit 0, 1 or 2 with no shell syntax error on stderr. `TMPDIR`
  inside the scratch root. A coverage check extracts the command names from `main()`'s
  `case` in `plugin/bin/peal` and fails when one has no hostile case. A self-test runs a
  deliberately unsafe one-liner through the same assertions and expects it caught.
  Full matrix under the first awk found, awk-sensitive channels under all
  (`for_each_awk`, test-lib.sh:59-84).
- Up to about ten fixes, worst first; the rest in a `KNOWN` list naming their ideas.
- One sentence in `docs/design.md` that malformed ids, slugs and refs are refused.

Files: create `plugin/lib/hostile.test.sh`; modify `plugin/lib/common.sh`,
`plugin/bin/peal`, `docs/design.md`, and the `plugin/lib/*.sh`/`*.awk` the audit
implicates (likely store-files, claim, backlog, ideas, close, work, task-text,
milestones, review, ship, decisions, githooks, commit, session, init, github,
task-fixtures). `tools/test-all.sh` and CI need no change.

Verification: `bash plugin/lib/hostile.test.sh` passes; its self-test is caught;
dropping a command's case fails the coverage check; reverting one fix makes it fail
(shown in the Outcome). `tools/test-all.sh` lists it and every harness passes on Linux
(all awks) and macOS (bash 3.2, BSD awk). `tools/lint.sh` clean. Legitimate values keep
working (`task/0042-some-slug`, `issue/42`, `m08`). CI's harnesses and shellcheck jobs
green.

Ranges: tasks/doing/0039-hostile-input-harness.md:1-49, docs/milestones/m1.md:1-24,
docs/design.md:224-296, docs/design.md:311-351, docs/design.md:535-570,
docs/design.md:572-654, docs/design.md:811-851, .github/workflows/ci.yml:11-41,
tools/test-all.sh:1-31, tools/lint.sh:1-21, plugin/bin/peal:1-409,
plugin/lib/common.sh:1-15, plugin/lib/task-text.sh:1-90, plugin/lib/store.sh:1-88,
plugin/lib/store-files.sh:40-107, plugin/lib/store-files.sh:233-295,
plugin/lib/github.sh:1-78, plugin/lib/json-request.awk:1-28, plugin/lib/test-lib.sh:1-90,
plugin/lib/work.sh:67-123, plugin/lib/githooks.sh:410-418, plugin/lib/close.sh:410-420,
plugin/lib/git-guard.sh:45-90, plugin/lib/init.sh:484-560, plugin/lib/ship.sh:185-210.

---

## Outcome

