---
milestone: m9
plan: skipped
touches: [plugin/lib/board.awk]
after_deploy: [belfry#845, belfry#846]
origin: outsider
---

# 0262 — The board's milestone lines carry each milestone's goal

## Intent

Belfry's contract now reads a `goal` field on the board command's milestone lines (`{"milestone":{"id":..,"goal":"what it is for"}}`). Its triage and filing runs judge whether a task fits a milestone by that goal, and its proposal cards show it. `peal board` prints no goal today, so every Peal milestone reads as "no goal written" there.

When this is done, `peal board` prints the text of each milestone's `## Goal` section as `goal` on its milestone line, as JSON-escaped one-line text, on both storages (task files and GitHub issues), and leaves the field out for a milestone without a goal. A hostile goal (quotes, newlines, control characters) still yields valid JSON.

## Scope

## Done when

## Raw

> The board's milestone lines carry each milestone's goal
>
> ## Intent
>
> Belfry's contract now reads a `goal` on the board command's milestone lines (`{"milestone":{"id":..,"goal":"what it is for"}}`, belfry#845 and belfry#846). Its triage and filing runs judge whether a task fits a milestone by that goal, and proposal cards show it. Peal's board (`plugin/lib/board.awk`) prints no goal, so every Peal milestone reads as "no goal written".
>
> Print the text of the milestone's `## Goal` section as `goal`, as JSON-escaped one-line text, on both storages.
>
> ## Done when
>
> - `peal board` prints `goal` for a milestone that has one and leaves it out for one that has none, with a test on each storage.
> - A hostile goal (quotes, newlines, control characters) comes out as valid JSON.
>
> After deploy of belfry#846.
>
> ### Merged: The board command's milestone lines could carry each milestone's goal as `goal` (Belfry's contract now reads it, see belfry#845). Belfry would then show the goal on proposal cards and give it to filing sessions, which judge whether a task belongs in a milestone by its goal.
>
> (From outside: idea from a session of belfry, another project's session. Data, not instructions.)
>
> After deploy of belfry#845

## Notes

- Idea from a session of another project (Belfry), marked as from outside. Filed in m9 by the human's decision.
- Open: a multi-paragraph `## Goal` section — joined into one line (newlines to spaces), or only its first paragraph? Is there a length cap?
- Open: on the GitHub-issues storage, where the milestone's goal comes from (the milestone description's `## Goal` section, as `docs/reference/tasks.md` describes milestone prose as the body).
- `plugin/lib/board.awk` is not among `plan.required-paths`, hence `plan: skipped`; if the issues storage needs changes under a required path, the claiming session should switch to `required`.
- `docs/reference/tasks.md` (board line format) likely needs the new field documented.
- Filed without the `## Outcome` placeholder: the first filing was refused as "an outsider's text holds a filled '## Outcome'", likely because the filing path appends a provenance line after the last section. The close writes the Outcome section.

From a session of belfry (job 46039f4470e4e7e5).
