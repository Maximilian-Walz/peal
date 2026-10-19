---
plan: required
---

# 0135 — The planner gets the issues and pull requests its task cites

## Intent

The peal:planner subagent can only Read, Grep, Glob, WebFetch and WebSearch. WebFetch gets a 404 on a private repository's issues, so when a task cites issues or pull requests the planner plans without them (on 0112 it treated a schema as unknown that the cited issue defined). The main session can read them with `gh issue view`, but only by resuming the planner with the text quoted by hand.

Have `/peal:work` (or `peal brief planner`) fetch the issues and pull requests a task names (`#N`, `owner/repo#N`) with `gh` and hand their bodies to the planner quoted as data. Text by authors without write access stays marked as outsider text, as on every other read of issues (0062, 0063). When `gh` is missing or has no access, the brief names the references it could not read, and the planner reports them as open questions instead of guessing.

## Scope

## Done when

## Raw

> The planner gets the issues and pull requests its task cites, quoted as data
>
> ## Intent
>
> The peal:planner subagent has Read/Grep/Glob/WebFetch/WebSearch only. WebFetch gets a 404 on a private repository's issues, so a task that cites issues was planned as if its schema were unknown (seen on 0112). The main session could read them with `gh issue view` and had to resume the planner with them quoted.
>
> Have `/peal:work` (or `peal brief planner`) fetch the issues and pull requests the task names with `gh`, and hand them to the planner quoted as data. Text by authors without write access stays marked as outsider text, like every other issues read (0062, 0063).
>
> ## Done when
>
> - A task citing `#N` or `owner/repo#N` gets their bodies in the planner's brief, quoted, with the write-access rule applied.
> - Without `gh` or without access, the brief says which references it could not read, and the planner reports them as open questions.
>
> ## Notes
>
> - This would also make most of the planner's WebFetch use (and its permission prompts) unnecessary.

## Notes

- Open: `/peal:work` or `peal brief planner`? The CLI is testable and reusable by other roles (reviewer, implementer); the command is where the network call already happens in a session.
- Open: comments too, or bodies only? Issue comments carry decisions as often as bodies do, and each needs the same write-access marking.
- Open: how a task's `#N` is told apart from a task id, a Markdown heading or a number in prose, and which repository a bare `#N` means on a project whose tasks live in files.
- Open: a cap on the length quoted, so a long thread does not swamp the brief.
- Under Belfry the session's sandbox has no `gh` login, so the fallback (references named as unread) will be the usual path there unless the fetch runs outside the sandbox.
- May let the planner drop WebFetch (and its permission prompts) for most tasks.
- Context: `docs/security.md` (the write-access rule `admitted()` applies to every issues read; outsider text quoted as data); `docs/reference/cli.md` (`peal brief`).

---

## Outcome

<!-- Written at close, replacing this comment. -->
