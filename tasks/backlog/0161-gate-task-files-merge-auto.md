---
milestone: m6
plan: required
size: S
depends: []
priority: high
---

# 0161 — Gate a task-files-only pull request from setting `merge: auto` on another task

## Intent

Found in 0149. The `task files` auto-merge tier lets a pull request that touches only `tasks/**` merge by itself, and the `agreed tasks` rule merges any task marked `merge: auto`. A task-files pull request can therefore write `merge: auto` into another task's frontmatter, which the human only means to write when agreeing a plan. Accepted for now; find a gate (a check, a Belfry rule or a harness) so that `merge: auto` cannot arrive through a pull request that auto-merges on its paths.

## Done when

- A pull request that adds or changes `merge: auto` in a task file does not merge without the human, or the gap is documented with its reason in docs/security.md.

## Raw

> Found in 0149: the task-files loophole (a task-files PR setting `merge: auto` on another task) is accepted for now; file an idea for a gate. (The human's answer at planning.)
