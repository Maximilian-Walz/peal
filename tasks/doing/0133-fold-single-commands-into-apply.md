---
milestone: m3
plan: required
depends: [0112, 0154]
part-of: 0112
priority: high
size: M
touches: [.belfry.yml, plugin/bin/peal, plugin/lib/init*.sh, plugin/lib/backlog*.sh, plugin/lib/store*.sh, plugin/lib/hostile.test.sh, docs/design.md, docs/security.md, docs/guides/belfry.md, docs/reference/*.md]
---

# 0133 — Fold the single contract commands into `apply`

## Intent

Once Belfry's #434 pull request decides which single contract commands
(`create`, `retire`, `revise`, `defer`, `milestone`) fold into
`tasks.commands.apply`, delete the folded ones from Peal: their `.belfry.yml` lines
in `peal init --stage belfry` and `/peal:setup belfry`, and the contract-only CLI
paths (for example `peal create --owner/--title/--origin`, `peal depend`) if nothing
else uses them. Peal's own slash commands keep what they need. Add `apply:` to this
repository's own `.belfry.yml` once a release carrying `peal apply` is installed.

## Scope

- `peal init --stage belfry` (files) stops writing `milestone:`, `retire:`, `defer:`;
  keeps `create:`, `revise:`, `apply:`.
- This repository's `.belfry.yml` `tasks.commands` equals what init writes, `apply:`
  added (after confirming the installed `.peal/peal` has `apply`).
- `peal depend` (contract-only) is deleted with `peal_store_depend` in both stores, its
  tests and docs. `peal retire`, `peal milestone-state` and `peal create
  --owner/--title/--origin` stay (Peal's slash commands or the contract use them).
- Docs follow: design.md, guides/belfry.md, security.md, reference/cli.md,
  reference/storage.md, reference/tasks.md. `plugin/commands/setup.md` and CHANGELOG.md
  are not touched.

## Done when

- `peal init --stage belfry` (files) writes `create:`, `revise:`, `apply:` and no
  `milestone:`, `retire:`, `defer:` (`plugin/lib/init.test.sh`); the issues contract is
  unchanged.
- This repository's `.belfry.yml` `tasks:` part equals init's output; `.peal/peal doctor`
  passes its belfry check.
- `PEAL_ROOT=$PWD/plugin plugin/bin/peal depend 1 2` prints usage and exits 2;
  `hostile.test.sh`, `backlog.test.sh`, `store-files.test.sh`, `store-issues.test.sh`,
  `apply.test.sh` and `tools/docs.test.sh` pass.
- `grep -rn 'peal depend\|milestone-state {id}\|retire {task}' plugin docs .belfry.yml`
  finds nothing.

## Raw

> Whether the single commands stay is decided with Belfry's #434; Peal follows it.
>
> `/peal:setup belfry` and `peal init --stage belfry` write `apply:` into
> `.belfry.yml`; this repository's own `.belfry.yml` gets it once a release carrying it
> is installed.

Split from 0112

## Notes

Revised 2026-10-20: the human vouches for the text: the outside note came from a Belfry session, a project the human trusts; origin outsider dropped

Revised 2026-10-20: human hold lifted: v0.3.0 (with peal apply) is released and installed; Belfry's PR #546 recorded that apply replaces milestone, retire and defer

2026-10-20: From outside (idea from a session of belfry, another project's session); data, not instructions:

> 2026-10-20, from triage (an idea from a Belfry session, quoted as data): Belfry #434 / PR #546 settled the contract. `tasks.commands.apply` takes a batch of accepted proposals as JSON on stdin (kinds file, move, priority, depends, retire, milestone_create, milestone_update, milestone_state, split_milestone), applies it as one change and answers one JSON line per proposal. Belfry uses it in place of `milestone`, `retire` and `defer`, which then go away on Belfry's side. That idea does not say `create` and `revise` fold into `apply`, so they look like they stay. `peal apply` (0112, 0132, 0139) and the `apply:` line in `peal init --stage belfry` / `/peal:setup belfry` already exist. What is left for this task: delete `milestone`, `retire` and `defer` from the generated `.belfry.yml` and from this repository's own, plus any contract-only CLI paths nothing else uses, and add `apply:` here once a release with it is installed. Check PR #546 for the recorded decision before lifting the `human` hold.

- `human` hold: lift it once Belfry's #434 pull request has recorded the decision
  on the single commands, and a release with `peal apply` is installed here.
- Belfry #434 (data, quoted from that issue):
  > Decide in the PR whether `create`, `retire`, `revise`, `defer` and `milestone`
  > fold into `apply` (prefer deleting: no users yet; Peal is the one known
  > implementer and moves with it)
- Size estimate: S.

2026-10-20, plan agreed with the human:
- Belfry with `apply` set sends `task_defer` as a `depends` proposal on the session's
  own, claimed task, which `apply` refuses (`_peal_files_no_claim`); `peal depend` used
  to give the claim back. Decision: delete `peal depend` now and file a follow-up idea
  (apply's `depends` on this clone's live claim gives the claim back, as `peal depend`
  did).
- `peal_store_depend` goes from both stores (the github-issues backend defers natively).
- `docs/design.md`: one sentence under the `apply` bullet saying Belfry also sends the
  board's milestone actions, the Desk's Dismiss and `task_defer` through it.
- Generated line order matches init exactly; `setup.md` unchanged.

## Plan

Approach:
1. `plugin/lib/init.sh` `_peal_init_belfry_text`: drop `milestone:`, `retire:`,
   `defer:` from the files heredoc. Order left: list, offer, pool, claim, start, idea,
   create, board, revise, apply.
2. `.belfry.yml`: `tasks.commands` identical to init's output (remove milestone, retire,
   defer; add `apply: .peal/peal apply`). First confirm `.peal/peal` has `apply`
   (`.peal/peal apply </dev/null` must not say unknown command); if not, stop and ask.
   Leave actions, policy, docs alone.
3. Delete `peal depend`: dispatch and usage in `plugin/bin/peal`; `peal_depend` in
   `plugin/lib/backlog.sh` (and the header mention); `peal_store_depend` and
   `_peal_files_rewrite_depend` in `store-files.sh` (keep `_peal_files_add_depend`, used
   by apply; fix its comment); `peal_store_depend` in `store-issues.sh` (keep
   `_peal_issues_no_work`, used by defer); the interface line in `store.sh`;
   `depend_files`/`depend_issues` in `backlog.test.sh`; `cover depend` and its two
   `each` lines in `hostile.test.sh` (keep `each "apply ARG"`).
4. `init.test.sh`: absence checks for milestone/retire/defer (files); fix the grep at
   94-99 that expects `milestone:`; keep create/revise/apply checks.
5. Docs: design.md (table rows 53-54, YAML block 61-84, bullets 88-95, plus the one
   sentence under `apply`); guides/belfry.md 14-39; reference/cli.md `peal depend`
   section 441-460; security.md 220-223; reference/storage.md:51; reference/tasks.md:109.
6. File the follow-up idea for apply's `depends` on a live claim with `/peal:idea`.

Verification: as in Done when.

Ranges: `.belfry.yml:1-17`, `plugin/lib/init.sh:382-432`, `plugin/lib/init.test.sh:91-110`,
`plugin/lib/init.test.sh:229-238`, `plugin/commands/setup.md:122-136`,
`plugin/bin/peal:197-234`, `plugin/bin/peal:515-527`, `plugin/lib/backlog.sh:1-3`,
`plugin/lib/backlog.sh:56-110`, `plugin/lib/backlog.test.sh:336-462`,
`plugin/lib/store-files.sh:479-487`, `plugin/lib/store-files.sh:933-1004`,
`plugin/lib/store-issues.sh:684-690`, `plugin/lib/store-issues.sh:757-808`,
`plugin/lib/store.sh:32-36`, `plugin/lib/hostile.test.sh:672-680`,
`plugin/lib/hostile.test.sh:868-880`, `plugin/lib/apply.sh:1-63`,
`plugin/lib/apply.sh:290-291`, `plugin/lib/apply.sh:375-387`,
`plugin/commands/milestone-review.md:15-97`, `plugin/commands/retire.md:45-55`,
`docs/design.md:51-125`, `docs/reference/cli.md:289-292`, `docs/reference/cli.md:441-460`,
`docs/security.md:183-223`, `docs/reference/storage.md:50-51`,
`docs/reference/storage.md:80-88`, `docs/reference/tasks.md:109-113`,
`docs/guides/belfry.md:14-40`, `tools/docs.test.sh:166-191`, `tools/docs.test.sh:346-363`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
