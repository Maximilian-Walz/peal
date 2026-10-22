---
plan: required
size: M
depends: [0176]
touches: [plugin/lib/close.sh, plugin/commands/close.md, plugin/lib/config-defaults.yml, plugin/lib/doctor.sh, docs/reference/configuration.md]
milestone: m8
---

# 0198 — A pluggable pull request host for close: gh, the control plane's pr_create, or none

## Intent

`peal close finish` commits the move to `done/`, files the queued ideas, then fails on `gh api .../pulls` when `gh` is missing or the remote is not on GitHub: "the close is committed here. Run finish again once it can." `close verify` answers `BLOCKED:no-gh`; `peal list` warns on every call; `/peal:release` publishes through `gh`. A project on GitLab, Gitea, Bitbucket or a company server gets through setup, idea, claim, plan and build, and then cannot end. The README's "Peal never needs Belfry" is true; "Peal needs GitHub" is nowhere said. When this is done how a pull request is opened and watched is one small interface with three implementations: `gh` (today), the control plane's `pr_create` and `wait_ci` (the Safe under Belfry task adds the second), and `none`: finish pushes, prints the compare URL the remote gives, and ends `closed 0001: pushed task/0001-...; open the merge request yourself`; `verify` answers `READY:no-pr-tracking` and `list` stops warning.

## Scope

- A setting such as `pr.host: github|none` (auto-detected from the remote URL, with the control plane's tools detected as today) and `peal doctor` says which is in use.
- Cut the seam once, on top of the pr_create task: `close.sh` gains one seam, not two special cases; the wait step is provider-specific (under a control plane that follows the pull request itself it disappears, under `gh` it stays, under `none` there is nothing to wait for).
- The docs say what works without GitHub (ideas and claims yes) and what does not (releases).

## Done when

- Tests: `close finish` with `pr.host: none` ends with the pushed branch and the message, `verify` answers READY, and `list` does not warn.
- `peal doctor` names the host in use.
- The docs say Peal needs GitHub for releases and for `gh` close, and what `none` gives up.

## Raw

> yes, go ahead with all of it and file those proposals.

## Notes

- Usability review F3 and P2: Peal stops being a GitHub plugin by accident. A control plane that ends a session at pull request open (Belfry's #676) makes the wait provider-specific too; accept that here rather than keep a wait it will stop asking for.
- Security: touches the gh boundary (fewer calls); update `docs/security.md`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
