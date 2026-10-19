---
milestone: m3
plan: required
depends: [0112, human]
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
