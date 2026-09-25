#!/usr/bin/env bash
# Harness for the plugin's commands (plugin/commands/*.md), what can be checked without a
# session running them:
#
#   bash plugin/commands/commands.test.sh
#
# Each has frontmatter with a description, takes its arguments, and names only peal
# subcommands the CLI has: a command calling one renamed or never built fails here, not
# in a session. The fields a plan settles: the planner proposes touches, /peal:work
# writes them once the human agrees, /peal:idea only when the idea names the files; the
# planner recommends merge: auto, /peal:work writes it only on the human's word, the
# reviewer's merge-auto line reaches peal close finish.
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
check "releases: the command exists" "release" "$([ -f "$commands/release.md" ] && echo release)"
check "setup: the command exists" "setup" "$([ -f "$commands/setup.md" ] && echo setup)"
check "setup: the issue sample is filtered to write access" "0|1" \
  "$(grep -c -F 'gh issue list --limit 20)' "$commands/setup.md")|$(grep -c -F 'authorAssociation' "$commands/setup.md")"
# shellcheck disable=SC2016 # the literal placeholder
check "setup: commits with the subject the gate lets through" "2|1" \
  "$(grep -c -F 'chore(peal): set up the <stage> stage' "$commands/setup.md")|$(grep -c -F '"chore(peal)" ]' "$PEAL_ROOT/lib/githooks.sh")"
check "the backlog commands exist" "defer idea retire revise split" \
  "$(for c in defer idea retire revise split; do [ -f "$commands/$c.md" ] && printf '%s ' "$c"; done | sed 's/ $//')"

# touches: proposed by the planner, recorded by /peal:work with the plan, set by
# /peal:idea only from the idea's own words.
agents=$PEAL_ROOT/agents
check "planner: proposes touches in its Files" "1" \
  "$(awk '/^3\. \*\*Files\.\*\*/ { f = 1 } /^4\. / { f = 0 } f && /`Touches:`/ { n++ } END { print n + 0 }' "$agents/planner.md")"
check "planner: leaves the model, the touches and the merge to the main session" "3" "$(grep -c 'You do not write it;' "$agents/planner.md")"
check "work: asks the human to agree the touches" "1" \
  "$(grep -c -F 'size, touches' "$commands/work.md")"
check "work: records the agreed touches" "1" \
  "$(grep -c -F 'peal frontmatter set-list <file> touches' "$commands/work.md")"
check "work: records them before peal record" "touches plan" \
  "$(grep -o -E 'set-list <file> touches|peal record <id> plan' "$commands/work.md" | awk '{ print $NF }' | paste -sd' ' -)"
# shellcheck disable=SC2016 # the literal backticks
check "idea: touches only when the idea names the files" "1|1" \
  "$(grep -c -F -- '- `touches`: only when the idea names' "$commands/idea.md")|$(grep -c '^touches: \[' "$commands/idea.md")"

# merge: auto: recommended by the planner for small, low-risk work only, written only when
# the human agrees, never by /peal:idea; the reviewer's verdict goes to finish.
check "planner: recommends merge: auto for small, low-risk work" "1" \
  "$(awk '/^6\. \*\*Merge\.\*\*/ { f = 1 } /^7\. / { f = 0 } f && /small, low-risk/ { n++ } END { print n + 0 }' "$agents/planner.md")"
check "work: asks the human to agree the merge" "1" "$(grep -c -F 'touches and merge' "$commands/work.md")"
check "work: writes merge: auto only when the human agreed" "1" \
  "$(grep -c -F 'peal frontmatter set <file> merge auto` only when the human agreed' "$commands/work.md")"
# shellcheck disable=SC2016 # the literal backticks
check "idea: never sets merge" "1" "$(grep -c -F -- '- `merge`: never.' "$commands/idea.md")"
check "revise: can drop merge: auto" "1" "$(grep -c -F 'merge: auto` the task no longer earns' "$commands/revise.md")"
# shellcheck disable=SC2016 # the literal backticks
check "reviewer: ends in the merge-auto line" "1" \
  "$(grep -c -F '`merge-auto: keep` or `merge-auto: withdraw`' "$agents/reviewer.md")"
check "close: hands the report to finish" "1" \
  "$(grep -c -F 'peal close finish --summary "<bullets>" [--section "<title>" "<text>"]... [--review-file FILE]' "$commands/close.md")"

finish
