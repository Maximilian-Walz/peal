#!/usr/bin/env bash
# Harness for lib/config.sh, lib/config-merge.awk and lib/config-print.awk, through
# `peal config`:
#
#   bash plugin/lib/config.test.sh
#
# The effective config is the defaults with the project's .peal/config.yml over them;
# unknown keys and wrong shapes are refused with the line.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"

defaults() {
  cat <<'EOF'
remote: origin
main: main
tasks: tasks
milestones: docs/milestones
branch-prefix: task/
worktrees: ../{repo}-wt
sizes.S: 60
sizes.M: 120
sizes.L: 200
plan.required-paths: []
review.skip-paths: [docs/, tasks/]
context: []
checks.commit: []
checks.close: []
pr.sections: []
commit.areas: []
models.planner: opus
models.reviewer: opus
models.implementer: sonnet
task.fields: {}
storage.kind: files
storage.issues.repo:
storage.issues.label:
decisions: false
EOF
}

cases() {
  local project
  project=$(scratch_dir)
  git -C "$project" init -q
  mkdir -p "$project/sub"
  cfg() { (cd "$project/sub" && "$PEAL" config "$@"); }
  write() { mkdir -p "$project/.peal" && printf '%b' "$1" >"$project/.peal/config.yml"; }

  check "no file: the defaults" "$(defaults)" "$(cfg)"
  write ''
  check "empty file: the defaults" "$(defaults)" "$(cfg)"

  write '# ours\nmain: trunk   # really\nsizes: {S: 30}\nplan:\n  required-paths:\n    - src/\n    - "odd: path"\nmodels:\n  implementer: opus\ncontext: [docs/design.md]\nchecks: {}\ntask:\n  fields:\n    kind: [bug, feature]\n    area:\ndecisions: docs/decisions\n'
  check "merged" "$(defaults | sed \
    -e 's|^main: main$|main: trunk|' \
    -e 's|^sizes.S: 60$|sizes.S: 30|' \
    -e "s|^plan.required-paths: \[\]$|plan.required-paths: [src/, 'odd: path']|" \
    -e 's|^models.implementer: sonnet$|models.implementer: opus|' \
    -e 's|^context: \[\]$|context: [docs/design.md]|' \
    -e 's|^task.fields: {}$|task.fields.kind: [bug, feature]\ntask.fields.area:|' \
    -e 's|^decisions: false$|decisions: docs/decisions|')" "$(cfg)"

  check "get: scalar" "trunk" "$(cfg main)"
  check "get: list" "$(printf 'src/\nodd: path')" "$(cfg plan.required-paths)"
  check "get: empty list" "" "$(cfg checks.close)"
  check "get: group" "$(printf 'S: 30\nM: 120\nL: 200')" "$(cfg sizes)"
  check "get: open map" "$(printf 'kind: [bug, feature]\narea:')" "$(cfg task.fields)"
  check_refused "get: unknown" "unknown setting nope" cfg nope

  refused() {
    write "$2"
    check_refused "refused: $1" "peal: .peal/config.yml:$3: *$4" cfg
  }
  refused "unknown key" 'main: x\nbogus: 1' 2 "unknown setting bogus"
  refused "unknown nested key" 'sizes:\n  XL: 300' 2 "unknown setting sizes.XL"
  refused "unknown flow key" 'models: {critic: opus}' 1 "unknown setting models.critic"
  refused "list for a scalar" 'main: [a]' 1 "main takes a single value, not a list"
  refused "scalar for a list" 'context: README.md' 1 "context takes a list"
  refused "value for a group" 'sizes: 5' 1 "sizes is a group of settings"
  refused "empty group" 'plan:' 1 "plan is a group of settings"
  refused "value for an open map" 'task:\n  fields: x' 2 "task.fields holds keys of your own"
  refused "field with one value" 'task:\n  fields:\n    kind: bug' 3 "give the allowed values as a list"
  refused "field too deep" 'task:\n  fields:\n    kind:\n      x: y' 4 "unknown setting task.fields.kind.x"
  refused "not the subset" 'main: &a x' 1 "anchors and aliases"
  refused "list of maps" 'pr:\n  sections:\n    - title: x' 3 "lists of maps"
  refused "duplicate" 'main: a\nmain: b' 2 "duplicate key main"

  local outside
  outside=$(scratch_dir)
  # shellcheck disable=SC2016 # expanded by the inner shell
  check_refused "outside a repository" "not inside a git repository" \
    bash -c 'cd "$1" && GIT_CEILING_DIRECTORIES=$1 "$2" config' _ "$outside" "$PEAL"
}

for_each_awk cases
finish
