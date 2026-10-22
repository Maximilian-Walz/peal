---
milestone: m7
plan: required
size: S
depends: [0162, 0161]
priority: high
touches: [.belfry.yml, docs/security.md, README.md]
---

# 0219 — Peal's merge rules: a task pull request outside the boundary tiers merges by itself once CI and the security review pass, with no grace

## Intent

53 of the 57 Belfry-side merges of Peal pull requests between 2026-10-18 and 10-22 were the human's: `policy.merge: human`, the `agreed tasks` rule needs `merge: auto`, which only two done tasks ever carried, and `review_before_merge` keeps a one-hour grace after the review passed. The tiers decide what is dangerous: `never_auto_merge` is always the human's, `review_before_merge` merges after the review; once 0162 puts every guard path in a tier, a pull request that touches neither is ordinary code with green CI and a passed reviewer. When this is done such a pull request merges by itself, boundary paths and outsider tasks stay the human's, and the human's merges drop from about eleven a day to about three.

## Scope

- `.belfry.yml`: an `auto_merge` rule for pull requests from a job carrying no text from outside, with a line cap (say 400), that the tiers hold back for boundary paths; `review_before_merge` drops `grace: 1h` (it merges once security-pr passed on the head); the `agreed tasks` rule stays for `merge: auto` tasks.
- `docs/security.md` (Auto-merge tiers) says which pull requests merge by themselves and why the tiers make that safe; the README's "nothing merges by itself" is reworded as what the rules do.
- Depends on 0162 (every guard path in a tier) and 0161 (a task-files pull request cannot set `merge: auto`).

## Done when

- With 0162 in, a pull request touching only `plugin/lib/next.sh` and its test merges by itself once CI is green and security-pr passed (seen once on a real pull request, noted in the Outcome); one touching `plugin/lib/githooks.sh` waits for the human.
- `.belfry.yml` has no `grace` under `review_before_merge`.
- `docs/security.md` and the README describe it.

## Raw

> Lets [...] make a fable session with all of the proposed changes above + the ones from the two feature request + everything currently on the board on belfry and peal and rethink all of the milestones so they all are nicely scoped, tickets depend on each other correctly, we can just do a release after each milestone

## Notes

- Attention review F3c and F3a. The human merges `.belfry.yml`, so this pull request is theirs.
- Security: the auto-merge tiers boundary (`docs/security.md`); the tiers are what makes the rule safe, which is why 0162 comes first.

---

## Outcome

<!-- Written at close, replacing this comment. -->
