---
plan: skipped
touches: [.claude/settings.json, docs/security.md]
---

# 0138 — Allow WebFetch in this repository's .claude/settings.json

## Intent

Sessions in this repository keep asking the human to allow `WebFetch`: Belfry saw it allowed three times across two sessions, and the planner agent lists it among its tools. Allowing it in the committed `.claude/settings.json` would end those prompts.

First weigh it against the threat model in `docs/security.md`: the repository may become public, sessions here read outsider text (issue bodies, a task's `Raw`), and `WebFetch` reaches arbitrary URLs, so a pre-allowed fetch is a possible exfiltration or injection channel. If that rules it out, record the decision and its reason in `docs/security.md` instead of changing the settings, and close the task.

## Scope

## Done when

## Raw

> Allow WebFetch in this repository's .claude/settings.json
>
> ## Intent
>
> Belfry recorded the human allowing `WebFetch` three times in two sessions of this project; the planner's tools include it. Add it to `.claude/settings.json`'s permissions so sessions stop asking.
>
> Before doing so, weigh it against the security model: this repository may become public, and WebFetch reaches arbitrary URLs from sessions that read outsider text (`docs/security.md`). If that rules it out, record the choice there instead and close this task.
>
> ## Done when
>
> - Either `WebFetch` is allowed in `.claude/settings.json`, or `docs/security.md` says why it is not.
>
> ## Notes
>
> - If the planner gets its cited issues through `gh` (filed in this triage), most of its WebFetch use goes away.
> - `.claude/` is unwritable from a sandboxed session: the change may need a human step.

## Notes

- The task filed in the same triage for the planner to read cited issues through `gh` (likely 0135, "the planner gets the issues") would remove most WebFetch use; it is not set as a dependency, but working it first may make this one moot. Open question: is the remaining use worth an allow at all?
- Open question: a blanket `WebFetch` allow, or a domain-scoped one (`WebFetch(domain:github.com)` and the like), which narrows the outsider-text risk?
- `.claude/settings.json` is unwritable from a sandboxed session: if the outcome is to allow it, the edit is likely a human step.
- Context: `docs/security.md` (attackers: issue authors whose text reaches a session; boundaries).

---

## Outcome

<!-- Written at close, replacing this comment. -->
