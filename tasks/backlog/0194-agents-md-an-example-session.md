---
plan: auto
size: S
depends: []
touches: [AGENTS.md, docs/example-session.md, plugin/.claude-plugin/plugin.json, .claude-plugin/marketplace.json]
milestone: m8
---

# 0194 — AGENTS.md, an example session transcript, and a plugin manifest description that names the issues storage

## Intent

An agent that finds the repository or is asked to set it up reads the README and then has to follow links to learn that `/peal:setup` is the entry point and `peal init --stage tasks` its deterministic half. There is no `AGENTS.md` (the repository's `CLAUDE.md` is contributor rules, correctly), no machine-oriented summary, and the install is given only in the slash-command form: the CLI form an agent can run from a shell (`claude plugin marketplace add <owner>/peal`, `claude plugin install peal@peal --scope project`) appears only in CONTRIBUTING's refresh recipe. The plugin and marketplace description is one sentence that omits the GitHub issues storage, the `peal` CLI and releases, and a marketplace browser and an agent both choose from it. There is also no transcript of a real session; the README's is composed. When this is done an agent and a newcomer each have what they need.

## Scope

- `AGENTS.md` at the root, about 40 lines: what Peal is in two sentences; the install lines from a shell; "run `/peal:setup` in a session, or `peal init --stage tasks` for the deterministic half"; the 14 commands; what it writes; pointers to the reference and `docs/security.md`. Not a copy of `CLAUDE.md`.
- `docs/example-session.md`: a real transcript of `/peal:setup`, `/peal:idea` and `/peal:work` on a scratch repository, lightly cut (the live walk the milestone 3 review wanted is its source; do that walk, do not compose one).
- `plugin.json` and `marketplace.json`: "Tasks as Markdown files or GitHub issues, each claimed into its own branch and worktree, planned with you by a planner subagent, built by an implementer and reviewed before it closes as a pull request; milestones, releases, and a `peal` CLI for hooks, scripts and control planes." and `keywords` if the schema allows.

## Done when

- `AGENTS.md` exists and every command it names is real (`tools/docs.test.sh` or a check of the list against `plugin/commands/`).
- The transcript is from a real run, and says which version it ran.
- Both manifests carry the new description.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Documentation review, section 5 and 8.3, 8.5. Also A3 of that review: `peal --help` and the comment in `plugin/lib/work.sh` omit `auto` among `PLAN` values; fix with the manifests.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
