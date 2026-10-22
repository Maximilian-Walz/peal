---
milestone: m7
plan: auto
size: S
depends: []
touches: [plugin/lib/claim.sh, plugin/lib/claim.test.sh, plugin/agents/reviewer.md, docs/security.md]
---

# 0220 — peal claim refuses from a subagent outside a test fixture, and the reviewer's brief says never to claim

## Intent

`peal claim` pushes `task/<id>-<slug>` to the remote at once ("the push is the lock", `plugin/lib/store-files.sh:1019`), so any `peal claim` run in a real worktree reaches the real remote. The reviewer subagent has Bash and is told to run the one test or command a Done-when line names; the reviewer runs of 0167, 0121 and 0160 ran `peal claim 0001`, inside fixtures as far as the transcripts show. A claim from a subagent in a real clone would push a scratch branch and claim a task nobody works. When this is done a claim outside a fixture is refused when the caller is a subagent, and the reviewer is told not to.

## Scope

- `peal claim`: when the hook fields or environment say the caller is a subagent (`agent_id`, or the control plane's marker) and no fixture marker is set (`PEAL_TEST`), refuse with the reason; at least refuse when the task's remote branch already exists under another slug.
- `plugin/agents/reviewer.md`: never claim, release or push; run the named test only in a fixture.
- `claim.test.sh` covers the refusal.

## Done when

- A harness case: a claim with the subagent marker and no fixture marker is refused, nothing pushed; with the fixture marker it proceeds.
- `reviewer.md` carries the line and `commands.test.sh` (or the agents check) asserts it.

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Reliability review finding 7, Peal side; the control plane's Run-button guard is its belfry#724.
- Security: the git gates boundary (what reaches the remote); `docs/security.md` gets one line.

---

## Outcome

<!-- Written at close, replacing this comment. -->
