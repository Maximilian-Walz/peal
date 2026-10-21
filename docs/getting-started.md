# Getting started

This page takes you from nothing installed to your first task worked, reviewed and ready
to merge. It assumes you use [Claude Code](https://claude.com/claude-code) in a git
repository, and nothing else: you do not need to know anything about Peal or Belfry yet.

Peal is a plugin for Claude Code. It is a process for the work on a project: each piece
of work is a *task*, and Peal adds commands, whose names start with `/peal:`, that take a
task from an idea through a plan you agree, a build on its own branch and a review to a
pull request you merge. Where the tasks are kept is a choice between two backends today:
Markdown files in the repository, or GitHub issues. The steps below are the same for
both, and the examples show the files.

## Install

A plugin is added to Claude Code from inside a session. Type these two lines into one:

<!-- docs-check: install -->
```text
/plugin marketplace add Maximilian-Walz/peal
/plugin install peal@peal
```

The first line tells Claude Code where to find Peal; the second installs it. This follows
Peal's `main` branch, so you get changes as they land. To stay on a released version
instead, see [pinning a release](guides/setting-up.md#pin-a-release).

## Set up

In the repository you want to use Peal in, type `/peal:setup`

Peal reads the repository and suggests where your tasks should live, as Markdown
files in a `tasks/` folder or as GitHub issues (the storage; both work the same from the
commands' side). It asks you once. It then
prepares everything as a single commit on a new branch called `peal/setup-tasks`, for you
to look at. It never commits to your main branch (the branch your finished work lands on,
usually `main`).

When it has written the commit, it suggests one or two first tasks based on what it found
in your repository, and says what you can do next.

Merge that branch into your main branch before you go on. Setup offers to open the pull
request for you. This matters because Peal starts every task from the main branch, so a
task cannot begin until the setup is there.

Setup works in stages, and this first one, `tasks`, is all you need. Later you can add
guards for commit messages, milestones, or Belfry (a separate tool that runs Claude Code
sessions unattended). [Setting up in stages](guides/setting-up.md) lists them and how
to take each back, and `/peal:next` suggests when one is worth adding.

## Your first task

A task goes through three steps, two of them commands you type. Here they are for a small
example.

### 1. File an idea

Type `/peal:idea a health check endpoint`. You see a line starting `filed 0001`. Peal has written the task, here a file `tasks/backlog/0001-...md`
(with GitHub issues it opens an issue instead), holding your sentence and a template to fill in. The folder `backlog/` is where tasks wait
until someone starts them, and `0001` is the task's number. An idea is simply a task you
filed roughly; nobody has planned it yet. Open the file if you like: it is plain
Markdown, and you can edit it. The file is committed to the main branch on your remote, not into your checkout:
update your checkout (`git pull`) to see it there. (If your main branch refuses direct pushes, the idea arrives as a small
pull request instead and shows up once that is merged.) If you file an idea while on another task's branch, it is queued and
filed when that task closes.

### 2. Work it

Type `/peal:work 0001`. This is where Peal does most of its work, and where it keeps your other work safe:

- It *claims* the task: it creates a new git branch, `task/0001-...`, and a second
  checkout of your repository in a separate folder next to it (git calls this a
  *worktree*). Your own checkout stays as it was, so you can keep working there, and
  several tasks can be worked at once without mixing.
- It asks a helper, a Claude *subagent* called the planner, to read the task and the code
  and write a plan. It decides the technical questions itself and asks you only what is
  yours (what the work is for, what you see or use, money, security, a recorded
  decision); you see its decisions afterwards in the task's Notes. When it has no
  question for you, the build starts without stopping. A task with `plan: required`
  waits until you agree the whole plan.
- Once the plan is agreed, another subagent, the implementer, builds the plan in the worktree and
  commits as it goes.

An idea comes out with `plan: auto` (or `skipped` for plainly trivial work), empty *Scope* and *Done when* sections, and its
open questions in the Notes. For a `skipped` task no planner runs: the implementer reads the
task and, if it cannot tell what to build, stops and asks you, with a proposed answer for
each question. Reply, and your answers go into the task and the build goes on. (A task with
`plan: auto` or `required` gets the planner first, as described above.)

Without a number, `/peal:work` offers you the next task in the backlog. When the build
is done it carries on to the close, described next.

### 3. Review and pull request

You do not type anything for this step. When the implementer is done, the same session
closes the task: a reviewer subagent checks the changes against the task, a short summary
of the result is written into the task (its *Outcome*), the task is moved to `done/`
(with files), and a pull request is opened. The session then waits for the pull request's
checks to pass. You read the pull request and merge it; Peal never merges for you.

Closing is also a command, `/peal:close`. You would run it by hand only in a session you
drive yourself, for instance one that stopped before the close.

Opening the pull request needs the `gh` command line tool, logged in to GitHub.

To see the backlog at any time, run `.peal/peal list` in a terminal (the plain `peal` command is only on the path inside Claude Code).

## Next

- Add the other stages and let `/peal:next` suggest what to adopt:
  [setting up in stages](guides/setting-up.md).
- Work with tasks day to day: the [guides](guides/README.md), starting with
  [working a task](guides/working-a-task.md).
- Look up a command, a setting or a task field: the [reference](reference/README.md).
- Already have your own task process: [migrating an existing project](migrating.md).
- Why Peal is built this way: [the design](design.md).
