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
