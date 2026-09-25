---
description: Set this project up for Peal, one stage at a time. Without a stage, the first one: reads the repository, recommends where tasks live and asks once, writes the setup as one commit to review, and offers one or two first tasks. With a stage (tasks, guardrails, milestones, belfry), sets up that one.
argument-hint: "[tasks | guardrails | milestones | belfry]"
---

Arguments: `$ARGUMENTS`, a stage: `tasks`, `guardrails`, `milestones` or `belfry`. None
means the first setup: the `tasks` stage, and nothing more.

`peal` is Peal's CLI, on the Bash tool's path. `peal init --stage STAGE` writes a stage,
deterministically and safe to run again; this command reads the repository, decides the
options, asks the human only what it cannot infer, and commits what the stage wrote. It
never sets up a stage the human did not ask for: the later ones are named at the end,
for the human to take when they want them.

## 1. What is there

Run `peal init --survey`. It writes nothing and prints one `key value` line each:
`stages` (set up, comma list), `next` (the first stage not set up), `storage` (`-` before
the `tasks` stage), `branch <name> main <main>`, `github` (owner/name, `-` for none),
`issues` and `milestones` (open ones on GitHub, or `unknown: why`), `closes` (recent
commits that close an issue), `readme`, `todo` (TODO lists), `todo-marks` (TODO and
FIXME marks in the code), `ci`, `taskdir` (a tasks directory already there, with its file
count), `belfry` (`peal`, `other` or `-`) and `recommend` (the storage to recommend).

Then decide the stage:

- **No argument, `tasks` already set up:** nothing to do unasked. Say what is set up and
  that `/peal:setup <next>` sets up the next stage (`next` from the survey), and stop.
- **No argument otherwise:** the stage is `tasks`.
- **A stage other than `tasks` while `tasks` is not set up:** say `/peal:setup` comes
  first, and stop.
- **A stage already set up:** run it again; it is safe, and repairs what a fresh clone
  lacks (the `guardrails` stage's git hooks are each clone's own).
- **Not a stage:** name the four, and stop.

## 2. Where the commit goes

The setup is one commit, for the human to review before it reaches the main branch;
never commit on it. Note `git status --porcelain` now: the human's own changes stay out
of the commit.

- On the main branch (`branch` equals `main`), or on a detached HEAD: `git switch -c
  peal/setup-<stage>` (a name already taken: `peal/setup-<stage>-2`, and so on).
- On another branch: commit there; it is the human's.

## 3. The stage

### `tasks`

1. **Read the repository**: the README, the TODO lists, a sample of the TODO marks
   (`git grep -n -w -E 'TODO|FIXME' | head -n 30`), the CI files, and on GitHub up to
   twenty open issues (`gh issue list --limit 20`) and the last commits that close one.
   This is for recommending the storage and for the first tasks (step 5); do not
   summarise it back to the human.
2. **Recommend the storage.** `recommend` is the survey's rule: `issues` when the
   project is on GitHub and already works from issues (open issues, or commits closing
   some), so nothing moves; `files` otherwise (task files in the repository, next to the
   code, no GitHub needed). Override it only on evidence the rule cannot see, and say
   which. The `issues` storage needs `gh`, logged in: `issues unknown: ...` says it is
   not; recommend it then only with a note that `gh auth login` comes first.
3. **Ask once**, with `AskUserQuestion`: "Where should Peal keep this project's tasks?".
   The question holds your recommendation's reason in two sentences, from what you read
   ("42 open issues and most commits close one: the tasks stay where they are."), and
   what the stage will write: `.peal/config.yml`, the launcher `.peal/peal`, the lines
   in `.claude/settings.json` that enable Peal for everyone on the project, and for task
   files the `tasks/` directories with `TEMPLATE.md`. Options: the recommended storage
   first, labelled `(Recommended)`, then the other. A `taskdir` line means a tasks
   directory is there already: say that its files stay as they are and that adopting an
   existing task process is a migration of its own, not this setup.
4. **Write it:** `peal init --stage tasks --storage <files|issues>`. No `--label`: the
   issues opened by someone with write access are the tasks, the safe default on a
   public repository. Status 1 means `.claude/settings.json` does not parse: the rest is
   written, and the lines it printed go into the report for the human to add by hand.
   Any other failure: report it and stop.

### `guardrails`

`peal init --stage guardrails`: Peal's git hooks for this clone (no commit on the main
branch, the commit subject grammar, the project's checks before a commit). The commit
holds only the `stages:` line: the hooks are each clone's own, so tell the human that
every clone runs `/peal:setup guardrails` (or `.peal/peal hooks install`) once.

### `milestones`

1. **For task files**, when `peal milestones` lists none: ask for the first milestone's
   title with `AskUserQuestion`, offering one or two titles from what the README or a
   roadmap says the project is working towards, then "First milestone". Run `peal init
   --stage milestones --title "<title>"`, and tell the human that `m1.md`'s goal and
   acceptance criteria are theirs to write. With milestones there already, run `peal
   init --stage milestones`: it keeps them.
2. **For issues**, run `peal init --stage milestones`: the repository's milestones on
   GitHub are the milestones, nothing is written but the record.
3. **The review task.** Find the `current` milestone in `peal milestones`. When no task
   of `peal board --no-pr` has that milestone and `milestone` in its `depends`, offer
   with `AskUserQuestion` to file its review task (step 5's form, `milestone: <id>`,
   `depends: [milestone]`, titled "Review milestone <title>", its Intent to run
   `/peal:milestone-review <id>` once every other task of the milestone is done). A task
   file's milestone must be on the main branch first: when `peal create` refuses the
   milestone as unknown, say the review task is offered again by `/peal:setup
   milestones` once the setup commit is merged.

### `belfry`

1. `peal init --stage belfry`. Status 1 means a `.belfry.yml` that is not Peal's: show
   the contract it printed, say the human merges it into their file by hand, and stop
   without a commit.
2. The file ends with Peal's actions as comments. When the `milestones` stage is set up,
   ask with `AskUserQuestion` whether Belfry should offer the milestone review when a
   milestone is closed; on yes, uncomment the `actions:` line and the `milestone-review`
   action (its four lines, the comment marks only). The `release` action stays a comment
   unless the human asks for it. Tell the human that `peal init --remove belfry` refuses
   a file changed since, so it is theirs to remove then.
3. The human steps Belfry needs, for the report: add the project in Belfry, and run
   `belfry check` on the file once Belfry has it (the stage says it skipped the check).

## 4. The commit

Stage exactly the paths the stage printed as `created`, `updated` or `removed` (file
paths; `removed` ones with `git add -A -- <path>`), `.peal/config.yml` (every stage
records itself there, unprinted), and any file you edited in step 3; nothing the status
noted in step 2 showed. Then:

```bash
git commit -m "chore(peal): set up the <stage> stage" -m "<the stage's output lines>"
```

`chore(peal)` is the subject Peal's commit gate lets through without a task id, for
exactly the paths `peal init` writes. Nothing staged (the stage was set up already):
no commit; say so, and skip step 6. Show the human `git show --stat HEAD`.

## 5. First tasks (the `tasks` stage only)

So `/peal:work` has something to do right away, propose one or two first tasks from what
step 3 read: small, concrete, clearly wanted (a TODO the code or a list names, a gap the
README admits, a failing or missing CI step). Never invent work the repository does not
point at; with nothing fitting, propose nothing and skip to step 6.

- **Issues storage with open issues:** the issues are the tasks already. Name the one or
  two that fit a first task best (small, clear), by number, for step 7. File nothing.
- **Otherwise:** ask with `AskUserQuestion` (multiSelect): one option per proposal, its
  title as the label and a sentence of what and why (where you found it) as the
  description, and "None". File each chosen one with `peal create <slug>`, a slug of two
  to five kebab-case words, its text on stdin:

  ```markdown
  ---
  plan: skipped
  ---

  # NNNN — <Title>

  ## Intent

  <what changes when it is done, from what you found>

  ## Scope

  ## Done when

  ## Raw

  > <where it came from: the TODO line, the README passage, the issue, verbatim>

  ## Notes

  Proposed by /peal:setup.

  ---

  ## Outcome

  <!-- Written at close, replacing this comment. -->
  ```

  `plan: required` instead when `peal config plan.required-paths` names a path the work
  touches. Report each `filed` line. A refusal: report it; the proposal can be filed
  later with `/peal:idea`.

## 6. Hand the commit over

When step 2 made a `peal/setup-<stage>` branch, ask with `AskUserQuestion`: "Push the
setup and open a pull request?". Options: push and open it (recommended when `github`
names a repository), or keep the branch local for the human to review and merge
themselves. On yes: `git push -u <remote> <branch>` (`peal config remote`) and `gh pr
create --title "chore(peal): set up the <stage> stage" --body "<the stage's output lines,
and the first tasks filed>"`; report its URL. On a branch of the human's own, the commit
stays there, unpushed.

## 7. Report

End with at most five lines:

- what was set up, and where the commit is (its branch, the pull request's URL);
- what the human can do now: `/peal:idea <text>` files an idea as a task, and
  `/peal:work` works one (the first task by id, when step 5 filed or named one), once
  the setup commit is on the main branch;
- what exists for later, without setting it up: `/peal:setup <next>`, with the next
  stage and in a few words what it brings (`guardrails`: git hooks that keep commits off
  the main branch and run the project's checks; `milestones`: tasks grouped into goals,
  worked in order; `belfry`: Belfry's board and jobs for this project);
- any human step: settings lines to add by hand, `gh auth login`, Belfry's.
