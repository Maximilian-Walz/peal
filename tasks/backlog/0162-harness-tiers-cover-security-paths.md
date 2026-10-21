---
milestone: m3
plan: skipped
size: S
depends: []
---

# 0162 — A harness checking every guard and harness path docs/security.md names is in a merge tier

## Intent

Found in 0149. `.belfry.yml`'s `never_auto_merge` and `review_before_merge` paths were checked by hand against the `Guard:` and `Harness:` lines of docs/security.md. A guard file added later that joins no tier would merge by itself under the `agreed tasks` rule. Add a harness (tools/docs.test.sh or its own) that reads both and fails when a named path is in no tier nor among Belfry's own guards (`.belfry.yml`, `.github/**`, `.claude/settings.json`), or when a listed non-glob path does not exist.

## Done when

- The harness fails on a path named in security.md that is in no tier, and passes on the current tree.

## Raw

> Found in 0149: file an idea for a harness checking the tiers against security.md. (The human's answer at planning.)
