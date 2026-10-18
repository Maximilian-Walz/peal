# Getting started

This page takes you from nothing installed to your first task worked, reviewed and ready
to merge. It assumes you use [Claude Code](https://claude.com/claude-code) in a git
repository, and nothing else: you do not need to know anything about Peal or Belfry yet.

Peal is a plugin for Claude Code. It keeps your to-do list as small Markdown files in the
repository (each one a *task*) and adds commands, whose names start with `/peal:`, that you
type into a Claude Code session to file, plan, build and close those tasks.

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

Peal reads the repository and suggests where your tasks should live: as files in a
`tasks/` folder, which is the usual choice, or as GitHub issues. It asks you once. It then
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

A task goes through three commands. Here they are for a small example.

### 1. File an idea

Type `/peal:idea a health check endpoint`. You see a line starting `filed 0001`. Peal has written a file, `tasks/backlog/0001-...md`,
holding your sentence and a template to fill in. The folder `backlog/` is where tasks wait
until someone starts them, and `0001` is the task's number. An idea is simply a task you
filed roughly; nobody has planned it yet. Open the file if you like: it is plain
Markdown, and you can edit it. If you file an idea while on another task's branch, it is queued and
filed when that task closes.

### 2. Work it

Type `/peal:work 0001`. This is where Peal does most of its work, and where it keeps your other work safe:

- It *claims* the task: it creates a new git branch, `task/0001-...`, and a second
  checkout of your repository in a separate folder next to it (git calls this a
  *worktree*). Your own checkout stays as it was, so you can keep working there, and
  several tasks can be worked at once without mixing.
- It asks a helper, a Claude *subagent* called the planner, to read the task and the code
  and write a plan. You see the plan and answer any questions in it. Nothing is built
  until you agree.
- Once you agree, another subagent, the implementer, builds the plan in the worktree and
  commits as it goes.

Without a number, `/peal:work` offers you the next task in the backlog.

### 3. Close it

Type `/peal:close`. Closing has a reviewer subagent check the changes against the task, writes a short
summary of the result into the task file (its *Outcome*), moves the task to `done/`, and
opens a pull request. It then waits for the pull request's checks to pass. You read the
pull request and merge it; Peal never merges for you.

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
