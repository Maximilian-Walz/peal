#!/usr/bin/env bash
# Harness for the plugin's commands (plugin/commands/*.md), what can be checked without a
# session running them:
#
#   bash plugin/commands/commands.test.sh
#
# Each has frontmatter with a description, takes its arguments, and names only peal
# subcommands the CLI has: a command calling one renamed or never built fails here, not
# in a session.
set -uo pipefail
# shellcheck source=../lib/test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/test-lib.sh"

commands=$PEAL_ROOT/commands
# The subcommands the usage lists, the first word after two spaces.
known=$("$PEAL" --help | awk '/^  [a-z]/ { print $1 }' | sort -u)

for file in "$commands"/*.md; do
  name=$(basename "$file" .md)
  check "$name: frontmatter with a description" "---|1" \
    "$(head -n 1 "$file")|$(awk 'NR > 1 && $0 == "---" { exit } /^description: ./ { n++ } END { print n + 0 }' "$file")"
  # shellcheck disable=SC2016 # the literal placeholder
  check "$name: takes its arguments" "1" "$(grep -c -m 1 -F '$ARGUMENTS' "$file")"
  # `peal <sub>` in code spans and in lines of code blocks.
  used=$(grep -o -E '(^|`)peal [a-z-]+' "$file" | sed -E 's/^`?peal //' | sort -u)
  for sub in $used; do
    check "$name: peal $sub exists" "$sub" "$(grep -x -F -- "$sub" <<<"$known")"
  done
done

check "a milestone's end: the commands exist" "drift milestone-review" \
  "$(for c in drift milestone-review; do [ -f "$commands/$c.md" ] && printf '%s ' "$c"; done | sed 's/ $//')"
check "the backlog commands exist" "defer idea retire revise split" \
  "$(for c in defer idea retire revise split; do [ -f "$commands/$c.md" ] && printf '%s ' "$c"; done | sed 's/ $//')"

finish
