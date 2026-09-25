---
plan: required
---

# 0044 — Human tasks: /peal:idea, /peal:defer and /peal:split file them

## Intent

A wait for the human gets an id: the commands that file tasks file a human task when
the work is the human's, and the task that waits depends on it.

## Scope

- `/peal:defer` and `/peal:split` file a human task and depend on it when the wait is
  for the human, so the wait has an id; the `human` keyword stays for waits nobody has
  written down yet.
- `/peal:idea` ends by printing the new task's id, so a caller (a session, or Belfry's
  filing job) can depend on it or link it.
- `/peal:idea` files a human task when the idea says the work is the human's ("I'll
  model …"), or when a session files one for the human.

## Done when

- Harnesses cover `/peal:idea` printing the id, and defer and split filing a human task
  and depending on it, in both storages.

## Raw

Filed as issue #44 (https://github.com/Maximilian-Walz/peal/issues/44), part of human tasks (#33, done); its text is carried over
into the sections above.

## Notes

Proposed plan, not agreed yet (the planner, 2026-09-25). The human's answers to the
questions at the end are still open; the next session asks them and records the
agreed plan under `## Plan`.

- `peal idea` (`plugin/lib/ideas.sh`): after a filing, one last line `filed: <id>`
  (Belfry's form; it does not match close's `^filed `). A queued idea prints none. Usage
  line in `plugin/bin/peal`.
- `plugin/commands/idea.md`: an `owner: human` triage rule (the idea says the work is the
  human's, or the caller files it for the human); the report ends with `filed: <id>`;
  `depends: human` only for holds nobody has written down.
- `plugin/commands/defer.md`, a wait for human work: `peal defer --dry-run` with
  `depends: [human]` as a placeholder, then `PEAL_MAIN_WRITE_WAIT=merged peal idea <slug>
  --now` with `owner: human`, then the real defer with the printed id.
- `plugin/commands/split.md`: a human piece gets `owner: human`; the pieces that need it
  depend on its `PARTn`.
- `docs/design.md`: the command bullets, the `owner`/`depends` rows, the idea contract.
- Harnesses: `store-files.test.sh`, `store-issues.test.sh` (the id line; none when
  queued), `backlog.test.sh` (defer and split with a human task, both storages).
- Size M, model default, merge default. Rejected: an atomic `peal defer --human` (it
  changes the pre-push gate), and reading the id out of `filed NNNN` in prose.
- Overlaps 0043 in `docs/design.md`, `plugin/bin/peal` and the same harnesses.

Open questions, proposed defaults in brackets:
1. The id printed by the CLI and by the command's report [both].
2. An `owner: human` idea on a task branch is filed at once, not queued [at once].
3. A queued idea prints no id line [yes].
4. Defer under `main-writes: pr` waits for the human task's merge (up to ~9 minutes),
   falling back to `depends: [human]` and a note [yes].
5. Belfry's `{owner}` placeholder in `.belfry.yml` [not here; file an idea].
6. A human piece of a split is a real `part-of` piece [yes].
7. The harness covers push mode only [yes].
8. `/peal:idea` files one task per call [yes].
9. Defer runs the dry run first [yes].
10. The human task takes the waiting task's milestone, never a parked one [yes].

---

## Outcome

