---
milestone: m3
plan: skipped
size: S
depends: []
---

# 0141 — Reproduce the sandbox friction of `peal close wait` and name the denied host

## Intent

Belfry's Friction page reported `peal close wait` answering `WAIT:checks-pending` seven times in two sessions, the gh calls reaching a host the sandbox denies. By the code a denied gh gives `BLOCKED:gh-failed`, not `WAIT`, so the mechanism is unproven. When this is done it is reproduced under a sandbox that denies GitHub's host, and, if real, `peal close verify` names the denied host in its verdict.

## Scope

- Reproduce first; if the report does not hold, close with the finding.
- `plugin/lib/close.sh` verify, `plugin/lib/github.sh` if the host must be surfaced.

## Done when

- The friction is reproduced or shown not to occur, with evidence in the Outcome.
- If real, `peal close verify` names the denied host, with a test.

## Raw

> From task 0067's note of 2026-10-18 (Belfry's Friction page): under the sandbox `peal close wait` answers `WAIT:checks-pending` every round.
