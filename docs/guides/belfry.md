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
    milestone: .peal/peal milestone-state {id} {state} --reason {reason}
    retire: .peal/peal retire {task} --reason {reason}
    defer: .peal/peal depend {task} {on}
```

Each line names a `peal` subcommand or a `/peal:` command that Belfry runs for you: it
lists and offers tasks, claims one and starts a session on it, files an idea, draws the
board, changes a milestone, retires a task or records that one waits for another from its own
screens ([`peal depend`](../reference/cli.md#peal-depend)). For a project
whose tasks are GitHub issues, the contract names the `github-issues` backend instead.

## What changes for a session

- **Claimed before it starts.** Belfry claims the task, then starts a session in its
  worktree; `/peal:work` sees it is there and claims nothing. The claim is idempotent, so
  a job that runs again continues where the last stopped.
- **Finished means a pull request open and green.** `/peal:close` waits for the checks,
  and the merge is yours, or the task's, if it says `merge: auto` and Belfry's policy for
  the project allows it (its `auto_merge` policy, which Belfry documents).
- **Questions reach the inbox.** A question that would stop an interactive session goes
  to Belfry's inbox instead.
- **Ideas go through Belfry.** Off a task branch, `/peal:idea` files through Belfry's
  own `task_create` tool, never the shell; on a task branch it queues as usual.

## Actions

The file ends with two commented-out actions. Uncomment `milestone-review`, and Belfry
offers the review when a milestone's tasks are done; uncomment `release`, and the
Releases tab's button runs [`/peal:release`](releases.md). `peal board` prints what
Belfry draws its lanes from ([CLI](../reference/cli.md#peal-board)).
