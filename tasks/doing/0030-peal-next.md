---
milestone: m2
plan: required
---

# 0030 — /peal:next: what to adopt next

## Intent

After `/peal:setup` a project uses a small part of Peal. Nobody reads all the docs
first, so the rest should find the user when it would help, one thing at a time, with the
evidence for it, and never by changing things unasked.

## Scope

- `/peal:next` reads the project's state: stages set up (`.peal/config.yml`), the
  backlog and its history (tasks done, splits, deferrals), milestones, git history, CI,
  whether Belfry is configured.
- It suggests **one** next thing, the one with the best evidence, in a few lines: what it
  is, why this repository would profit ("12 tasks closed and no milestones: milestones
  would let you and Belfry's auto mode work the important ones first"), and how to try it
  (`/peal:setup milestones`). It may list two or three runners-up in one line each.
- It knows the stages of `peal init` and the features within them (the decisions
  module, drift and milestone review, releases, the reviewer's settings), each with a
  short check of whether it would help here.
- The user can accept (it runs the setup step), decline (recorded under `declined:` in
  `.peal/config.yml`, with the date, and not suggested again for 90 days unless asked),
  or ask for more.
- It never changes anything without an explicit yes.

## Done when

- Harnesses cover the `declined:` bookkeeping. (`peal doctor` is 0036.)
- On two scratch projects in different states, `/peal:next` suggests different, fitting
  next steps, and none after everything is set up.

## Raw

Filed as issue #30 (https://github.com/Maximilian-Walz/peal/issues/30), "/peal:next and peal doctor: what to adopt next, and what is
broken"; its text is carried over into the sections above.

## Notes

---

## Outcome

