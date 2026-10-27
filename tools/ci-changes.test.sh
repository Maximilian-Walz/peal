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
mkdir -p "$dir/plugin/templates" "$dir/.peal" "$dir/.github/workflows"
SHA1=53fbcc7bf30e53bedc0cf3ab6eb0a0b07eac3d23
SHA2=0123456789abcdef0123456789abcdef01234567
FETCH="git -C \"\$RUNNER_TEMP/peal\" fetch -q --depth 1 https://github.com/Maximilian-Walz/peal"
tpl() { # tpl FILE FETCH-TAIL: a template with a Peal fetch line and a uses: line
  printf 'steps:\n  - uses: actions/checkout@%s # v7.0.1\n    run: |\n      %s %s\n      next\n' "$SHA1" "$FETCH" "$2" >"$1"
}
tpl "$dir/plugin/templates/t.yml" "$SHA1 # v0.8.0"
tpl "$dir/.github/workflows/w.yml" "$SHA1 # v0.8.0"
printf 'a: 1\n' >"$dir/.peal/config.yml"
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

T=$dir/plugin/templates/t.yml
sedi() { sed -i.bak "$1" "$2" && rm "$2.bak"; }

sedi 's/# v0.8.0/# v0.9.0/' "$T"
check "template: tag bumped: skip" harnesses=false "$(verdict t-tag)"
reset
tpl "$T" "$SHA2 # v0.8.0"
check "template: SHA changed: skip" harnesses=false "$(verdict t-sha)"
reset
tpl "$T" "$SHA2 # v0.9.0"
check "template: SHA and tag changed: skip" harnesses=false "$(verdict t-both)"
reset
tpl "$T" "$SHA2 # v0.9.0"
printf '# Changelog\n\n## v0.9.0\n' >"$dir/CHANGELOG.md"
sedi 's/0.1.0/0.9.0/' "$dir/plugin/.claude-plugin/plugin.json"
check "a full bump set: skip" harnesses=false "$(verdict t-set)"
reset
sedi 's/      next/      other/' "$T"
check "template: another line changed: run" harnesses=true "$(verdict t-other)"
reset
tpl "$T" "$SHA1 # v0.8.0"; sedi 's|Maximilian-Walz/peal|Maximilian-Walz/other|; s/# v0.8.0/# v0.9.0/' "$T"
check "template: other URL: run" harnesses=true "$(verdict t-url)"
reset
sedi 's/ --depth 1//; s/# v0.8.0/# v0.9.0/' "$T"
check "template: --depth 1 dropped: run" harnesses=true "$(verdict t-depth)"
reset
tpl "$T" "${SHA2:0:39} # v0.9.0"
check "template: short SHA: run" harnesses=true "$(verdict t-short)"
reset
tpl "$T" "$(printf %s "$SHA2" | tr a-f A-F) # v0.9.0"
check "template: uppercase SHA: run" harnesses=true "$(verdict t-upper)"
reset
tpl "$T" "$SHA2 # v0.9"
check "template: tag # v0.9: run" harnesses=true "$(verdict t-short-tag)"
reset
tpl "$T" "$SHA2 # v0.9.0"; printf '      extra\n' >>"$T"
check "template: a second line beside a valid change: run" harnesses=true "$(verdict t-extra)"
reset
sedi "s/checkout@$SHA1 # v7.0.1/checkout@$SHA2 # v7.0.2/" "$T"
check "template: a uses: re-pin: run" harnesses=true "$(verdict t-uses)"
reset
tpl "$dir/.github/workflows/w.yml" "$SHA2 # v0.9.0"
check "the same change in .github/workflows: run" harnesses=true "$(verdict w-both)"
reset
tpl "$dir/plugin/templates/t.txt" "$SHA1 # v0.8.0"; git -C "$dir" add -A; git -C "$dir" commit -qm txt; base=$(git -C "$dir" rev-parse HEAD)
tpl "$dir/plugin/templates/t.txt" "$SHA2 # v0.9.0"
check "a non-.yml under templates: run" harnesses=true "$(verdict t-txt)"
reset
chmod +x "$T"
check "template: a mode-only change: run" harnesses=true "$(verdict t-mode)"
reset
tpl "$T" "$SHA2 # v0.9.0"; printf 'a: 2\n' >"$dir/.peal/config.yml"
check "template change with .peal/config.yml: run" harnesses=true "$(verdict t-config)"
reset

tpl "$T" "$SHA2 # v0.9.0"; printf '++ injected: true\n' >>"$T"
check "template: a valid change and an added '++ ' line: run" harnesses=true "$(verdict t-plus)"
reset
sedi 's/# v0.8.0/# v0.9.0/' "$T"; printf '++ injected: true\n' >>"$T"
check "template: tag bump and an added '++ ' line: run" harnesses=true "$(verdict t-plus2)"
reset
tpl "$T" "$SHA1 # v0.8.0"; printf -- '-- gone\n' >>"$T"; git -C "$dir" add -A; git -C "$dir" commit -qm dash; base=$(git -C "$dir" rev-parse HEAD)
tpl "$T" "$SHA2 # v0.9.0"
check "template: a valid change and a removed '-- ' line: run" harnesses=true "$(verdict t-minus)"
reset
P=$dir/plugin/.claude-plugin/plugin.json
sedi 's/0.1.0/0.2.0/' "$P"; printf '++ x\n' >>"$P"
check "plugin.json: a version bump and an added '++ ' line: run" harnesses=true "$(verdict p-plus)"
reset
printf -- '-- x\n' >>"$P"; git -C "$dir" add -A; git -C "$dir" commit -qm pdash; base=$(git -C "$dir" rev-parse HEAD)
sedi 's/0.1.0/0.2.0/' "$P"; sedi '/^-- x$/d' "$P"
check "plugin.json: a version bump and a removed '-- ' line: run" harnesses=true "$(verdict p-minus)"
reset

check "no base (a new branch): run" harnesses=true "$(cd "$dir" && bash "$REPO/tools/ci-changes.sh" "" HEAD)"
check "an all-zero base (a push that created the branch): run" harnesses=true \
  "$(cd "$dir" && bash "$REPO/tools/ci-changes.sh" 0000000000000000000000000000000000000000 HEAD)"
check "a base git does not have: run" harnesses=true \
  "$(cd "$dir" && bash "$REPO/tools/ci-changes.sh" 1234567890abcdef1234567890abcdef12345678 HEAD)"
check "nothing changed: skip" harnesses=false "$(verdict empty)"

finish
