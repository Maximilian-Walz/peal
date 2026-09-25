---
plan: required
---

# 0044 — Human tasks: /peal:idea, /peal:defer and /peal:split file them

## Intent

A wait for the human gets an id: the commands that file tasks file a human task when
the work is the human's, and the task that waits depends on it.

## Scope

- `/peal:defer` and `/peal:split` file a human task and depend on it when the wait is
  for the human, so the wait has an id; the `human` keyword stays for waits nobody has
  written down yet.
- `/peal:idea` ends by printing the new task's id, so a caller (a session, or Belfry's
  filing job) can depend on it or link it.
- `/peal:idea` files a human task when the idea says the work is the human's ("I'll
  model …"), or when a session files one for the human.

## Done when

- Harnesses cover `/peal:idea` printing the id, and defer and split filing a human task
  and depending on it, in both storages.

## Raw

Filed as issue #44 (https://github.com/Maximilian-Walz/peal/issues/44), part of human tasks (#33, done); its text is carried over
into the sections above.

## Notes

---

## Outcome

