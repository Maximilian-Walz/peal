---
milestone: m1
plan: skipped
priority: high
---

# 0038 — SECURITY.md, private vulnerability reporting and a threat model

## Intent

Peal is public. It runs shell on users' machines, installs git hooks in their
repositories, and feeds issue text to sessions. A reporter needs a private way to tell
us, and a reader needs to see what Peal guards against and how.

## Scope

- `SECURITY.md` with GitHub's private vulnerability reporting enabled.
- A threat model in `docs/security.md`: assets (the user's repository and machine, their
  GitHub token through `gh`), attackers (issue and PR authors on public repositories,
  hostile content in the repository, a malicious contribution to Peal), boundaries and
  what guards them, each naming its harness.
- `.github/ISSUE_TEMPLATE/task.md` and `.github/pull_request_template.md`, each with a
  one-line **Security:** field.

## Done when

- Both files exist, private reporting is on, and the template has the field.

## Raw

Filed as issue #38 (https://github.com/Maximilian-Walz/peal/issues/38); its text is carried over into the sections above and below.

## Notes

Decided up front, so a session need not ask:

- Enabling private vulnerability reporting is a repository setting: list it under "Human
  steps" in the PR body; do not change settings through `gh api`.
- `SECURITY.md` points to GitHub's private reporting only, with no email address.
- The threat model goes in `docs/security.md`.
- Name no other project and no private paths.

---

## Outcome

