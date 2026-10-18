#!/usr/bin/env bash
# Harness for tools/lint.sh's file list:
#
#   bash tools/lint.test.sh
#
# - `--list` shows exactly the repository's readable scripts: tracked or untracked and not
#   ignored, never an ignored file, a symlink, a deleted tracked file or an unreadable one;
# - it says nothing on stderr about files it cannot open;
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

chmod 600 "$dir/repo/locked" 2>/dev/null
finish
