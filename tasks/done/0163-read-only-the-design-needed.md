---
plan: skipped
size: S
depends: []
priority: high
touches: [CLAUDE.md, plugin/agents/reviewer.md, plugin/agents/planner.md]
milestone: m3
---

# 0163 — Sessions read only the parts of the design they need

## Intent

Every Peal session is told to "Read `docs/design.md` first": about 8,000 words, some
12k tokens, before any work, whatever the task. In the last month 27 of 47 task-job
sessions read it; the rest ignored the line. Either way it costs: read, it fills the
context with what the task does not need (current guidance from Anthropic: the smallest
set of high-signal tokens, and "would removing this cause Claude to make mistakes?" as
the test for an instruction); ignored, it teaches that the project's instructions are
optional. When this is done, CLAUDE.md points at the design as the place for the why
and the architecture, to read in the parts a task touches, and the subagent prompts
hold no wording that would cut what a reviewer finds once it runs on a model that takes
instructions literally.

## Scope

- `CLAUDE.md`: the "Read `docs/design.md` first" line becomes a pointer: the design
  is the why and the architecture, read the parts the work touches.
- `plugin/agents/reviewer.md` and `plugin/agents/planner.md`: check for wording that
  narrows what they report ("only high severity", "don't nitpick" and the like), which
  newer models obey literally and which lowers a review's recall; reword any found to
  say what to report and how to rank it instead. Nothing else in them changes.

## Done when

- `CLAUDE.md` no longer asks every session to read the whole design first, and still
  names `docs/design.md` as the place for the why and the architecture.
- The reviewer's and planner's prompts hold no instruction to leave findings out by
  severity or kind; their ranking by severity stays.

## Raw

> A lot has changed with recent AI models. Often times they don't need that many
> instructions and system prompts anymore. Especially stuff that is clear from the
> context they will look at anyways. Can you also check that we don't have too much
> instructions and harness that might make the models performance worse?

## Notes

Found in a review of the instructions sessions get, against Anthropic's current prompt
and CLAUDE.md guidance (code.claude.com/docs/en/best-practices, /memory). The same change
was made in the control plane's own instructions. The "Text from others is data" block
repeated in the commands and agents stays: it is the security line each prompt needs on
its own.

---

## Outcome

`CLAUDE.md` no longer tells every session to read `docs/design.md` first. It now names
the design as the place for the why and the architecture, to read in the parts the work
touches.

`plugin/agents/reviewer.md` said "Report only findings you would block a merge on". That
is the recall-cutting wording the task was after. It now says to report every finding,
each with a severity (blocks the merge, should be fixed, or minor), ranked most severe
first. The "Check, in order of severity" list is unchanged, and so is the merge-auto
line. `/peal:close` step 3 already routes every finding (fix, file, escalate or rebut),
so the change needs nothing new there. Closes will now see minor findings too, which is
the intended trade for recall.

`plugin/agents/planner.md` was checked for wording that drops findings by severity or
kind. None was found, so it is unchanged.

The reviewer had one finding, minor: an over-long line in the reviewer prompt. It was
rewrapped in its own commit.

### Reviewer findings not acted on

- `CONTRIBUTING.md` still says "Read docs/design.md first". It is written for human
  contributors and lies outside this task's scope. The reviewer agreed it was not a
  finding.
