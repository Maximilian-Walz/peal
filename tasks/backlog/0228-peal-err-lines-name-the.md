---
milestone: m8
plan: skipped
size: S
depends: []
touches: [plugin/lib/common.sh, plugin/bin/peal, docs/reference/cli.md]
---

# 0228 — peal_err lines name the command that failed

## Intent

Errors are `peal: ...` on stderr (about 510 `peal_err` calls), the same prefix for all sixty commands. A session sees the line in its Bash output and the control plane shows `apply`'s stderr tail and `create`'s error to the proposing session, so `peal: no such task` says nothing about which step of a composed command failed. When this is done every error line starts with the command (`peal apply: ...`, `peal close finish: ...`).

## Scope

- `peal_err` in `plugin/lib/common.sh` prefixes the dispatched command (set once in `plugin/bin/peal`'s dispatch; subcommands append their name).
- The harnesses that match `peal: ` adjust; `docs/reference/cli.md` says the form.

## Done when

- A harness case per storage finds `peal create:` and `peal apply:` prefixes; the hostile harness's reason-line check accepts the new form.

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Observability review, Peal section. Pairs with 0197's messages and 0136's unknown-command line.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
