---
milestone: m3
plan: required
size: M
depends: [0117]
---

# 0127 — release.version-files reaches a nested YAML field

## Intent

`release.version-files` reaches a top-level field of a JSON, TOML or YAML file, or (task
0117) a marked line. Let it also name a nested YAML field (for example `image.tag` of a
Helm values file), set without touching anything else, and re-derived by the
chore(release) gate.

## Scope

- The item syntax for a nested field (today a dotted field is refused), the edit in
  `plugin/lib/version-field.awk`, the gate, docs and tests.

## Done when

- `peal ship bump` sets a nested YAML field, changing only its value; the gate accepts
  exactly that edit; refusals leave main unchanged.

## Raw

> Follow-up of task 0117: nested YAML fields in release.version-files, left out of it.
