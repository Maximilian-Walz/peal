---
milestone: m3
plan: required
size: M
depends: [0117]
---

# 0126 — Release sets the template's Peal SHA after the tag

## Intent

Task 0117 lets `peal ship bump` set the tag in the Get Peal step of
`plugin/templates/decisions.yml`, but the SHA on that line is still set by hand once the
tag exists, and `tools/pins.test.sh` fails until it is. A release commit cannot hold its
own SHA. Add a narrow write after `peal ship tag` that sets the SHA of the tag's commit
on that line, as its own gated commit.

## Scope

- A write after `peal ship tag` and its pre-push gate shape (subject, diff re-derived).
- Docs and tests as for the bump.

## Done when

- After a release, the template's SHA is the tag's commit without a hand edit, and
  `tools/pins.test.sh` stays green.

## Raw

> Follow-up of task 0117 (option D): a narrow write after peal ship tag that sets the template's Peal SHA.
