---
plan: auto
size: S
depends: []
touches: [plugin/lib/init.sh, plugin/lib/init.test.sh, .belfry.yml, docs/guides/belfry.md]
milestone: m6
priority: high
---

# 0179 — The peal init --stage belfry template, and Peal's own contract, set apply_kinds, max_code_jobs and never_auto_merge for .peal/**

## Intent

`_peal_init_belfry_text` in `plugin/lib/init.sh` writes the contract a Peal project hands to its control plane. Three things in it are wrong for the Belfry of today. It names `apply` without `apply_kinds`, and Belfry carries out nothing through `apply` without it: no Close, Park or Un-park on the board, no Dismiss, and a deferral falls back to "record the dependency the project's way". It does not set `policy.max_code_jobs`, which replaced `max_concurrent` (a project that still has the old key is refused). And it has no `never_auto_merge: [.peal/**]`, so in a project that turns on any `auto_merge` rule a task pull request can change `.peal/config.yml` (`worktree-setup`, `checks.commit`, `main`, `remote`) and `.peal/peal`, and merge by itself; the control plane then runs the merged launcher on the host. When this is done a freshly set up project's contract is valid, complete and safe.

## Scope

- The template: `apply_kinds` naming the kinds Peal carries out, `policy.max_code_jobs`, and `policy.never_auto_merge: [.peal/**]` (with a comment that Belfry's own never-list already covers `.belfry.yml`, `.github/**` and `.claude/**`).
- Peal's own `.belfry.yml` still has `apply` without `apply_kinds` (its `max_code_jobs` was fixed): add it, and `.peal/**` to its never list if it is not covered.
- `docs/guides/belfry.md` shows the same lines.

## Done when

- A test asserts the template names `apply_kinds`, `max_code_jobs` and `never_auto_merge` with `.peal/**`.
- `peal doctor belfry` flags a contract with `apply` and no `apply_kinds`.
- Peal's own `.belfry.yml` has `apply_kinds`.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Security review finding 6 (MEDIUM, boundary) and boundary review section 1.3 (`apply_kinds` arrived in the control plane's contract on 2026-10-21; without it Peal's board loses its milestone actions and Dismiss silently).
- Belfry side: a compatibility rule for contract keys is filed there so the next rename warns first.
- Security: touches the committed launcher and config limits and the auto-merge tiers in adopting projects (`docs/security.md`).

---

## Outcome

Built:
- `.peal/peal init --stage belfry` now writes `apply_kinds` with the commands backend. The list is `file, move, priority, depends, retire, milestone_create, milestone_update, milestone_state, split_milestone`, the same as Peal's own contract.
- With every backend, the template now writes `policy.max_code_jobs: 2` and `policy.never_auto_merge: [.peal/**]`. A comment says that Belfry's own never-list already covers `.belfry.yml`, `.github/**` and `.claude/**`.
- `docs/guides/belfry.md` shows the same lines.
- `peal doctor belfry` fails `belfry.apply_kinds` when `tasks.commands.apply` is set without `apply_kinds`. `docs/reference/cli.md` documents the check.
- Tests: `init.test.sh` checks the template has the three keys, and `doctor.test.sh` checks both the failing and the passing doctor case.

Peal's own `.belfry.yml` already had `apply_kinds` (#321) and `.peal/**` in its never list on main. It is left unchanged.

Decided:
- `add` and `vouch` stay out of the template's `apply_kinds`, although `PEAL_APPLY_KINDS` accepts them.
  - `vouch`: Peal cannot tell that a vouch came from a human (`docs/security.md`). Offering it to the control plane must be the adopting project's explicit choice.
  - `add`: notes go through `revise: /peal:comment`.
  - The template therefore grants no more than Peal's own contract.
  - The comment in the template calls the list "the kinds Belfry may send apply", because it is a deliberate subset of what apply can do.
- The doctor check tests only that `apply_kinds` is present, not what it lists.

Next session: if the control plane ever sends triage `add` verdicts only through `apply`, add `add` to the list. The reviewer could not check the control plane's side from this sandbox.

### Reviewer findings not acted on

- None left. The missing cli.md line and the comment wording were fixed in a commit of their own.
