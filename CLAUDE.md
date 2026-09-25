# Peal

A Claude Code plugin: the task-file process (task files, claim, offer, board, idea,
work, close, milestones), made generic. Read `docs/design.md` first.

Rules:
- Peal generalises the process of a reference project. Where that project lives is
  machine-local context, not part of this repository: read it there, never edit it
  from here, and never name it or its paths in this repository's files, commits,
  issues or pull requests. This repository may become public.
- Only what is generic moves in. Project-specific tooling stays in its project; Peal
  offers extension points instead of absorbing it.
- Task headers are real YAML frontmatter: a `---` block at the top of the file, lists
  (`depends`, `needs`) as YAML lists.
- Peal never needs Belfry; Belfry never knows Peal (`docs/design.md`).
- Peal runs on itself: the tasks are the files under `tasks/`, the milestones
  `docs/milestones/`, the settings `.peal/config.yml`. Work a task with `/peal:work` and
  `/peal:close`, file one with `/peal:idea`; GitHub issues are not tasks. The process
  runs the installed plugin (from `main`), never this checkout's `plugin/`: a branch
  cannot change the gates it is checked by. Try a branch's CLI with
  `PEAL_ROOT=$PWD/plugin plugin/bin/peal ...`.
- Each clone installs the git gates once: `.peal/peal hooks install`.
- Prefer deleting to deprecating. There are no users yet.
