#!/usr/bin/env bash
# Harness for bin/peal's dispatch and its SessionStart hook (lib/session.sh):
#
#   bash plugin/bin/peal.test.sh
set -uo pipefail
# shellcheck source=../lib/test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/test-lib.sh"

version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$PEAL_ROOT/.claude-plugin/plugin.json")
check "the manifest has a version" "1" "$([ -n "$version" ] && echo 1)"
check "--version" "$version" "$("$PEAL" --version)"
check "version" "$version" "$("$PEAL" version)"
check "--version from elsewhere" "$version" "$(cd / && "$PEAL" --version)"
check "help" "usage: peal <command> [args]" "$("$PEAL" help | head -n1)"
check_refused "no command" "usage: peal" "$PEAL"
check_refused "unknown command" "unknown command 'nope'" "$PEAL" nope
check_refused "frontmatter without a file" "usage: peal" "$PEAL" frontmatter get
check_refused "unknown hook" "usage: peal" "$PEAL" hook nope

# The SessionStart hook records the plugin root in the git directory shared by every
# worktree, only for a repository that uses Peal, and stays silent either way.
project=$(scratch_dir)
git -C "$project" init -q
git -C "$project" -c user.name=t -c user.email=t@t commit -q --allow-empty -m root
out=$(cd "$project" && "$PEAL" hook session-start </dev/null 2>&1)
check "hook: silent" "" "$out"
check "hook: nothing recorded without .peal/" "0" "$([ -e "$project/.git/peal-root" ] && echo 1 || echo 0)"

mkdir "$project/.peal"
(cd "$project" && "$PEAL" hook session-start </dev/null >/dev/null)
check "hook: recorded" "$PEAL_ROOT" "$(cat "$project/.git/peal-root")"

rm "$project/.git/peal-root"
git -C "$project" worktree add -q "$project-wt" 2>/dev/null
scratch+=("$project-wt")
mkdir -p "$project-wt/.peal"
out=$(cd / && CLAUDE_PROJECT_DIR="$project-wt" "$PEAL" hook session-start </dev/null 2>&1)
check "hook: from a worktree, into the common git directory" "$PEAL_ROOT" "$(cat "$project/.git/peal-root")"
check "hook: in a Peal worktree, the orientation" "Peal:" "$(printf '%s\n' "$out" | head -n 1)"

outside=$(scratch_dir)
out=$(cd "$outside" && GIT_CEILING_DIRECTORIES=$outside "$PEAL" hook session-start </dev/null 2>&1)
check "hook: outside a repository, silent and fine" "0:" "$?:$out"

finish
