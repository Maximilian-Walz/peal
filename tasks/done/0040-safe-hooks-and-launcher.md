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
- Departure in the build: `plugin/lib/test-lib.sh`, outside `touches`, exports
  `PEAL_ROOT` to every harness. The hooks in scratch repositories now refuse this
  checkout's recorded root (it is not in the plugin cache), and without the export some
  tests expecting a refusal would pass for the wrong reason.

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

Built: the launcher (`plugin/templates/launcher`) and the git hook stub
(`plugin/templates/githook`) now verify a Peal root before running it, with the same
verification block in both (the stub cannot source files; `launcher.test.sh` asserts the
two copies are identical and runs one table against both). A root is accepted only if it
is absolute, has an executable `bin/peal`, its `.claude-plugin/plugin.json` names `peal`
with a version, and it lies outside every worktree, the base directory and the git
common dir, compared as physical paths (a symlink into the repository counts as inside).
Recorded and cache roots must also lie under `${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/cache/`,
and when `installed_plugins.json` exists one of its `peal@*` entries must list that path
and version (parsed by an inline awk tokenizer; path-only when the file is absent). The
stub applies the repository checks to `PEAL_ROOT` too; the launcher honours `PEAL_ROOT`
as given. A refused root is named on stderr each time; with none left the launcher exits
127 and the stub refuses with a message. `peal hooks install` and `peal_record_root`
refuse a root inside the repository (new helper `peal_repo_holds` in `session.sh`).
`peal hooks uninstall` removes `peal-root`, the `peal/` directory and the whole `[peal]`
config section; `--remove tasks` removes `peal-root` too.

Harnesses: new `plugin/templates/githook.test.sh` drives real git (commit, amend,
checkout, merge, rebase, push) in a clone that plants `plugin/bin/peal`,
`plugin/lib/common.sh`, `.peal/peal`, a `.githooks/` nobody configured, a `peal-root` and a
`PEAL_ROOT` into the work tree, and cache entries that fail verification. It asserts no
canary, the installed gate still refusing a bad subject and a push to main, every refused
root named, network tools shimmed and never called, and git traced with no fetch,
ls-remote or pull. Against the old stub it fails 15 of 25 checks. `init.test.sh` now
snapshots `.git` outside git's own files plus `git config --local --list`, with a
SessionStart run mid-round-trip; removal ends equal to the start.

Decided (the human, in planning): the task was split; reading the gate settings from
main is its own task (idea `gate-settings-from-main`). `checks.commit`, in-tree project
hooks and the committed `.peal/peal` still run tree content: accepted limits written in
`docs/security.md`, along with gate settings still coming from the work tree until the
split piece lands. Removal keeps claims, branches, `refs/reaped/*` and per-task git-dir
files (session files `peal-heartbeat`, `peal-turns`, `peal-nudged` are left out of the
snapshot as session state).

Found in review and fixed: the new `case` pattern inside `$( )` did not parse under bash
3.2 (launcher and stub a syntax error on a Mac's /bin/bash; `peal_repo_holds` failing
open there). Now parenthesised; checked with `bash -n` and a run in a `bash:3.2`
container. The CI guard against it coming back is an idea (`bash32-parse-guard`).

For the next session: a Peal loaded with `--plugin-dir` from outside the cache is still
recorded, then skipped by the hooks with a stderr line on every run.
`PEAL_ROOT=$PWD/plugin plugin/bin/peal hooks install` inside this repository is now
refused. Stale cache versions not listed in `installed_plugins.json` print a skip line
when the hooks search the cache. The branch merged origin/main (0039) and its
`hostile.test.sh` passes on the combined tree. A full `tools/test-all.sh` under every awk
takes over 20 minutes here; macOS/bash 3.2 is left to CI. Ideas, carried below: gate settings from
main, a warning when the committed launcher differs from the installed one,
`checks.close` from main, and the bash 3.2 CI guard.

### Ideas not filed

`peal close finish` could not file the four queued ideas: main's ruleset refuses the
direct push (the gap 0061 closes). The human chose to carry them here instead; once 0061
has landed, a session files each with `peal idea <slug>` from the text below (strip the
four-space indent, keep `NNNN`).

    -----IDEA gate-settings-from-main-----
    ---
    milestone: m1
    plan: required
    touches: [plugin/lib/config.sh, plugin/lib/githooks.sh]
    ---

    # NNNN — Gate settings from the main branch, not the work tree

    ## Intent

    The git gates take their settings (`checks.commit`, `main`, `tasks`, `milestones`) from the
    checked-out `.peal/config.yml`, so a stranger's branch can choose which commands the
    commit-msg gate runs, or move `main` so pre-push no longer protects it. `peal githook`
    should read `.peal/config.yml` from the main branch's tip instead (remote-tracking ref,
    then the local branch, then Peal's defaults), with the remote and main branch names
    recorded in git config at `hooks install` so a branch cannot redirect the lookup. Split
    from 0040, whose hooks and launcher no longer run what the repository ships.

    ## Scope

    ## Done when

    ## Raw

    > Gate settings from the main branch, not the work tree (split from 0040, milestone m1). `peal githook` loads `.peal/config.yml` from the main branch's tip (`git show <ref>:.peal/config.yml`, ref `refs/remotes/<remote>/<main>`, falling back to `refs/heads/<main>`, then Peal's defaults), with `peal.main`/`peal.remote` recorded in git config at `hooks install` so a branch cannot redirect the lookup; new `peal_config_load_ref` in config.sh; removes the "Known limit" comment in githooks.sh. A branch then cannot choose which `checks.commit` commands run nor move `main`. Human answers from 0040's planning: the commands themselves still run the checked-out tree (accepted, documented limit); when main has no `.peal/config.yml` yet, use Peal's defaults. Harness: a branch-only `checks.commit` does not run; a branch's `main:` change cannot open a push to real main. Uninstall also removes `peal.main`/`peal.remote`. `checks.close` in `peal close finish` is a separate idea.

    ## Notes

    - Settled in 0040's planning: the commands still run the checked-out tree (a documented
      limit in `docs/security.md`); with no `.peal/config.yml` on main, Peal's defaults apply.
    - Open: with the defaults, the first `/peal:setup` commit with a custom tasks directory
      would be refused by the `chore(peal)` path check until merged. Is that acceptable?
    - Open: 0040 records the limit "gate settings come from the work tree" in
      `docs/security.md`; this task removes it again.
    - Context: `docs/design.md` (Git gates).

    ---

    ## Outcome

    <the Outcome placeholder comment, as in tasks/TEMPLATE.md>
    -----IDEA launcher-drift-warning-----
    ---
    plan: required
    ---

    # NNNN — Warn when the committed launcher differs from the installed one

    ## Intent

    The committed `.peal/peal` is repository content: a branch can replace it, and whatever
    runs it (a session, a control plane's contract) then runs the branch's script. No check
    inside the launcher can guard against its own replacement. Peal could warn, e.g. at
    SessionStart or in `peal check`, when `.peal/peal` differs from the installed plugin's
    `templates/launcher`. Filed from 0040's planning, where the human chose to record the
    limit in `docs/security.md` and file this.

    ## Scope

    ## Done when

    ## Raw

    > A9: The committed launcher .peal/peal is itself repository content: a PR can replace it, and Belfry's contract runs it. No check inside the launcher can protect against that. — "Record limit + idea": record the limit in docs/security.md and file an idea for a warning when .peal/peal differs from the installed template.

    ## Notes

    - Open: where the warning lives (SessionStart, `peal check`, or both), and whether a
      `commit-msg` refusal of a change to `.peal/peal` outside `chore(peal)` is wanted too.
    - Context: `docs/design.md` (Distribution).

    ---

    ## Outcome

    <the Outcome placeholder comment, as in tasks/TEMPLATE.md>
    -----IDEA close-checks-from-main-----
    ---
    plan: required
    ---

    # NNNN — checks.close from the main branch's config

    ## Intent

    `peal close finish` runs `checks.close` from the checked-out `.peal/config.yml`, so a
    branch chooses the commands its own close runs. Like the git gates (the
    gate-settings-from-main task), it could read them from the main branch's config. Kept
    out of 0040 and its split piece because it is not a git hook.

    ## Scope

    ## Done when

    ## Raw

    > `checks.close` in `peal close finish` is a separate idea.

    ## Notes

    - Open: depends in practice on the helper the gate-settings-from-main task adds
      (`peal_config_load_ref`); not recorded as `depends` since that task has no number yet.
    - Context: `docs/design.md`.

    ---

    ## Outcome

    <the Outcome placeholder comment, as in tasks/TEMPLATE.md>
    -----IDEA bash32-parse-guard-----
    ---
    plan: required
    ---

    # NNNN — A CI guard that the scripts parse and run under bash 3.2

    ## Intent

    0040's review found that the launcher and git hook stub did not parse under bash 3.2 (an
    unparenthesised `case` pattern inside `$( )`), and that `peal_repo_holds` misbehaved
    there at run time, while every Linux harness passed. The macOS CI job may run Homebrew's
    bash rather than /bin/bash 3.2, so it would not catch this either. A guard (the scripts
    Peal installs checked with `bash -n` and a smoke run under bash 3.2, or the macOS job
    pinned to /bin/bash) would stop it coming back.

    ## Scope

    ## Done when

    ## Raw

    > From 0040's review: add a guard that runs `bash -n` under 3.2, or make sure the macOS job really uses /bin/bash, so this cannot come back unnoticed.

    ## Notes

    - Open: which bash the macOS job actually runs; whether a `bash:3.2` container job on
      Linux is the cheaper guard.

    ---

    ## Outcome

    <the Outcome placeholder comment, as in tasks/TEMPLATE.md>

### Reviewer findings not acted on

- `test-lib.sh` outside `touches`: kept; it is recorded under Notes as a departure.
