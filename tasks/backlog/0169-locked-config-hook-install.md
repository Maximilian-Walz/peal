---
plan: required
touches: [plugin/lib/githooks.sh]
milestone: m7
---

# 0169 — A locked config does not make the git-hook install print raw lock errors

## Intent

`peal_hooks_ensure` (`plugin/lib/githooks.sh`) runs at claim and at session start. The first time, it writes `core.hooksPath` to the shared `.git/config`. In a sandbox that keeps `config.lock` in place, that write can print git's raw "could not lock config file" lines. Under a locked config it should stay quiet or print one clear line, as task 0167 did for the pushes.

## Scope

## Done when

## Raw

> peal_hooks_ensure (plugin/lib/githooks.sh), run at claim and session start, writes core.hooksPath to the shared .git/config the first time; under a sandbox's locked config.lock that write can print git's raw "could not lock config file" lines. Make it quiet (or a single clear line) when the config is locked, as task 0167 did for the pushes. Found while planning 0167; agreed by the human as a follow-up.

## Notes

- Open: once the install fails, the git gates are not active. Is one clear line (and `.peal/peal hooks install` as the fallback) the right answer, rather than staying quiet?
- Context: task 0059 (automatic hook install); task 0167 (pushes without `-u`, locked-config harness cases to copy).

---

## Outcome

<!-- Written at close, replacing this comment. -->
