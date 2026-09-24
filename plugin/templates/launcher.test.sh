#!/usr/bin/env bash
# Harness for templates/launcher, the .peal/peal a project commits:
#
#   bash plugin/templates/launcher.test.sh
#
# It finds Peal through $PEAL_ROOT, then the root recorded in the git directory, then the
# newest Peal in Claude Code's plugin cache, and otherwise fails with an install hint.
set -uo pipefail
# shellcheck source=../lib/test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/test-lib.sh"

LAUNCHER="$PEAL_ROOT/templates/launcher"

# fake DIR NAME -> a stand-in Peal at DIR that prints NAME and its arguments.
fake() {
  mkdir -p "$1/bin"
  printf '#!/bin/sh\necho "%s $*"\n' "$2" >"$1/bin/peal"
  chmod +x "$1/bin/peal"
}

project=$(scratch_dir)
home=$(scratch_dir)
git -C "$project" init -q
mkdir -p "$project/.peal"
cp "$LAUNCHER" "$project/.peal/peal"
run() {
  (cd "$project" && env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$@")
}

check_fails "nothing installed: an install hint" 127 \
  "claude plugin marketplace add Maximilian-Walz/peal*claude plugin install peal@peal" \
  run .peal/peal --version

cache="$home/plugins/cache"
fake "$cache/peal/peal/0.1.0" old
fake "$cache/other-market/peal/abc123" newer
fake "$cache/peal/unrelated/9.9.9" unrelated
touch -t 202601010000 "$cache/peal/peal/0.1.0"
touch -t 202602010000 "$cache/other-market/peal/abc123"
touch -t 202603010000 "$cache/peal/unrelated/9.9.9"
check "cache: the newest Peal, arguments passed" "newer --version a b" "$(run .peal/peal --version 'a b')"
touch -t 202604010000 "$cache/peal/peal/0.1.0"
check "cache: the newest by time, not by name" "old x" "$(run .peal/peal x)"

fake "$project-recorded" recorded
scratch+=("$project-recorded")
printf '%s\n' "$project-recorded" >"$project/.git/peal-root"
check "recorded root before the cache" "recorded x" "$(run .peal/peal x)"
git -C "$project" -c user.name=t -c user.email=t@t commit -q --allow-empty -m root
git -C "$project" worktree add -q "$project-wt" 2>/dev/null
scratch+=("$project-wt")
mkdir -p "$project-wt/.peal"
cp "$LAUNCHER" "$project-wt/.peal/peal"
check "recorded root, from a worktree" "recorded x" "$(cd / && env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$project-wt/.peal/peal" x)"
printf '%s\n' "$project-gone" >"$project/.git/peal-root"
check "stale recorded root: the cache" "old x" "$(run .peal/peal x)"

fake "$project-env" env
scratch+=("$project-env")
check "PEAL_ROOT before everything" "env x" "$(run env PEAL_ROOT="$project-env" .peal/peal x)"
check_fails "PEAL_ROOT without Peal is an error" 127 "holds no bin/peal" \
  run env PEAL_ROOT="$project-gone" .peal/peal x

# End to end: the real hook records the real plugin, and the launcher runs it.
rm -f "$project/.git/peal-root"
(cd "$project" && "$PEAL" hook session-start </dev/null)
version=$("$PEAL" --version)
check "end to end: hook, then launcher" "$version" "$(run .peal/peal --version)"

finish
