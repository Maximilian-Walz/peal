---
plan: required
size: M
depends: []
touches: [plugin/lib/work.sh, plugin/lib/close.sh, plugin/commands/work.md, plugin/commands/close.md, docs/reference/cli.md]
milestone: m7
---

# 0187 — Fewer turns per task: peal work and close begin print what the next step needs, peal record writes the Plan section, finish waits

## Intent

In a measured sample, a quarter of the main session's turns are steps a script could fold together: in a plan-skipped session 14 of 19 tool calls were the mandated sequence, in a planned one about 20 of 29. Each main turn costs about $0.04 at the median 54 k context, so four to six turns removed are 15 to 20 % of the main session's spend. Observed: `peal brief` 259 times as a turn of its own; `peal work` run twice in 56 sessions and three or more times in 21 (the second run after `peal record` only prints `PLAN agreed`); the task file read right after `peal work` in 131 sessions; `peal config review.skip-paths` 89 times; `peal close verify` or `wait` 164 times after finish; a tool-search call per session because `close.md` says to load `wait_ci` through it; and 326 `python3` heredocs, mostly the session scripting the insertion of the Plan or Outcome section into the task file. When this is done the same task needs four to six fewer turns.

## Scope

- `peal work` prints the task text after the TASK line (or with `--with-text`) and the brief of the role that comes next; `peal close begin` prints the skip-path verdict and the reviewer's brief.
- `peal record ID plan` takes the plan on stdin and inserts `## Plan` itself, with options for the frontmatter the plan agrees (`--size`, `--touches`, `--model`; `merge` is not one of them, see the consent task of Safe under Belfry), replacing an edit, up to four `peal frontmatter set` calls, `peal record` and a second `peal work`.
- `peal close finish --outcome-file FILE` writes the Outcome section; finish runs the wait itself unless `--no-wait`, and prints the verdict.
- `close begin` does the post-implementer `git status` and `git log` check (already in the implementer's COMMITS block).
- `close.md` says the tool search for `wait_ci` and the first wait go in one message, or drops the branch when Belfry lists the tool.
- The prompts and `docs/reference/cli.md` follow; the sequence in `work.md` and `close.md` is the script's output, not a list of commands.

## Done when

- A harness walks the folded sequence and asserts each step's output carries what the next needs.
- `work.md` and `close.md` state the shorter sequence and `commands.test.sh` checks it.
- A measured session of the same size as before needs at least four fewer tool calls (recorded in the Outcome).

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Performance review finding 3. Interacts with the task that makes `merge` a consent only the human records: `peal record` must not gain a `--merge` option.
- Belfry's phase detection matches the command names here (`peal work`, `peal brief`, `peal close begin|finish|wait|verify|body`): keep the names, or tell Belfry first.
- Security: none beyond the `merge` rule above.

---

## Outcome

<!-- Written at close, replacing this comment. -->
