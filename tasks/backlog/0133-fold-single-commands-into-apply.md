---
milestone: m3
plan: required
depends: [0112]
part-of: 0112
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

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
