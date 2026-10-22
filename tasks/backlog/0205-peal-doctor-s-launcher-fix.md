---
plan: required
touches: [plugin/lib/doctor.sh, plugin/lib/doctor.test.sh]
---

# 0205 — peal doctor's launcher fix runs the verified Peal, not the .peal/peal it just flagged

## Intent

When `.peal/peal` is missing or no longer matches the plugin's launcher template, `peal doctor version` (`_peal_doctor_stage_version`, `plugin/lib/doctor.sh`) offers `.peal/peal init --stage tasks` as the fix. A mismatched launcher may be a branch's hostile replacement, so following that advice runs exactly the file doctor has just said not to trust. The remedy should instead go through the Peal that is running and was verified (`"$PEAL_ROOT/bin/peal" init --stage tasks`, or `/peal:setup tasks`). The SessionStart `Launcher:` line (task 0088) gets the same treatment if it also names `.peal/peal` as its fix.

## Scope

## Done when

## Raw

> peal doctor's launcher fix runs the verified Peal, not the .peal/peal it just flagged
>
> ## Intent
>
> `_peal_doctor_stage_version` (`plugin/lib/doctor.sh`) suggests `.peal/peal init --stage tasks` as the fix when `.peal/peal` is missing or does not match the plugin's launcher template. A mismatched `.peal/peal` may be a branch's hostile replacement (docs/security.md, "The committed launcher"), so the suggested fix runs the very file doctor just flagged.
>
> ## Scope
>
> - Point the remedy at the running, verified Peal (`"$PEAL_ROOT/bin/peal" init --stage tasks`, or `/peal:setup tasks`).
> - The same for the SessionStart `Launcher:` line from 0088, if it names `.peal/peal` as its fix.
>
> ## Done when
>
> - doctor.test.sh asserts that the remedy for a mismatched launcher does not start with `.peal/peal`.

## Notes

- The SessionStart `Launcher:` line does name it: `plugin/lib/session.sh` (around line 218) says "Refreshing it is .peal/peal init --stage tasks and a commit of its own." So that line is in scope too, and so is `plugin/lib/session.test.sh` if it asserts the wording.
- Open question: when `.peal/peal` is simply *missing*, running it is harmless, but there is nothing to run, so the same remedy should apply there. Is one wording enough for both the missing and the mismatched case?
- Open question: doctor's other remedies (`.peal/peal hooks install`, `.peal/peal release`) also go through the launcher. When the launcher check has failed in the same run, should they switch over too? The idea doesn't ask for this; the planner decides whether it stays out of scope.
- Open question: `$PEAL_ROOT` may be unset when doctor runs through the launcher. The remedy has to name a path that resolves, or fall back to `/peal:setup tasks`.
- Context: docs/security.md, "The committed launcher" (guard `peal_launcher_matches`); docs/reference/cli.md for doctor's output.

---

## Outcome

<!-- Written at close, replacing this comment. -->
