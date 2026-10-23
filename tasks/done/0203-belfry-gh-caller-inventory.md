---
milestone: m6
plan: required
depends: [0176]
part-of: 0176
size: M
model: opus
touches: [plugin/lib/github.sh, plugin/lib/fake-gh, plugin/lib/main-write*.sh, plugin/lib/ship*.sh, plugin/lib/store-issues*.sh, plugin/lib/gh-callers.test.sh, plugin/commands/release.md, plugin/commands/commands.test.sh, docs/guides/belfry.md, docs/reference/cli.md, docs/security.md, docs/design.md]
---

# 0203 — Every gh call Peal makes is listed for Belfry, and the writes that need a login refuse with the reason

## Intent

Under Belfry a session has no gh login. Close's pull request and the quiet list are handled by the origin. This piece covers every other `gh` call Peal makes. Each one either has a Belfry-side path or is listed as unavailable under Belfry, with what to do instead. A test keeps that list complete. The writes that need a login (main-write's pull request route, `peal ship publish`, the issues storage) refuse up front with the reason, rather than failing halfway.

## Scope

- `plugin/lib/github.sh` (`peal_gh_login`, `peal_gh_need_login`) and `plugin/lib/fake-gh` (`auth token`, `release` under no-auth).
- The refusals in `main-write.sh` (pull request route), `ship.sh` (`publish`, `_peal_ship_issue_items`) and `store-issues.sh` (its write entry points).
- `release.md`'s stop on the login refusal.
- `plugin/lib/gh-callers.test.sh` and the inventory table in `docs/guides/belfry.md`.
- `docs/reference/cli.md`, `docs/security.md`, `docs/design.md`.
- Not touched: `doctor.sh`, `init.sh`'s Belfry template, this repository's `.belfry.yml` (Peal's release as a workflow is 0232).

## Done when

- With gh not logged in: a main-write on the pull request route refuses with the reason and no `peal/main-write-*` branch is pushed; `peal ship publish` refuses before any `gh release` call; every issues-storage write refuses before any git or GitHub change.
- With gh logged in (or a token, as in a release workflow), all three behave as before.
- `gh-callers.test.sh` passes, and fails when a new `peal_gh` caller has no row or a row's function no longer calls gh.
- `docs/guides/belfry.md` says what a Belfry session can and cannot rely on.

## Raw

> - `main-writes: auto` and `peal ship`: say what they do without a login (refuse with the reason, or leave the write to the control plane's host commands).
> - The docs say what a Belfry session can and cannot rely on.
>
> Every other `gh` call Peal makes is either listed in the docs as unavailable under Belfry with what to do instead, or has a Belfry-side path; a test asserts the list is complete (a new `peal_gh` caller fails it until listed).

Split from 0176

## Notes

2026-10-22: Re-plan 2026-10-22: the issues storage's refusal is the stopgap; the path through the control plane's `task_record` is its belfry#727 and Peal's 0227 (Contract kept), which closes the "file an idea" default of this piece's planner.

- From the origin's plan, as agreed with the human: no Belfry tool can stand in for these writes. `pr_create` only opens from the job's own branch, so main-write's `peal/main-write-*` pull requests have no Belfry path. The plan's proposal is that `_peal_mw_pr` refuses before it pushes a branch, and `peal ship publish` and the issues storage refuse the same way. Use the origin's no-login status (`peal_gh` exit 4, `BLOCKED:no-gh-login`) and `fake-gh`'s no-auth mode.
- Inventory, as proposed: one row per shell function under `plugin/lib/*.sh` that calls `peal_gh` or `gh`, in a table in `docs/guides/belfry.md` grouped under command headings. A new `plugin/lib/gh-callers.test.sh` compares the functions it extracts with awk against the table, failing on both missing and stale rows.
- Open for this piece's planner (the planner's defaults, not yet decided by the human):
  - Issues storage: refuse with one line pointing to Belfry's `tasks`/`task` tools, and file an idea for a path through Belfry's tools.
  - Ship: refuse, and mark the `release` action in `init.sh`'s Belfry template as needing a login.
  - Doctor's "gh is not logged in" under Belfry: leave it.
- Size estimate: M, about 90 tool calls.

2026-10-23, the human's answers to the plan:
- Release: Belfry releases through a GitHub workflow its release action dispatches (`workflow: release.yml`), where gh has the run's token; no session releases. So `peal ship publish` refuses only when gh really has no token; `init.sh`'s Belfry template stays unchanged; the inventory's ship row says a release under Belfry runs as that workflow (0232); one idea is filed for a generic `workflow:` release action and starter `release.yml` in the template.
- Issues storage: refuse its writes only, pointing to Belfry's `tasks`/`task` tools; reads keep `peal_gh`'s "gh has no login" failure; no idea (0227 covers `task_record`).
- Revise: document it in the inventory as unavailable on a protected main, and file one idea for a host-side `revise` command.
- Doctor: leave `peal doctor gh`'s "gh is not logged in" as it is; the inventory row says it is expected under Belfry.
- Plan agreed as below: model opus, size M, merge left to the human.

## Plan

**Login probe** (`plugin/lib/github.sh`). `peal_gh_login`: 0 when `gh auth token >/dev/null 2>&1` succeeds (offline, counts `GH_TOKEN`), 1 when gh has no token or is missing. First check on a real gh that `GH_TOKEN=x gh auth token` succeeds and `GH_CONFIG_DIR=$(mktemp -d) gh auth token` fails; else fall back to `gh auth status`. `peal_gh_need_login WHAT INSTEAD` prints `peal: WHAT needs gh's login, and gh has none here (a Belfry session hides it); INSTEAD` and returns 1 when there is no login. `fake-gh` learns `auth token` (fails while `$FAKE_GH/no-auth` exists) and its `release` verbs honour `no-auth` (exit 4).

**Main-write** (`plugin/lib/main-write.sh`). Check at the top of `peal_push_main` when `_peal_mw_route` is `pr` (before `_peal_mw_fetch_branches` and the reuse lookup), and at the `auto` switch (around lines 205-209) before `continue`. Returns 1 (nothing written): no branch pushed, `peal.mainWrites` not set. INSTEAD: this main refuses direct pushes, so the write needs a pull request: run it where gh is logged in, or leave it to Belfry's own commands (apply runs on its host). The plain push route is unchanged.

**Ship** (`plugin/lib/ship.sh`). `peal_ship_publish` checks right after the `PEAL_GH_REPO` emptiness check (a non-GitHub remote still answers "the tag is the release"); returns 2. `_peal_ship_issue_items` checks too, so notes for an issues project refuse rather than come out empty. `bump`/`pin` refuse through `peal_push_main`; `wait` stays a read failing with `peal_gh`'s line. INSTEAD for publish names the release workflow Belfry dispatches (or a place where gh is logged in).

**Issues storage** (`plugin/lib/store-issues.sh`). `_peal_issues_need_login` at the top of every write entry point, before any git or GitHub change: create, edit, defer, set_milestone, comment, finish-retired, claim, release, takeover, record, milestone_state (apply refuses already; `finish … done` makes no gh call and is unchanged). Returns 2; INSTEAD points to Belfry's `tasks`/`task` tools. Reads unchanged.

**`plugin/commands/release.md`.** When a step refuses with "needs gh's login", stop and report that the release runs in the release workflow Belfry dispatches, or where gh is logged in, with the commands left. `commands.test.sh` checks it.

**Inventory test** (`plugin/lib/gh-callers.test.sh`). awk over `plugin/lib/*.sh` except `*.test.sh`, tracking the current function (`^name() {`), dropping comment lines and stripping `'…'`/`"…"` strings; a function counts when a line holds the word `peal_gh`, `_peal_ship_gh` or `gh` in command position (not `command -v gh`), word boundary `[^A-Za-z0-9_]` (so `peal_gh_failed`, `peal_gh_telemetry_env` do not count). Produces `file:function`; compared with the backticked function in the first column of the table after a marker comment in `docs/guides/belfry.md`; reports missing and stale rows by name. Also checks every `plugin/commands/*.md` with a `` `gh `` call (close, next, setup) is named in a list under the table. Self-checks on a scratch copy: new caller → missing row; row without a call → stale row; a `peal_err "… gh …"` string and `peal_gh_failed` not counted. About 38 rows today.

**Docs.** `docs/guides/belfry.md`: section "What a session can and cannot rely on" with the table grouped under command headings (function, file, what it calls, under Belfry: Belfry path / quiet degradation / unavailable + what instead), including revise unavailable on a protected main, doctor's expected "not logged in", ship's release as a workflow (0232). `docs/reference/cli.md`: the refusals under `ship publish` and main-writes. `docs/security.md`: gh boundary paragraph gains "writes that need a login refuse up front"; guard and harness lists add the new test. `docs/design.md`: one clause in the Belfry bullet.

**Ideas to queue** (`/peal:idea`, filed at close): a host-side `revise` command for projects whose main refuses direct pushes; the Belfry template offering a `workflow:` release action and a starter `release.yml` for any Peal project.

**Verification.** `main-write.test.sh` with no-auth and a remote refusing main: `pr` refuses, no `peal/main-write-*` on the remote, `peal.mainWrites` unset, main unchanged; `auto` same after the refused push; `push` goes through. `ship.test.sh`: no-auth publish refuses with no `RELEASE` in the fake log; non-GitHub remote still says the tag is the release; issues-project `ship notes` refuses. `store-issues.test.sh`: no-auth create, comment, defer, set-milestone, record, claim, release each refuse, fake log empty, release keeps worktree and branch; `finish ID done` still works. `commands.test.sh`: release.md names the refusal. `gh-callers.test.sh` as above. All of `tools/test-all.sh` and shellcheck.

Touches: plugin/lib/github.sh, plugin/lib/fake-gh, plugin/lib/main-write*.sh, plugin/lib/ship*.sh, plugin/lib/store-issues*.sh, plugin/lib/gh-callers.test.sh, plugin/commands/release.md, plugin/commands/commands.test.sh, docs/guides/belfry.md, docs/reference/cli.md, docs/security.md, docs/design.md.

Ranges relied on: `tasks/done/0176-under-belfry-close-opens-its.md:14-23,47-57,62-84`; `tasks/backlog/0227-the-issues-storage-records-a.md:14-33`; `tasks/backlog/0232-peal-release-as-a-workflow.md:12-40`; `plugin/lib/github.sh:46-102`; `plugin/lib/main-write.sh:18-34,109-263,302-331`; `plugin/lib/ship.sh:446-511,897-981`; `plugin/lib/store-issues.sh:1-50,895-1024`; `plugin/lib/store-files.sh:218-241`; `plugin/lib/fake-gh:37-64,112-117`; `plugin/lib/doctor.sh:200-230`; `plugin/lib/close.sh:520-723,847-900`; `plugin/commands/release.md:54-100`; `plugin/commands/commands.test.sh:1-32`; `docs/guides/belfry.md:38-65`; `docs/design.md:51-57,106-125`; `docs/security.md:351-374,395-408`; `docs/reference/cli.md:9-10,721-731`.

---

## Outcome

Built as planned, on opus.

- `plugin/lib/github.sh` gains `peal_gh_login`, an offline `gh auth token` probe. It was checked on gh 2.45: it fails with an empty `GH_CONFIG_DIR` and succeeds with `GH_TOKEN`, so it also passes in a release workflow. It also gains `peal_gh_need_login WHAT INSTEAD`, which prints the one shared refusal line. `fake-gh` fakes `auth token`, and its `release` verbs honour `no-auth`.
- Without a login, these refuse before any change:
  - main-write's pull request route, under `pr` and at the `auto` switch (status 1, no `peal/main-write-*` branch pushed, `peal.mainWrites` unset);
  - `peal ship publish` and an issues project's ship notes (status 2);
  - every write of the issues storage (status 2, pointing to Belfry's `tasks`/`task` tools).
- With a login, all of these behave as before.
- `plugin/commands/release.md` stops on the refusal and says the release belongs in the workflow Belfry dispatches (0232), or where gh is logged in.
- `docs/guides/belfry.md` has a new section, "What a session can and cannot rely on". It holds the inventory: one row per function in `plugin/lib/*.sh` that calls gh (38 rows today), between the `gh-callers` marker comments, plus the command files that call gh themselves. `plugin/lib/gh-callers.test.sh` keeps that list complete. It fails on a missing, stale or dropped row and on an unlisted command file, and it does not count strings, `peal_gh_failed` or `command -v gh`.
- The CLI reference, `docs/security.md` and `docs/design.md` describe the refusals.

Decided with the human: releases under Belfry run as a GitHub workflow, not in a session, so the Belfry template in `init.sh` is unchanged. The issues storage refuses only its writes. Doctor stays as it is. Revise is documented as unavailable on a protected main.

Found and left, each filed as an idea:
- a host-side revise for projects whose main refuses direct pushes;
- the Belfry template offering a workflow release action and a starter `release.yml`, after 0232.

For the next session:
- Through the CLI, `claim`, `release` and `record` on an issues project fail first on the task read (`peal_gh`'s "gh has no login", status 2), still before any change. The storage-level refusal is tested on the store functions directly.
- shellcheck was not available locally, so CI is its first run; check the file-level SC2016 disable in `gh-callers.test.sh`.
- 0227 moves the issues storage's `record` from refused to `task_record`, and updates its inventory row.

The review found nothing blocking. Four minor findings were fixed on the branch:
- the inventory's test now also counts `gh` after `if`, `while`, `until`, `!`, `env` and `NAME=value`;
- the probe says gh is needed when gh is missing;
- `commands.test.sh` no longer counts ship's refusals exactly;
- two doc nits.

### Reviewer findings not acted on

- In `peal_store_create` and `peal_store_comment` the login check comes after the argument checks. Kept: a misuse still answers first, and nothing changes before the check.
