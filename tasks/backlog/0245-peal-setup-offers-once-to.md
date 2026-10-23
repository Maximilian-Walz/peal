---
milestone: m8
plan: required
---

# 0245 — /peal:setup offers once to trust the Apps behind bot issues

## Intent

When `/peal:setup` samples a project's open issues and finds some opened by `[bot]` logins whose GitHub App is not named in `storage.issues.apps`, setup offers the human to add those Apps to `storage.issues.apps`, so their issues count as a writer's. The offer is made once per App: the answer, yes or no, is remembered, and later setup runs do not offer the same Apps again. Follow-up of 0175, which lists the trusted Apps in setup.

## Scope

## Done when

## Raw

> /peal:setup offers once to trust the Apps behind bot issues
>
> ## Intent
>
> When `/peal:setup`'s issue sample sees open issues opened by `[bot]` logins whose App is not named in `storage.issues.apps`, setup offers the human to add those Apps to `storage.issues.apps`. It offers once: the answer is remembered, so later setup runs do not offer the same Apps again.
>
> ## Done when
>
> - A setup run on a sample with an untrusted App's issues offers it once, writes `storage.issues.apps` on yes, and a second run does not offer it again, yes or no; tested.
>
> ## Raw
>
> > it should at least be part of the stuff peal asks to set eventually. Of course it should not offer that over and over again.
>
> (The human, planning 0175.)
>
> ## Notes
>
> - plan: required. Follow-up of 0175.
> - Open: where the "already offered / declined" answer is remembered (config, a setup state file).
> - Open: writing `storage.issues.apps` likely needs a `peal init` option.
> - docs/security.md ("Only admitted issues reach a session"): trusting an App widens who can put text in front of a session; the offer must say so.

## Notes

- Follow-up of 0175 (setup lists trusted Apps). The human's proposed Done when (in Raw) is a starting point for the planner: offered once, `storage.issues.apps` written on yes, no second offer after yes or no; tested.
- Open: where the "already offered / declined" answer is remembered (in `.peal/config.yml`, or a setup state file).
- Open: writing `storage.issues.apps` likely needs a `peal init` option.
- docs/security.md, "Only admitted issues reach a session": trusting an App widens who can put text in front of a session; the offer must say so.
- docs/reference/configuration.md documents `storage.issues.apps`.
- Milestone m8 is the human's choice.

---

## Outcome

<!-- Written at close, replacing this comment. -->
