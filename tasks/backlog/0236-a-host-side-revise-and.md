---
milestone: m9
plan: required
---

# 0236 — A host-side revise and comment for Belfry, so task-file writes onto main leave the sandbox through Belfry's host

## Intent

A Belfry session has neither a gh login nor an SSH key, so the task-file writes Peal makes onto main cannot leave its sandbox. On a project whose main refuses direct pushes, `peal revise` (and the other writes onto main) needs a pull request from a `peal/main-write-*` branch, which Belfry's `pr_create` cannot open, since it only opens from the job's own branch. And `peal comment`, which Peal's `.belfry.yml` runs as `tasks.commands.revise` through `/peal:comment`, fails already at its own `git fetch origin main` ("Host key verification failed"), so a Belfry revise job never writes its note.

Belfry already runs `peal apply` on its host. The task gives revise and comment the same route: a command the contract names (a `revise`/`comment` command in the `commands` backend, or `peal apply` taking a revision and a note) that Belfry runs on its host, so that a revise or a comment asked for under Belfry reaches main without the session touching the network itself.

## Scope

## Done when

## Raw

> A host-side revise and comment for Belfry, so task-file writes onto main leave the sandbox through Belfry's host
>
> ## Intent
>
> Under Belfry a session holds no gh login and no SSH key. On a project whose main refuses direct pushes `peal revise` (and the other task-file writes onto main) refuses: the write needs a pull request from a `peal/main-write-*` branch, and Belfry's `pr_create` only opens from the job's own branch. And `peal comment`, which Peal's `.belfry.yml` runs as `tasks.commands.revise` through `/peal:comment`, fails at its own `git fetch origin main` ("Host key verification failed"), so a revise job can never write its note. Belfry already runs `peal apply` on its host. Once this is done, a revise or comment asked for under Belfry reaches main through a command the contract names and Belfry runs on its host.
>
> ## Scope
>
> - A `revise`/`comment` command in the `commands` backend Belfry runs on its host (or `peal apply` taking a revision and a note), its shape in `plugin/lib/init.sh`'s Belfry template and Peal's own `.belfry.yml`.
> - `/peal:revise` and `/peal:comment` under Belfry use it.
> - `docs/guides/belfry.md`'s inventory says how, no longer that revise is unavailable.
>
> ## Done when
>
> - A revise in a Belfry session on a protected main lands on main through Belfry's host, with no `peal/main-write-*` branch pushed from the session.
> - A Belfry revise job adds its note to the task.
>
> ## Raw
>
> > Revise: document it in the inventory as unavailable on a protected main, and file one idea for a host-side `revise` command.
>
> (The human's answer to 0203's plan.)
>
> ## Notes
>
> - plan: auto, size M. Belfry has to learn the command (its contract), so a Belfry-side task may follow.
> - Folds the friction of job 5a89590042a0f3dc (`peal comment` cannot fetch or push from the sandbox), whose other fix was a no-network mode with the fetch and push as separate commands.
>
> ### Merged: peal comment cannot fetch or push from inside Belfry's sandbox: its internal `git fetch origin main` failed with "Host…
>
> Friction a session of peal reported: the tooling around its work got in its way.
>
> ### Job 5a89590042a0f3dc (peal)
>
> - **Tried:** Run `peal comment 0184 "<text>"` in a Belfry revise job (/peal:comment), as the skill prescribes.
> - **What happened:** peal comment cannot fetch or push from inside Belfry's sandbox: its internal `git fetch origin main` failed with "Host key verification failed", since only a bare `git fetch`/`git push` command runs outside the sandbox and the SSH keys are unreadable inside it. So the revise job can never write its note.
> - **Workaround:** None; the note was not added, as the skill says not to retry with other commands.
> - **Proposed fix:** Under Belfry, have /peal:comment split the work: run `git fetch origin main` as its own command, call peal comment with a no-network mode that commits to a local ref, then `git push origin <ref>` as its own command (or have Belfry run the revise job's peal command outside the sandbox, like tasks.commands.create).
> - **Ran on:** worker v0.34.0, peal@peal 0.7.0

## Notes

- Milestone m9 is the human's decision (Contract kept): the command is part of the contract Belfry runs.
- plan: the idea suggested `auto`; triaged `required`, since the write path onto main lives in `plugin/lib/main-write.sh` (a plan-required path) and a host-side command may touch it and `plugin/templates/`.
- Open: which shape — a dedicated `revise`/`comment` command in the `commands` backend, or `peal apply` widened to take a revision and a note? And the friction's alternative, a no-network `peal comment` with the fetch and push run as separate bare git commands: weigh it against the host-side route.
- Open: Belfry has to learn the command in its contract; a Belfry-side task may follow, filed by the session that agrees the shape.
- Related: 0203 (Belfry gh-caller inventory), 0225 (`/peal:comment` takes the origin from its argument; the guide names no missing command).
- Context: `docs/guides/belfry.md` (its inventory), `docs/design.md` (Peal never needs Belfry; Belfry never knows Peal), `.belfry.yml` (`tasks.commands.revise`).

---

## Outcome

<!-- Written at close, replacing this comment. -->
