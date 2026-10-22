---
plan: required
size: M
depends: []
touches: [docs/security.md, plugin/lib/doctor.sh, plugin/lib/git-guard.sh, plugin/templates/githook, plugin/lib/git-guard.test.sh, plugin/lib/githooks.test.sh]
milestone: m4
priority: high
---

# 0181 — The docs say a Bash-call gate cannot hold against the session's own environment; peal doctor checks branch protection on main and the cheap guard fixes go in

## Intent

The git guard and the git hooks are described as gates, and the guard as "a signpost; the git hooks are the gates". Both hold only against honest mistakes. Verified by running `peal hook git-guard`: `PEAL_ROOT=/tmp/fake git push origin ...`, `CLAUDE_CONFIG_DIR=/tmp/fake git commit ...`, `HOME=/tmp/fake git commit ...` and `PATH=/tmp/fakebin:$PATH git commit ...` all return status 0 (the guard waves every `NAME=value` prefix through except `GIT_CONFIG_*`), and the hook stub honours `$PEAL_ROOT` from the pushing process (`plugin/templates/githook`, the `PEAL_ROOT` branch of root discovery) and reads `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` for its cache, so a fake root of three files makes the commit-msg and pre-push gates no-ops. The guard is also passed by `timeout -k 5 10 git push origin main`, `nice -n 5 ...`, `echo main | xargs git push origin`, a wildcard or variable refspec, `git config alias.p 'push origin main'`, `remote.origin.push`, `include.path`, `git update-ref refs/heads/main`, `git branch -M task/x main`, `git merge` while on main, any other interpreter, and a script file. No Bash-call check can close all of that. What holds is server-side: branch protection or rulesets on main (a pull request required, required checks, no force push, no bypass for the token the sessions use). When this is done the docs say so plainly, `peal doctor` tells the human whether protection is on and what to turn on, and the cheap guard fixes the review lists are in.

## Scope

- `docs/security.md` (and the README claim "nothing merges by itself") say that a Bash-call gate cannot hold against the session's own environment, list what the review found, and name branch protection as the control that holds.
- `peal doctor` gets a check for protection on the main branch (the rules that apply to it, through `gh api repos/{owner}/{repo}/rules/branches/{main}` or the branch protection endpoint) that prints what to turn on; `peal init --stage guardrails` points at it. Without a login or on a non-GitHub remote it says it could not check.
- The cheap fixes: the stub honours `PEAL_ROOT` only when it passes the same cache and installed check as a recorded root, or equals the recorded root, and ignores `CLAUDE_CONFIG_DIR` and `HOME` unless they match what the SessionStart hook recorded; the guard refuses `PEAL_ROOT=`, `CLAUDE_CONFIG_DIR=`, `HOME=`, `PATH=` and `GIT_*=` prefixes and `env -i/-u`, handles `timeout -k/-s`, `nice -n` and `xargs`, refuses wildcard and variable refspecs, `git config alias.*`, `remote.*.push`, `include.path`, `git update-ref`, `symbolic-ref` and `branch -M` onto main, and `git merge` on main. The guard stays called a signpost.

## Done when

- `docs/security.md` has the limit, the list and the control that holds, and the README no longer implies the hooks are more than they are.
- `peal doctor` reports protection on main as ok, FAIL with the settings to turn on, or skip with the reason.
- Each prefix, wrapper and refspec form of the review's list is a case in `git-guard.test.sh`, and the stub test plants a hostile `PEAL_ROOT`, `CLAUDE_CONFIG_DIR` and `HOME` in the pushing environment.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Security review finding 2 (HIGH, verified). The hostile harness does not cover hostile shapes of Bash commands at the guard nor a hostile environment at the stub (it plants `PEAL_ROOT` inside the repository only); this task adds them.
- Related: the local merge of fabricated remote refs (Safe under Belfry), and the `gh` finding (next task).
- Security: this is the git gates boundary itself; `docs/security.md` is the main deliverable.

---

## Outcome

<!-- Written at close, replacing this comment. -->
