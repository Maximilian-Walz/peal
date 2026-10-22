---
milestone: m7
plan: auto
size: M
depends: []
priority: high
---

# 0162 — A harness checking every guard and harness path docs/security.md names is in a merge tier

## Intent

Found in 0149. `.belfry.yml`'s `never_auto_merge` and `review_before_merge` paths were checked by hand against the `Guard:` and `Harness:` lines of docs/security.md. A guard file added later that joins no tier would merge by itself under the `agreed tasks` rule. Add a harness (tools/docs.test.sh or its own) that reads both and fails when a named path is in no tier nor among Belfry's own guards (`.belfry.yml`, `.github/**`, `.claude/settings.json`), or when a listed non-glob path does not exist.

## Done when

- The harness fails on a path named in security.md that is in no tier, and passes on the current tree.

## Raw

> Found in 0149: file an idea for a harness checking the tiers against security.md. (The human's answer at planning.)

## Notes

2026-10-22: Re-plan 2026-10-22: moved into Cheaper tasks as the precondition of the merge-rules task (0219): once every guard path is in a tier, a pull request outside the tiers can merge by itself.

Revised 2026-10-22: Widened by the security review (finding 5)

- Widened by the security review (finding 5): the scope is every file the guard code sources or executes, not only the paths `docs/security.md` names. Today `plugin/lib/common.sh`, `config.sh`, the config and yaml awks, `json-get.awk`, `shell-words.awk`, `close.sh`, `commit.sh`, `init.sh`, `ideas.sh`, the task-check, task-scan and task-state awks, `tasks.sh`, `decisions.sh`, `doctor.sh`, `next.sh`, `migrate.sh`, `milestones.sh`, `review.sh`, the issues awks and `templates/task.md` sit in neither `never_auto_merge` nor `review_before_merge`, so a pull request marked `merge: auto` that touches them merges on green CI alone and reaches every install at the next plugin update.
- Invert the default: `plugin/**`, `tools/**`, `.peal/**` and `.claude/**` need `review_before_merge` at least, with the current never list on top; only `tasks/**`, `docs/**` (minus `docs/security.md`), `CHANGELOG.md` and `README.md` merge on checks.
- Raised to priority high and size M (was S, plan skipped); plan auto.
