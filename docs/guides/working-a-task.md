# Working a task

[Getting started](../getting-started.md) took one task from idea to pull request. This
page is what happens between, and what to do when a step does not go as planned.

<!-- docs-check: shape -->
```text
> /peal:idea a health check endpoint
filed 0001 tasks/backlog/0001-health-check.md — milestone: -, plan: -, size: S — "Add a health check"

> /peal:work 0001
claimed 0001 task/0001-health-check ../myproject-wt/0001-health-check
  ... the plan, for you to agree; then the build in a subagent ...

> /peal:close
closed 0001: pull request #12 https://github.com/you/myproject/pull/12
```

## Plan, build, close

[`/peal:work`](../reference/commands.md#pealwork) claims the task and enters its
worktree. If the task's `plan` field says so, a planner reads the task and the code and
proposes a plan; it also asks whatever it could not settle from the code. Read it as you
would a design: the questions are where the task is vague. Once you agree, the plan goes
into the task's `## Plan` and an implementer builds it, committing as it goes. It hands
back `DONE`, or a `QUESTION` with a proposed default for each; your answers go back to it.

[`/peal:close`](../reference/commands.md#pealclose) then has a reviewer read the diff
against the task's `## Done when`. Each finding is fixed, filed as a new idea, escalated
to you, or rebutted in writing. The Outcome records what was done and how it was
checked, the task moves to `done/`, and the pull request opens. The command waits until
its checks are green, and you merge it. A project that has agreed it can let one task
merge itself: say so while agreeing the plan, and the plan records `merge: auto`.

## When something fails

- **A check fails at commit or close.** The commit is refused, or the close stops and
  says which check. Fix the cause and run the command again; it resumes.
- **The session stops.** Run `/peal:work` in the task's worktree. It resumes that task
  and claims nothing. Elsewhere, `peal list` shows the claim states
  ([Tasks](../reference/tasks.md#claim-states)).
- **The task cannot go on.** Give the claim back with `/peal:defer`, or cut the task
  with `/peal:split`; both are in [the backlog guide](backlog.md).

The claim is a branch, a worktree and a moved file. Underneath it looks like this, in a
repository with a remote. `peal work` prints what `/peal:work` reads next:

<!-- docs-check: run -->
```text
$ peal init --stage tasks
$ git add -A && git commit -qm "chore(peal): set up the tasks stage"
$ git push -q -u origin main
$ printf -- '---\nsize: S\n---\n\n# NNNN — Add a health check\n\n## Raw\n\n> a health check\n' | peal idea health-check
filed 0001 tasks/backlog/0001-health-check.md — milestone: -, plan: -, size: S — "Add a health check"
$ peal claim 0001
claimed 0001 task/0001-health-check …
$ cd ../repo-wt/0001-health-check && peal work
TASK 0001 tasks/doing/0001-health-check.md
PLAN skipped
```

The repository here is called `repo`, so its worktrees lie in `../repo-wt`; the setting
is `worktrees` ([Configuration](../reference/configuration.md#settings)). The steps of a
close are in [`peal close`](../reference/cli.md#peal-close).
