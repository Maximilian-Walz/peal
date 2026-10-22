---
plan: auto
size: S
depends: []
touches: [plugin/lib/status.sh, plugin/bin/peal, docs/reference/cli.md, docs/getting-started.md]
---

# 0201 — peal status: one human-readable screen of the project's state

## Intent

Today a human without a control plane has five commands to see where things stand (`list`, `overview`, `milestones`, `ideas`, `doctor`) and an orientation only Claude sees. `peal status` (or `peal` with no argument) prints one screen: the current milestone, this worktree's task and its plan state, my claims and what each waits on, tasks awaiting merge, queued ideas, the next offer, and "your main is N behind" (the fast-forward task). It adds one read-only command and replaces nothing; a control plane has its board for this, and its task page shows the same information from `board`, so no contract change.

## Scope

- `peal status`: read-only, fast (no network unless `--fetch`), plain text; lists what the orientation prints for Claude, for the human.
- `docs/getting-started.md` mentions it.

## Done when

- A test on a fixture project with a current milestone, a claim, a queued idea and a task awaiting merge asserts each line.
- The command makes no write and no network call without `--fetch`.

## Raw

> yes, go ahead with all of it and file those proposals.

## Notes

- Usability review P7.
- Security: none (read-only).

---

## Outcome

<!-- Written at close, replacing this comment. -->
