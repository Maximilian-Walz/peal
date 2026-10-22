---
plan: auto
size: M
depends: []
touches: [plugin/lib/test-lib.sh, plugin/lib/task-fixtures.sh, plugin/lib/work.sh, plugin/agents/implementer.md, plugin/commands/work.md, plugin/commands/close.md, CONTRIBUTING.md]
milestone: m7
priority: high
---

# 0185 — Harnesses run under one awk by default for the implementer, the main session runs none, and fixtures are reused

## Intent

The implementer is 43 % of all Claude spend on Peal's own tasks (a measured sample of 186 sessions), and test harnesses are its whole cost and wall time: 1,795 of its 6,573 tool calls (27 %) run a `*.test.sh` or `tools/test-all.sh`, and with the sleep and poll calls they cause that is 93 % of its 2,457 tool-minutes; 35 runs hit the Bash tool's 600 second ceiling. `for_each_awk` (`plugin/lib/test-lib.sh`) repeats every case under each awk installed; `PEAL_TEST_AWK=<one>` is the fast path (about three times faster) but it is documented only in a comment: no hit in CONTRIBUTING.md, the agent prompts or docs, and only 7 % of implementer runs set it. The main session, which never writes the task's code, ran harnesses 859 times (764 minutes), and the reviewer 173 times against its own one-test rule. Each case also builds a fresh fixture repository (`plugin/lib/task-fixtures.sh`: `git init --bare`, clone, four commits, push). When this is done a session runs the one harness of what it changed, under one awk, and the main session runs none.

## Scope

- Document `PEAL_TEST_AWK` in CONTRIBUTING.md and have `peal brief implementer` (`plugin/lib/work.sh`) say: run only the harness of the script you changed, with `PEAL_TEST_AWK=<the first awk found>`; CI covers the other awks; anything over two minutes goes in the background with Monitor.
- `plugin/commands/work.md` step 6 and `plugin/commands/close.md`: the main session runs no harness; the implementer's DONE WHEN block is the evidence. One sentence each.
- Fixture reuse: build the fixture repository once per harness and copy it per case, or have the fixture helper skip the push and use a local path remote (`plugin/lib/task-fixtures.sh` and the harnesses that call it directly).
- 0086 (`tools/test-all.sh -j`) is moved into this milestone at high priority and is the other half; do not duplicate it here.

## Done when

- CONTRIBUTING.md and `peal brief implementer` say how to run one harness under one awk, and a test of the brief asserts it.
- `work.md` and `close.md` say the main session runs no harness.
- A harness that built a fixture per case builds it once, and a test in `docs/` or `tools/` times a representative harness before and after (the Outcome records both numbers).

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Performance review finding 1. Estimated effect: implementer wall time roughly halved (median 24 minutes), 300 to 600 fewer implementer and main turns over the sample (3 to 5 % of spend).
- Security: none (test tooling and prompts only).

---

## Outcome

<!-- Written at close, replacing this comment. -->
