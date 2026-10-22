---
plan: auto
size: M
depends: []
touches: [plugin/bin/peal, plugin/lib/doctor.sh, plugin/lib/ship.sh, plugin/lib/migrate.sh, plugin/lib/backlog.sh, plugin/lib/tasks.sh]
milestone: m8
---

# 0197 — Small usability fixes: empty answers say so, a short --help with help COMMAND, doctor, release, migrate and create messages

## Intent

The usability review found several small defects, each cheap, in the first hour with the CLI. (F2) Empty answers are silent: `peal list` with no tasks, `peal list 1` (not an id), `peal offer current` with no current milestone, `peal work` on an empty pool, `peal list --state free` with none, and `peal migrate headers` after converting three files all exit 0 and print nothing, so a person cannot tell "no tasks" from "wrong directory" from "it did nothing". (F4) `peal --help` is a 230-line design dump and an unknown command prints all of it. (F8) `peal doctor`'s version line splices a launcher refusal into its own sentence (`FAIL version: the installed Peal (peal: skipped the Peal at ... (recorded): it is not in Claude Code's plugin cache\n0.6.0) is not the one running this session`), and its fix ("start a fresh session") is not one the human can act on in that case. (F9) `peal release ID` reports the first reason it meets, not the decisive one: on a task not yet on main it says "a session worked there in the last 30 minutes", when "not done on main" is the reason. (F10) `peal migrate headers` maps `milestone: 3` to `m3` while `migrate milestones` names the file `m03`, with no hint why a project gets "m3 has no milestone file"; it also looks only under backlog, doing and done, which `docs/migrating.md` does not say. (F11) `create` accepts a task without `## Notes` that `comment` and `revise` later refuse ("no '## Notes' section to record the reason in"); `apply vouch` adds the section. When this is done each message says what happened and what to do.

## Scope

- Empty answers: one line on stdout, keeping the exit status: `no tasks yet: /peal:idea files one`, `no current milestone: /peal:setup milestones makes one`, `1 is not a task id: ids are four digits (0001)`, `migrated 3 files, 0 problems`.
- `peal --help` is one screen of groups with one line each; `peal help COMMAND` and `peal COMMAND --help` give the detail; an unknown command says `unknown command 'frob' (Peal 0.6.0 at <root>); peal --help lists them`, with "did you mean" for one letter. Do it with 0136 (the unknown command names the running Peal): link or absorb it.
- `doctor version`: capture stderr separately, print `FAIL version: the recorded root <path> was refused: not in the plugin cache` and a fix the human can do.
- `release`: check the reasons in order of permanence and name every one that holds, the permanent one first.
- `migrate`: pad the milestone ids as the milestone files do (or `--pad N`), report "task 0009 says m3; the file is m03"; say what directories it reads.
- `create` adds the empty `## Notes` section (one rule, as `vouch` does) so `comment` and `revise` work.

## Done when

- A test for each empty answer's line and for the unchanged exit status.
- `peal --help` fits one screen; `peal help claim` prints the detail; the unknown-command message names the running Peal.
- Tests for the doctor line, the release reasons, the migrate ids and the `create`-then-`comment` sequence.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

2026-10-22: Re-plan 2026-10-22: add to doctor (reliability review, finding 14): a task file whose heading number differs from its id, or with two frontmatter blocks, is a FAIL with the fix; 0174 was filed that way (`# 0170 — …` under id 0174, two frontmatter blocks) and `peal create` accepted it. The commit gate's task check refuses the same.

- Usability review F2, F4, F8, F9, F10, F11 (each small). Left out on purpose: F5 (titles in `list`) and F13 to F18 of the review, for later.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
