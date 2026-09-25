---
milestone: m1
plan: required
size: M
model: opus
touches: [plugin/templates/*, plugin/lib/githooks.sh, plugin/lib/githooks.test.sh, plugin/lib/session.sh, plugin/lib/init.sh, plugin/lib/init.test.sh, docs/design.md, docs/security.md]
---

# 0040 — The git hooks and launcher Peal installs: safe in other people's repositories

## Intent

`peal init` installs git hooks and a launcher into the user's repository, and they run
on every commit and push, also on content a stranger contributed. They must never run
what the repository ships.

## Scope

- Hooks read only what they need, never execute repository content (no sourcing files
  from the working tree), use no network, and fail safe with a message. Reading the gate
  settings from main instead of the work tree is a task of its own (split).
- The launcher checks that the plugin it calls is the installed one (version and path),
  not something the repository ships.
- `peal init --remove` leaves nothing behind.

## Done when

- Harnesses cover a repository whose content tries to be executed by a hook (planted
  plugin, launcher, recorded root, `PEAL_ROOT` and cache entries), and removal.
- No hook calls the network; every refusal names its reason.
- The limits that remain (`checks.commit`, in-tree project hooks, the committed
  `.peal/peal`) are written in `docs/security.md`.

## Raw

Filed as issue #40 (https://github.com/Maximilian-Walz/peal/issues/40); its text is carried over into the sections above.

## Notes

Planning answers from the human (2026-09-25):
- Split: this task keeps root verification, stub messages, removal and harnesses. Reading
  the gates' settings (`checks.commit`, `main`, `tasks`) from the main branch's tip instead
  of the work tree is a task of its own, filed as an idea.
- A1 `checks.commit`: the branch must not choose which commands run (main's config does,
  in the split piece); the commands themselves run the checked-out tree, recorded in
  `docs/security.md` as an accepted limit.
- A2 installed version: consult `installed_plugins.json` when present (its `peal@*`
  entry's `installPath` and `version`); when absent, path checks only.
- A3 `peal.projectHooks`: keep chaining to an in-tree hooks path; document it; the harness
  asserts only that configured path runs.
- A4 cache: any marketplace's `peal`, but only a root that passes verification; newest by
  mtime.
- A5 `$PEAL_ROOT`: the stub ignores a `PEAL_ROOT` inside this repository, with a message;
  the launcher honours `PEAL_ROOT` as is.
- A8 removal: remove `peal-root` and the `peal.*` config; claims, `task/*` branches,
  `refs/reaped/*` and per-task git-dir files are task state and stay. "Nothing behind"
  is checked after removing every stage in order.
- A9 the committed `.peal/peal`: record the limit in `docs/security.md`; file an idea for a
  warning when it differs from the installed template.
- A11 git hooks only, plus `peal_record_root` (it feeds the launcher); not the Claude Code
  session hooks. A12 new `plugin/templates/githook.test.sh`. A13 a refused root is
  reported on stderr each time it is skipped.

## Plan

Approach:
1. Root verification, the same code in `plugin/templates/launcher` and
   `plugin/templates/githook` (the stub cannot source files; one harness table runs
   against both). A candidate root is accepted only if it is absolute, has an executable
   `bin/peal`, its `.claude-plugin/plugin.json` says `"name": "peal"` with a version, and it
   is not inside any worktree of this repository (`git worktree list --porcelain`) nor its
   git dir. Recorded and cache roots must also lie under
   `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/`, and when `installed_plugins.json`
   exists its `peal@*` entry must match (path and version). Cache: any marketplace's
   `peal`, verified, newest by mtime. A failing candidate is skipped with a stderr line
   naming it; the next source is tried; none left: the launcher exits 127, the stub
   refuses (exit 1) with a message. The stub ignores an in-repository `PEAL_ROOT` with a
   message; the launcher honours `PEAL_ROOT`.
2. `peal hooks install` (`githooks.sh`) and `peal_record_root` (`session.sh`) refuse to
   record a root inside the repository.
3. Stub hardening: a message on every failure path (`git rev-parse` failing, no Peal
   found, a root refused). No network: the harness pins down that hooks call no `gh`,
   `curl`, `wget`, `ssh`, nor `git fetch`/`ls-remote`/`pull`. Chaining to
   `peal.projectHooks` is kept as is.
4. Removal: `peal_hooks_uninstall` removes `peal-root`, every `peal.*` key and the
   `peal/` directory; `_peal_init_tasks_remove` removes `peal-root` too.
5. Docs: `docs/design.md` (Git gates, Distribution, the Setting up table) and
   `docs/security.md` (boundaries, "What this milestone leaves open"): the root checks,
   and the limits: `checks.commit` and in-tree project hooks run the tree's content; the
   committed `.peal/peal` can be replaced by a branch; gate settings still come from the
   work tree until the split piece lands.

Files: `plugin/templates/githook`, `plugin/templates/launcher`,
`plugin/templates/launcher.test.sh`, new `plugin/templates/githook.test.sh`,
`plugin/lib/githooks.sh`, `plugin/lib/githooks.test.sh`, `plugin/lib/session.sh`,
`plugin/lib/init.sh`, `plugin/lib/init.test.sh`, `docs/design.md`, `docs/security.md`.

Verification:
- `plugin/templates/githook.test.sh` (new): scratch origin and clone with the hooks
  installed; a fake Claude config dir holding a real copy of the plugin as
  `cache/peal/peal/<version>` and an `installed_plugins.json`. The clone plants a
  `plugin/bin/peal` and `lib/common.sh` writing a canary, a `.peal/peal` canary,
  `.git/peal-root` pointing at the work tree's `plugin/`, an in-repo `PEAL_ROOT`, a newer
  `cache/evil/peal/9.9.9` failing verification, and a cache entry whose plugin.json names
  another plugin or version. Real git runs commit, push, checkout, merge, rebase, amend.
  Asserts: no canary; the gate still ran with the installed Peal (a bad subject is still
  refused); stderr names each refused root; network shims on PATH never called; with no
  root left the hook exits non-zero with a message.
- `launcher.test.sh`: fakes get a `plugin.json`; new cases for a recorded root in the
  work tree or a linked worktree, a cache entry not Peal or of another version, and the
  end-to-end run.
- `githooks.test.sh`: install refuses an in-repo `PEAL_ROOT`; uninstall leaves no
  `peal-root` nor `peal.*` key; chaining runs only the configured path.
- `init.test.sh`: the snapshot also covers files under `.git` outside git's own and the
  full `git config --local --list`; a `peal hook session-start` mid-round-trip writes
  `peal-root`; both round trips end equal to the start, except the task.
- `tools/test-all.sh` green under every awk, `tools/lint.sh` clean, CI green incl. macOS
  (bash 3.2 in stub and launcher).

Ranges: tasks/doing/0040-safe-hooks-and-launcher.md:1-35, docs/milestones/m1.md:1-24,
docs/design.md:22-26, docs/design.md:535-570, docs/design.md:781-809,
docs/design.md:811-851, docs/security.md:28-69, docs/security.md:108-113,
plugin/templates/githook:1-61, plugin/templates/launcher:1-47,
plugin/templates/launcher.test.sh:1-70, plugin/lib/githooks.sh:15-102,
plugin/lib/githooks.sh:104-126, plugin/lib/githooks.sh:356-420, plugin/lib/config.sh:1-46,
plugin/lib/session.sh:1-22, plugin/lib/init.sh:292-338, plugin/lib/init.sh:611-683,
plugin/lib/common.sh:1-15, plugin/bin/peal:1-8, plugin/lib/test-lib.sh:1-90,
plugin/lib/githooks.test.sh:1-56, plugin/lib/githooks.test.sh:400-441,
plugin/lib/init.test.sh:1-128, tools/test-all.sh:1-31.

0039 (awaiting merge) is neither awaited nor reused; its `hostile.test.sh` runs `githook`
and `hooks install`, so whichever merges second re-runs `tools/test-all.sh` on the
combined tree.

---

## Outcome

