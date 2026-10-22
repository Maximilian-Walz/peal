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

<!-- Written at close, replacing this comment. -->
