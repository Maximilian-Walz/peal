#!/usr/bin/env bash
# Harness for tools/ci-changes.sh: which changes let CI skip its harnesses.
#
#   bash tools/ci-changes.test.sh
set -uo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../plugin/lib/test-lib.sh
. "$REPO/plugin/lib/test-lib.sh"

dir=$(scratch_dir)
git -C "$dir" init -q
git -C "$dir" config user.email t@example.com
git -C "$dir" config user.name t
mkdir -p "$dir/tasks/backlog" "$dir/docs/milestones" "$dir/plugin/.claude-plugin" "$dir/plugin/lib"
printf -- '---\nplan: skipped\n---\n# 0001 — one\n' >"$dir/tasks/backlog/0001-one.md"
printf -- '---\nstate: current\n---\n# M1\n' >"$dir/docs/milestones/m1.md"
printf '{\n  "name": "peal",\n  "version": "0.1.0",\n  "description": "x"\n}\n' >"$dir/plugin/.claude-plugin/plugin.json"
printf 'echo hi\n' >"$dir/plugin/lib/a.sh"
git -C "$dir" add -A && git -C "$dir" commit -qm base
base=$(git -C "$dir" rev-parse HEAD)

# change DESCRIPTION: commit what the caller changed, print the verdict against base.
verdict() {
  git -C "$dir" add -A && git -C "$dir" commit -qm "$1" --allow-empty
  (cd "$dir" && bash "$REPO/tools/ci-changes.sh" "$base" HEAD)
}
reset() { git -C "$dir" reset -q --hard "$base"; }

printf 'more\n' >>"$dir/tasks/backlog/0001-one.md"
printf -- '---\nplan: skipped\n---\n# 0002 — two\n' >"$dir/tasks/backlog/0002-two.md"
check "task files only: skip" harnesses=false "$(verdict tasks)"
reset

printf 'more\n' >>"$dir/docs/milestones/m1.md"
check "a milestone's text: skip" harnesses=false "$(verdict milestone)"
reset

sed -i.bak 's/0.1.0/0.2.0/' "$dir/plugin/.claude-plugin/plugin.json" && rm "$dir/plugin/.claude-plugin/plugin.json.bak"
check "a version bump: skip" harnesses=false "$(verdict bump)"
reset

printf '# Changelog\n\n## v0.2.0\n' >"$dir/CHANGELOG.md"
check "the changelog alone: skip" harnesses=false "$(verdict changelog)"
reset

printf '# Changelog\n\n## v0.2.0\n' >"$dir/CHANGELOG.md"
sed -i.bak 's/0.1.0/0.2.0/' "$dir/plugin/.claude-plugin/plugin.json" && rm "$dir/plugin/.claude-plugin/plugin.json.bak"
check "the changelog and a version bump: skip" harnesses=false "$(verdict changelog-bump)"
reset

mkdir -p "$dir/docs" && printf '# Changelog\n' >"$dir/docs/CHANGELOG.md"
check "a changelog elsewhere: run" harnesses=true "$(verdict changelog-elsewhere)"
reset

sed -i.bak 's/"x"/"y"/' "$dir/plugin/.claude-plugin/plugin.json" && rm "$dir/plugin/.claude-plugin/plugin.json.bak"
check "plugin.json beyond its version: run" harnesses=true "$(verdict desc)"
reset

printf 'more\n' >>"$dir/tasks/backlog/0001-one.md"
printf 'echo ho\n' >>"$dir/plugin/lib/a.sh"
check "a task file and code: run" harnesses=true "$(verdict mixed)"
reset

mkdir -p "$dir/tasks-x" && printf 'x\n' >"$dir/tasks-x/f"
check "a look-alike of tasks/: run" harnesses=true "$(verdict lookalike)"
reset

git -C "$dir" mv plugin/lib/a.sh tasks/a.sh
check "code moved into tasks/: run" harnesses=true "$(verdict move)"
reset

sed -i.bak 's/"0.1.0"/""/' "$dir/plugin/.claude-plugin/plugin.json" && rm "$dir/plugin/.claude-plugin/plugin.json.bak"
check "an emptied version: run" harnesses=true "$(verdict empty-version)"
reset

sed -i.bak 's/^  "version": "0.1.0"/\t"version": "0.2.0"/' "$dir/plugin/.claude-plugin/plugin.json" && rm "$dir/plugin/.claude-plugin/plugin.json.bak"
check "a version line indented with a tab: run" harnesses=true "$(verdict tab)"
reset

check "no base (a new branch): run" harnesses=true "$(cd "$dir" && bash "$REPO/tools/ci-changes.sh" "" HEAD)"
check "an all-zero base (a push that created the branch): run" harnesses=true \
  "$(cd "$dir" && bash "$REPO/tools/ci-changes.sh" 0000000000000000000000000000000000000000 HEAD)"
check "a base git does not have: run" harnesses=true \
  "$(cd "$dir" && bash "$REPO/tools/ci-changes.sh" 1234567890abcdef1234567890abcdef12345678 HEAD)"
check "nothing changed: skip" harnesses=false "$(verdict empty)"

finish
