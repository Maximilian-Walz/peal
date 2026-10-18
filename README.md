# Peal

*A peal is a full, ordered ringing of changes on a set of bells: here, a backlog worked
through in order.*

When you build a project with [Claude Code](https://claude.com/claude-code), the list of
what to do next tends to live in your head, in chat history, or in a tracker you have to
leave the terminal to open. Work started in one session is hard to pick up in the next,
and two pieces of work in one checkout get tangled.

Peal is a process for that. Each piece of work is a *task*, kept where the project
already lives, and Peal adds a few commands to Claude Code that take a task through the
same steps every time: an idea, a plan you agree, a build on its own branch, a review,
and a pull request you merge.

Where the tasks are kept is one choice, and Peal supports two today: Markdown files in
the repository (a short file with a small header of fields at the top, called YAML
frontmatter, reviewed and versioned like your code), or GitHub issues. The process is the
same either way; the examples below show the files.

## One task, start to finish

Here is a whole round trip. You type the lines that start with `>`; the rest is what
Peal prints. The second command carries the task all the way to a pull request.

<!-- docs-check: shape -->
```text
> /peal:idea a health check endpoint
filed 0001 tasks/backlog/0001-health-check.md — milestone: -, plan: -, size: S — "Add a health check"

> /peal:work 0001
claimed 0001 task/0001-health-check ../myproject-wt/0001-health-check
  ... the plan, for you to agree; then the build in a subagent; then the review ...
closed 0001: pull request #12 https://github.com/you/myproject/pull/12
```

1. `/peal:idea` writes your thought down as a task, here a file in `tasks/backlog/`. The
   line it prints names the file and its fields: a *milestone* (a goal that
   groups tasks, such as a release you are working toward; `-` means none yet), a plan
   (whether one is needed) and a size. You can ignore them for now.
2. `/peal:work` *claims* the task: it gives it its own git branch and a second checkout
   of your repository in a separate folder (git calls that a *worktree*), so your own
   checkout and other tasks are left alone. A planner *subagent* (a helper session Claude
   starts for one job) writes a plan, which you read and agree or change. Only after
   that does an implementer subagent build it.
3. When the build is done, the same session closes the task itself, without you typing
   anything: a reviewer subagent checks the change, the result is recorded in the task,
   and the pull request is opened. You look it over and merge it.

You stay in charge at two points: you agree the plan, and you merge the pull request.
Nothing merges by itself. The close step is also a command, `/peal:close`, which you can
run by hand, for instance in a session you drive yourself.

## What Peal is not

It is not a tracker with a screen of its own, and it does not replace GitHub issues: it
can keep the tasks in them, or in files. It is not an autonomous agent. And it works without Belfry, a separate tool described [below](#peal-and-belfry).

## Start

Install the plugin in a Claude Code session:

<!-- docs-check: install -->
```text
/plugin marketplace add Maximilian-Walz/peal
/plugin install peal@peal
```

Then run `/peal:setup` in your repository. [Getting started](docs/getting-started.md)
walks you through that and through your first task; read it next.

When you want more, the [guides](docs/guides/README.md) take each workflow in turn and
the [reference](docs/reference/README.md) lists every command and setting. If your
project already has its own task-file process, [migrating](docs/migrating.md) shows how
to bring it over.

## Peal and Belfry

Peal works on its own: every command runs in an ordinary Claude Code session.
[Belfry](https://github.com/Maximilian-Walz/belfry) is a separate, self-hosted tool that
runs Claude Code sessions unattended and gathers the decisions they need from you into one
inbox. Peal provides the commands Belfry's task contract asks for; neither depends on the
other. If you want that, [running under Belfry](docs/guides/belfry.md) says how to set it
up.

## Status

Peal is before its first stable version. The [milestones](docs/milestones/) are the
roadmap.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md). MIT, see [LICENSE](LICENSE).
