# Running under Belfry

[Belfry](https://github.com/Maximilian-Walz/belfry) is a self-hosted control plane that
runs Claude Code sessions unattended and gathers what they need from you into one inbox.
Peal works without it, and Belfry knows nothing of Peal: they meet at a small written
contract, `.belfry.yml`. The reasons are in
[the design](../design.md#peal-and-belfry).

## Set it up

Set up the `tasks` stage first, then `peal init --stage belfry` (or `/peal:setup belfry`)
writes the contract. For task files it is (abridged):

<!-- docs-check: run -->
```text
$ peal init --stage tasks >/dev/null
$ peal init --stage belfry
created .belfry.yml
$ cat .belfry.yml
tasks:
  backend: commands
  commands:
    list: .peal/peal list
    offer: .peal/peal offer "{pool}" --top 10
    claim: .peal/peal claim {task} --print-path
    start: /peal:work {task}
    idea: /peal:idea {idea}
    board: .peal/peal board
    apply: .peal/peal apply
    # What apply carries out; Belfry offers and sends only these.
    apply_kinds: [file, move, priority, depends, retire, milestone_create, milestone_update, milestone_state, split_milestone]
policy:
  max_code_jobs: 2
  # Belfry's own never-list already covers .belfry.yml, .github/** and .claude/**.
  never_auto_merge: [.peal/**]
```

Each line names a `peal` subcommand or a `/peal:` command that Belfry runs for you: it
lists and offers tasks, claims one and starts a session on it, files an idea, draws the
board, and writes the changes a milestone action, a dismissed proposal, a deferral or a
triage run ends with as one commit ([`peal apply`](../reference/cli.md#peal-apply)). For a project
whose tasks are GitHub issues, the contract names the `github-issues` backend instead.

## What changes for a session

- **Claimed before it starts.** Belfry claims the task, then starts a session in its
  worktree; `/peal:work` sees it is there and claims nothing. The claim is idempotent, so
  a job that runs again continues where the last stopped.
- **Finished means a pull request open and green.** `/peal:close` waits for the checks
  (with Belfry's `wait_ci` tool, which spends none of your GitHub budget; `peal close
  wait` without it), and the merge is yours, or the task's, if you agreed `merge: auto` with its plan and
  Belfry's policy for the project allows it (its `auto_merge` policy, which Belfry
  documents), once Belfry acts on its own record of your answer (belfry#729); until then
  the merge of a plan-agreed task is yours. Peal's board never grants `merge` from a
  claim branch's copy, and no session writes the field (`docs/security.md`).
- **No GitHub login in the session.** Belfry hides the worker's `gh` login from its
  sessions. `/peal:close` opens the pull request through Belfry's `pr_create` tool
  (`peal close finish --pr-by-tool`, then `peal close opened N URL`), opens no early
  draft, files queued ideas through `task_create`, and reruns a flaky CI failure once with
  an empty commit. A re-run of finish cannot update an open pull request's body (Belfry
  has no `pr_update` yet). `peal list` shows `pr:unknown` without a warning, and
  `peal close verify` answers `BLOCKED:no-gh-login`, where the session trusts `wait_ci`.
- **Questions reach the inbox.** A question that would stop an interactive session goes
  to Belfry's inbox instead.
- **Ideas go through Belfry.** Off a task branch, `/peal:idea` files through Belfry's
  own `task_create` tool, never the shell; on a task branch it queues as usual.

## What a session can and cannot rely on

A session can rely on git: its own branch, its pushes, the task files, and a write onto a
main branch that takes direct pushes. It can rely on Belfry's tools for what needs GitHub:
`pr_create`, `wait_ci`, `ci_log`, `task_create`, `tasks` and `task`. It cannot rely on
anything that needs `gh`'s login, which Belfry hides. Peal asks `gh auth token` first, so
a write that needs the login refuses before it changes anything, with `needs gh's login,
and gh has none here` and what to do instead, rather than failing halfway. In a GitHub
workflow, gh has the run's token, so the same writes go through there.

Every shell function of Peal that calls `gh` is listed below, by the command it serves,
with what it does under Belfry: a **Belfry path** (one of its tools stands in), **quiet**
(it does without, saying nothing or `unknown`), **refused** (it stops up front with the
reason), or **unavailable** (it fails on `gh has no login`, with what to do instead).
`plugin/lib/gh-callers.test.sh` keeps the list complete: a new caller fails it until it
has a row here.

<!-- gh-callers -->

### Every command

| Function | File | Calls | Under Belfry |
|---|---|---|---|
| `peal_gh` | `github.sh` | `gh api` | The one way to GitHub's API. Without a login it fails with status 4 and `gh has no login`; a verdict says `BLOCKED:no-gh-login`. |
| `peal_gh_login` | `github.sh` | `gh auth token` | Offline. There is no token, so the writes marked refused below stop up front. |
| `peal_pr_checks` | `github.sh` | `gh api` check runs and statuses | Unavailable: `BLOCKED:no-gh-login`. A session waits with `wait_ci` instead. |

### `/peal:close`

| Function | File | Calls | Under Belfry |
|---|---|---|---|
| `peal_close_finish` | `close.sh` | `gh api` pulls, GraphQL | Belfry path: `--pr-by-tool`, and `pr_create` opens the pull request. A re-run cannot update an open pull request's body. |
| `_peal_close_verify` | `close.sh` | `gh api` pulls, checks | Belfry path: `peal close verify` answers `BLOCKED:no-gh-login`, and the session trusts `wait_ci`. |

### `peal list`, `peal offer`, `peal board` and the reads of the issues storage

| Function | File | Calls | Under Belfry |
|---|---|---|---|
| `_peal_files_prs` | `store-files.sh` | `gh pr list` | Quiet: a task awaiting merge shows `pr:unknown`, with no warning. |
| `_peal_issues_listed` | `store-issues.sh` | `gh api` issues | Unavailable: read the tasks with Belfry's `tasks` and `task` tools. |
| `_peal_issues_prs` | `store-issues.sh` | `gh api` pulls | Unavailable, as above. |
| `_peal_issues_issue` | `store-issues.sh` | `gh api` one issue | Unavailable, as above. |
| `_peal_issues_edits_batch` | `store-issues.sh` | `gh api graphql` | Unavailable, as above. |
| `_peal_issues_milestone_rows` | `store-issues.sh` | `gh api` milestones | Unavailable, as above. |
| `peal_store_milestone_text` | `store-issues.sh` | `gh api` a milestone | Unavailable, as above. |

### The writes of the issues storage

`peal create`, `revise`, `set-milestone`, `comment`, `retire`, `defer`, `claim`, `release`,
`record` and `milestone-state` refuse up front: Belfry writes an issues project's tasks
through its own GitHub client. Where the command reads the task first (`claim`,
`release`, `record`), that read fails on `gh has no login` before the refusal.

| Function | File | Calls | Under Belfry |
|---|---|---|---|
| `_peal_issues_post` | `store-issues.sh` | `gh api` issues | Refused. |
| `_peal_issues_comment` | `store-issues.sh` | `gh api` comments | Refused. |
| `_peal_issues_labels` | `store-issues.sh` | `gh api` labels | Refused. |
| `_peal_issues_current_labels` | `store-issues.sh` | `gh api` one issue | Refused, as part of `record`. |
| `_peal_issues_label_claim` | `store-issues.sh` | `gh api` labels | Refused. Belfry labels its own claim. |
| `_peal_issues_unlabel` | `store-issues.sh` | `gh api` labels | Refused. |
| `_peal_issues_retire` | `store-issues.sh` | `gh api` issues | Refused. |
| `peal_store_set_milestone` | `store-issues.sh` | `gh api` issues | Refused. |
| `peal_store_milestone_state` | `store-issues.sh` | `gh api` milestones | Refused. |

### Writes onto a main branch that refuses direct pushes

The task-file storage's writes (`peal create`, `revise`, `set-milestone`, `retire`,
`defer`, `milestone-state`), the decisions index, `peal apply`, and `peal ship bump` and
`pin` go onto main. A plain push works in a session. A main that refuses direct pushes
needs a pull request from a `peal/main-write-*` branch, and `pr_create` opens one only
from the job's own branch. So that route refuses before it pushes any branch: run the
write where gh is logged in, or leave it to Belfry's own commands, which run on its host
(`peal apply`). `peal revise` on such a main is unavailable in a session.

| Function | File | Calls | Under Belfry |
|---|---|---|---|
| `peal_push_main` | `main-write.sh` | `gh api` pulls | Refused on the pull request route (`main-writes: pr`, or `auto` once the push is refused); the push route is unchanged. |
| `_peal_mw_pr` | `main-write.sh` | `gh api` pulls | Never reached: `peal_push_main` refuses first. |
| `_peal_mw_pr_manage` | `main-write.sh` | `gh api` pulls, GraphQL | Never reached. |
| `_peal_mw_find_reuse` | `main-write.sh` | `gh api` pulls | Never reached. |
| `_peal_mw_rivals` | `main-write.sh` | `gh api` pulls | Never reached. |
| `_peal_mw_drop` | `main-write.sh` | `gh api` pulls | Never reached. |
| `_peal_mw_merged` | `main-write.sh` | `gh api` refs | Never reached. |
| `_peal_mw_merge_self` | `main-write.sh` | `gh api` pulls | Never reached. |
| `_peal_mw_wait_merged` | `main-write.sh` | `gh api` pulls | Never reached. |
| `_peal_mw_automerge_off` | `main-write.sh` | `gh api graphql` | Never reached. |

### `peal ship` and `/peal:release`

Under Belfry, a release runs as the GitHub workflow Belfry's release action dispatches,
where gh has the run's token; no session releases (task 0232).

| Function | File | Calls | Under Belfry |
|---|---|---|---|
| `peal_ship_publish` | `ship.sh` | `gh release` | Refused before any `gh release` call. A remote not on GitHub still answers that the tag is the release. |
| `_peal_ship_gh` | `ship.sh` | `gh release` | Never reached: `peal_ship_publish` refuses first. |
| `_peal_ship_issue_items` | `ship.sh` | `gh api` issues, pulls | Refused: the notes of an issues project. |
| `_peal_ship_runs` | `ship.sh` | `gh api` workflow runs | Unavailable: `peal ship wait` fails on `gh has no login`. Use `wait_ci` and `ci_log`, or the workflow. |
| `_peal_ship_report` | `ship.sh` | `gh api` job logs | Unavailable, as above. |

### `peal doctor`

| Function | File | Calls | Under Belfry |
|---|---|---|---|
| `_peal_doctor_stage_gh` | `doctor.sh` | `gh auth status` | Says `gh is not logged in`: expected under Belfry, nothing to fix. |

### `peal init` and `/peal:setup`

| Function | File | Calls | Under Belfry |
|---|---|---|---|
| `_peal_init_survey_gh` | `init.sh` | `gh api` | Quiet: the survey's GitHub counts say `unknown`. |

### Commands that call gh themselves

- `/peal:close`: its draft pull request, its look at the checks and its rerun of a failed
  run have a Belfry path: no draft, `pr_create`, `wait_ci`, and an empty commit for the
  one rerun.
- `/peal:next`: a declined suggestion's pull request is unavailable; the decline waits
  for a session where gh is logged in.
- `/peal:setup`: the issue sample and the setup's pull request are unavailable; set up
  from a session where gh is logged in.

<!-- /gh-callers -->

## Actions

The file ends with two commented-out actions. Uncomment `milestone-review`, and Belfry
offers the review when a milestone's tasks are done; uncomment `release`, and the
Releases tab's button runs [`/peal:release`](releases.md). `peal board` prints what
Belfry draws its lanes from ([CLI](../reference/cli.md#peal-board)).

## Auto-merge and `merge: auto`

Belfry's `auto_merge` policy can merge two kinds of pull request without you that
together open a way around you: one that touches only task files, and the pull request of
a task marked `merge: auto`. A task-files pull request could write `merge: auto` into
another task, which you mean to write only when agreeing its plan. Before you allow both,
add Peal's merge gate:

1. Copy `plugin/templates/merge-gate.yml` from Peal to `.github/workflows/merge-gate.yml`.
   It runs [`peal merge-gate`](../reference/cli.md#peal-merge-gate) on every pull request,
   with Peal pinned by SHA, and fails one in which a task file under `backlog/` or
   `doing/` gains a `merge` key. The command ships in the first release after v0.7.0;
   the template pinned to v0.7.0 fails every pull request, so copy it from that release on.
2. Make its job, `peal merge-gate`, a required check of the main branch.
3. List `peal merge-gate` in the `checks` of every `auto_merge` rule.
4. Keep `.github/**` merged by you (Belfry already never auto-merges it): the gate is
   only as strong as the workflow that runs it.

The direct pushes of `peal revise` and `peal comment` reach main without a pull request,
so the gate does not see them; [the security model](../security.md#auto-merge-tiers)
names that limit.
