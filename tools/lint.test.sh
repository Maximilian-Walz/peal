#!/usr/bin/env bash
# Harness for tools/lint.sh's file list:
#
#   bash tools/lint.test.sh
#
# - `--list` shows exactly the repository's readable scripts: tracked or untracked and not
#   ignored, never an ignored file, a symlink, a deleted tracked file or an unreadable one;
# - it says nothing on stderr about files it cannot open;
# - the full run fails, naming the fix, when .peal/peal differs from plugin/templates/launcher
#   or is missing, and says nothing about it when they match;
# - the full run fails, naming the file, when docs/security.md names a guard that .belfry.yml's
#   lists do not cover (tools/guards.sh);
# - outside a git repository it exits 2 (the search is broken).
set -uo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../plugin/lib/test-lib.sh
. "$REPO/plugin/lib/test-lib.sh"

dir=$(scratch_dir)
mkdir -p "$dir/repo/tools" "$dir/repo/sub" "$dir/plain/tools"
cp "$REPO/tools/lint.sh" "$dir/repo/tools/lint.sh"
cp "$REPO/tools/lint.sh" "$dir/plain/tools/lint.sh"
cd "$dir/repo" || exit 2
git init -q .
printf '*.ignored\n' >.gitignore
printf 'echo a\n' >sub/a.sh
printf '#!/usr/bin/env bash\n' >bashbin
printf '#!/bin/sh\n' >shbin
printf '#!/usr/bin/env bash\n' >tracked-gone
printf 'not a script\n' >notes.txt
printf '#!/bin/bash\n' >x.ignored
printf '#!/bin/bash\n' >locked
chmod 000 locked
ln -s sub/a.sh link.sh
git add .gitignore sub/a.sh tools/lint.sh tracked-gone notes.txt
git -c user.name=t -c user.email=t@t commit -qm init
rm tracked-gone

expected=$(printf '%s\n' bashbin shbin sub/a.sh tools/lint.sh | sort)
# A mode-000 file is still readable by root: skip that case then.
[ "$(id -u)" -ne 0 ] || { rm -f locked; echo "note: root, unreadable-file case skipped"; }

err=$(bash tools/lint.sh --list 2>&1 >"$dir/out"); status=$?
check "--list exits 0" 0 "$status"
check "--list is quiet" "" "$err"
check "--list names exactly the readable scripts" "$expected" "$(sort "$dir/out")"

cd "$dir/plain" || exit 2
check_refused "outside a git repository" "no shell scripts found" bash tools/lint.sh --list

# The launcher step, in its own scratch repository (the other steps' output is ignored).
mkdir -p "$dir/l/tools" "$dir/l/.peal" "$dir/l/plugin/templates"
cp "$REPO/tools/lint.sh" "$dir/l/tools/lint.sh"
printf '#!/usr/bin/env bash\necho launcher\n' >"$dir/l/plugin/templates/launcher"
cp "$dir/l/plugin/templates/launcher" "$dir/l/.peal/peal"
# Stubs that succeed, so the exit status is the launcher step's alone.
mkdir -p "$dir/l/plugin/bin" "$dir/l/stub"
printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/l/tools/pins.sh"
cp "$dir/l/tools/pins.sh" "$dir/l/plugin/bin/peal"
cp "$dir/l/tools/pins.sh" "$dir/l/tools/guards.sh"
cp "$dir/l/tools/pins.sh" "$dir/l/stub/shellcheck"
chmod +x "$dir/l/tools/pins.sh" "$dir/l/tools/guards.sh" "$dir/l/plugin/bin/peal" "$dir/l/stub/shellcheck"
cd "$dir/l" || exit 2
git init -q .
out=$(PATH="$dir/l/stub:$PATH" bash tools/lint.sh 2>&1); status=$?
check "launcher: identical exits 0" "0" "$status"
check "launcher: identical is silent" "0" "$(printf '%s\n' "$out" | grep -c 'differs from plugin/templates/launcher')"
printf 'x' >>.peal/peal
out=$(PATH="$dir/l/stub:$PATH" bash tools/lint.sh 2>&1); status=$?
check "launcher: differing is named" "1" "$(printf '%s\n' "$out" | grep -c 'peal init --stage tasks')"
check "launcher: differing exits non-zero" "1" "$([ "$status" -ne 0 ] && echo 1 || echo 0)"
rm .peal/peal
out=$(PATH="$dir/l/stub:$PATH" bash tools/lint.sh 2>&1); status=$?
check "launcher: missing is named" "1" "$(printf '%s\n' "$out" | grep -c 'peal init --stage tasks')"
check "launcher: missing exits non-zero" "1" "$([ "$status" -ne 0 ] && echo 1 || echo 0)"

# The guards step, with the real tools/guards.sh over fixtures: restore the launcher, then
# a guard named in docs/security.md but in no list fails lint, naming the file.
cp "$dir/l/plugin/templates/launcher" .peal/peal
cp "$REPO/tools/guards.sh" tools/guards.sh
mkdir -p docs
printf 'policy:\n  never_auto_merge: []\n  review_before_merge:\n    paths:\n      - plugin/lib/a.sh\n' >.belfry.yml
# shellcheck disable=SC2016 # backticks are literal
printf -- '- Guard: `plugin/lib/a.sh`\n' >docs/security.md
out=$(PATH="$dir/l/stub:$PATH" bash tools/lint.sh 2>&1); status=$?
check "guards: covered exits 0" "0" "$status"
# shellcheck disable=SC2016
printf -- '- Guard: `plugin/lib/a.sh`, `plugin/lib/gone.sh`\n' >docs/security.md
out=$(PATH="$dir/l/stub:$PATH" bash tools/lint.sh 2>&1); status=$?
check "guards: uncovered names the file" "1" "$(printf '%s\n' "$out" | grep -c 'plugin/lib/gone.sh')"
check "guards: uncovered exits non-zero" "1" "$([ "$status" -ne 0 ] && echo 1 || echo 0)"

chmod 600 "$dir/repo/locked" 2>/dev/null
finish
