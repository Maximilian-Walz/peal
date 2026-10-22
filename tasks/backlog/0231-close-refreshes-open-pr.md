---
milestone: m9
plan: auto
size: S
depends: []
priority: normal
touches: [plugin/commands/close.md, plugin/lib/close.sh, docs/reference/cli.md]
---

# 0231 — Under a control plane, close refreshes an open pull request through pr_update

## Intent

Under a control plane, `close finish` opens its pull request through the plane's
`pr_create` tool (0176). When the pull request is already open (a re-run after a
send-back or a failed check), `pr_create` leaves it unchanged, and `peal close opened
--unchanged` says so: the pull request keeps its old title and body while the Outcome
and summary moved on. Belfry is adding a `pr_update` tool (belfry#758). When this is
done, close calls it in that case, so the pull request always shows the current text.

## Scope

- `close finish`'s hand-off and `plugin/commands/close.md`: when the pull request is
  already open and the control plane offers `pr_update`, the session calls it with the
  title, body and draft state `finish` prepared; without the tool, as today
  (`--unchanged`, said once).
- `docs/reference/cli.md` and the Belfry guide, where they describe the hand-off.

## Done when

- A harness case under fake-gh's no-auth mode with an open pull request: `finish` hands
  off an update, and `peal close opened N URL` records it; without the tool, the
  `--unchanged` path stays and is said once.
- `close.md` names `pr_update` beside `pr_create`.

## Raw

> yes, file the peal follow-up task too

## Notes

Waits on belfry#758 (the `pr_update` tool) being released and deployed; Peal detects the
tool as it detects `pr_create`. Left over from 0176 (its Outcome: "Belfry should add a
`pr_update` tool").
