---
milestone: m1
plan: required
---

# 0040 — The git hooks and launcher Peal installs: safe in other people's repositories

## Intent

`peal init` installs git hooks and a launcher into the user's repository, and they run
on every commit and push, also on content a stranger contributed. They must never run
what the repository ships.

## Scope

- Hooks read only what they need, never execute repository content (no sourcing files
  from the working tree), use no network, and fail safe with a message.
- The launcher checks that the plugin it calls is the installed one (version and path),
  not something the repository ships.
- `peal init --remove` leaves nothing behind.

## Done when

- Harnesses cover a repository whose content tries to be executed by a hook, and removal.

## Raw

Filed as issue #40 (https://github.com/Maximilian-Walz/peal/issues/40); its text is carried over into the sections above.

## Notes

---

## Outcome

