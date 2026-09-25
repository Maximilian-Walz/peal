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

Built, no plan needed (`plan: skipped`):

- `SECURITY.md`: reports go through GitHub's private vulnerability reporting only, no
  email address; it points to `docs/security.md` for what Peal guards against.
- `docs/security.md`, the threat model: assets (the user's repository and machine, their
  GitHub token through `gh`), attackers (issue and PR authors on public repositories,
  hostile content in the repository, a malicious contribution to Peal), and each
  boundary with its guard (a file or function) and its harness (a `*.test.sh`, or "none
  yet" with the task that builds it: 0039 for the cross-command hostile-input harness,
  0041 for CI action pinning). It ends with a pointer to 0039, 0040 and 0041 as the rest
  of what m1 promises, so it does not claim coverage this task did not build.
- `.github/ISSUE_TEMPLATE/task.md` and `.github/pull_request_template.md`, each with a
  one-line **Security:** field. The issue template follows `tasks/TEMPLATE.md` loosely and
  says a maintainer turns a triaged issue into a task with `/peal:idea`; the PR template
  says `/peal:close` writes a task's PR body itself, so it serves PRs opened outside the
  process.

Private vulnerability reporting was already enabled on the repository (checked read-only
through the API), so no human step is left for it; no setting was changed.

The review found that the `gh` boundary claimed every GitHub call goes through `peal_gh`;
the board's lookup of open pull requests (`_peal_files_prs`) calls `gh` directly, with its
own timeout. Fixed on the branch: the boundary now says every call goes through the `gh`
CLI and names that direct call. Routing it through `peal_gh` was not filed: the token
claim holds either way.

For the next session: `docs/security.md` is not in `.peal/config.yml`'s `context:` list,
so briefs do not point at it; a milestone review may want it there once 0039-0041 land.
