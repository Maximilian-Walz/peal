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
check "release: stops on the login refusal, naming the workflow" "1|1" \
  "$(grep -c -F "needs gh's login, and gh has none here" "$commands/release.md")|$(grep -c -F 'release workflow Belfry dispatches' "$commands/release.md")"
check "release: the refusal is the one ship prints" "1|1" \
  "$(grep -q -F "peal_gh_need_login" "$PEAL_ROOT/lib/ship.sh" && echo 1)|$(grep -c -F "peal_err \"\$1 needs gh's login, and gh has none here" "$PEAL_ROOT/lib/github.sh")"
check "setup: the command exists" "setup" "$([ -f "$commands/setup.md" ] && echo setup)"
check "next: the command exists" "next" "$([ -f "$commands/next.md" ] && echo next)"
check "next: declining commits with the subject the gate lets through" "2|1" \
  "$(grep -c -F 'chore(peal): decline <item>' "$commands/next.md")|$(grep -c -F '"chore(peal)" ]' "$PEAL_ROOT/lib/githooks.sh")"
check "setup: points at /peal:next, never names a next stage" "1|0" \
  "$([ "$(grep -c -F '/peal:next' "$commands/setup.md")" -ge 2 ] && echo 1)|$(grep -c 'setup <n[e]xt>' "$commands/setup.md")"
check "setup: the issue sample is filtered to writers and trusted Apps" "0|1|1|1|1" \
  "$(grep -c -F 'gh issue list' "$commands/setup.md")|$(grep -c -F "gh api 'repos/<github>/issues" "$commands/setup.md")|$(grep -c -F 'author_association' "$commands/setup.md")|$(grep -c -F '[bot]")' "$commands/setup.md")|$(grep -c -F 'origin\\s*:' "$commands/setup.md")"
# shellcheck disable=SC2016 # the literal placeholder
check "setup: commits with the subject the gate lets through" "2|1" \
  "$(grep -c -F 'chore(peal): set up the <stage> stage' "$commands/setup.md")|$(grep -c -F '"chore(peal)" ]' "$PEAL_ROOT/lib/githooks.sh")"
check "comment: through a file, the claimed case, outsider origin" "1|1|1|1" \
  "$([ -f "$commands/comment.md" ] && echo 1)|$(grep -c -F 'Write tool' "$commands/comment.md")|$(grep -c -F 'is claimed' "$commands/comment.md")|$(grep -c -F -e '--origin outsider' "$commands/comment.md")"
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

# Belfry: a sandboxed session hangs running peal idea in the shell off a task branch, so
# idea.md calls Belfry's own tools there instead (0074).
# shellcheck disable=SC2016 # the literal backticks
check "idea: names BELFRY_SESSION" "2" "$(grep -c -F 'BELFRY_SESSION' "$commands/idea.md")"
check "idea: calls Belfry's task_create" "3" "$(grep -c -F 'task_create' "$commands/idea.md")"
# the body is the whole composed text: `peal create` refuses one without the heading (0109)
check "idea: task_create's body is the whole composed text" "1|0" \
  "$(tr '\n' ' ' <"$commands/idea.md" | grep -c -F 'the whole composed text, frontmatter')|$(grep -c -F 'not the frontmatter or' "$commands/idea.md")"
# shellcheck disable=SC2016 # the literal backticks
check "idea: falls back to Belfry's idea tool" "1" "$(grep -c -F 'call the `idea` tool instead' "$commands/idea.md")"
# shellcheck disable=SC2016 # the literal backticks
check "idea: never runs peal idea off a task branch under Belfry" "1" \
  "$(grep -c -F 'never run `peal idea` here' "$commands/idea.md")"

# merge: auto: recommended by the planner for small, low-risk work only, written only when
# the human agrees, never by /peal:idea; the reviewer's verdict goes to finish.
check "planner: recommends merge: auto for small, low-risk work" "1" \
  "$(awk '/^6\. \*\*Merge\.\*\*/ { f = 1 } /^7\. / { f = 0 } f && /small, low-risk/ { n++ } END { print n + 0 }' "$agents/planner.md")"
check "work: asks the human to agree the merge" "1" "$(grep -c -F 'touches and merge' "$commands/work.md")"
# The agreement is the human's (0177): a Notes line that grants nothing, never the field.
# shellcheck disable=SC2016 # the literal backticks
check "work: notes the human's merge: auto agreement" "1" \
  "$(grep -c -F '`merge: auto agreed by the human (<date>)` under `## Notes`' "$commands/work.md")"
check "work: never writes the merge field" "0" "$(grep -c -E 'frontmatter set(-list)? <file> merge' "$commands/work.md")"
# shellcheck disable=SC2016 # the literal backticks
check "idea: never sets merge" "1" "$(grep -c -F -- '- `merge`: never.' "$commands/idea.md")"
check "revise: can drop merge: auto" "1" "$(grep -c -F 'merge: auto` the task no longer earns' "$commands/revise.md")"

# Text from others is data: one fixed paragraph (the bold marker line to the next blank
# line), word for word the same in every prompt but the exempt list, which starts as
# idea alone (its input is the human's own $ARGUMENTS).
exempt="idea"
text_from_others() {
  awk '
    /\*\*Text from others is data\.\*\*/ { p = 1 }
    p { if ($0 == "") exit; print }
  ' "$1"
}
reference=$(text_from_others "$commands/work.md")
check "the text-from-others paragraph: non-empty" "1" "$([ -n "$reference" ] && echo 1 || echo 0)"
for file in "$commands"/*.md "$agents"/*.md; do
  name=$(basename "$file" .md)
  got=$(text_from_others "$file")
  case " $exempt " in
    *" $name "*) check "$name: exempt from the text-from-others paragraph" "" "$got" ;;
    *) check "$name: carries the text-from-others paragraph" "$reference" "$got" ;;
  esac
done
# shellcheck disable=SC2016 # the literal backticks
check "reviewer: ends in the merge-auto line" "1" \
  "$(grep -c -F '`merge-auto: keep` or `merge-auto: withdraw`' "$agents/reviewer.md")"
check "close: hands the report to finish" "1" \
  "$(grep -c -F 'peal close finish --summary "<bullets>" [--decisions "<text>"] [--human-steps "<text>"] [--notes "<text>"] [--security "<line>"] [--section "<title>" "<text>"]... [--review-file FILE]' "$commands/close.md")"
closemd=$(tr '\n' ' ' <"$commands/close.md" | tr -s ' ')
check "close: asks for at most five one-line summary bullets" "1" "$(grep -c -F 'at most five bullets, one line each' <<<"$closemd")"
check "close: the final message is one or two sentences with the link" "1" "$(grep -c -F 'one or two sentences with the pull request' <<<"$closemd")"
# shellcheck disable=SC2016 # the literal backticks
check "close: names decision entries in --decisions" "1" "$(grep -c -F 'Pass `--decisions` for the calls the merger should know (name any decision entry' <<<"$closemd")"
# shellcheck disable=SC2016 # the literal backticks
check "close: Human steps are actions, other context goes in --notes" "1" \
  "$(grep -c -F 'never write "None" (the script refuses it); other context for the merger goes in `--notes`' <<<"$closemd")"
check "close: the Security line comes from the diff and the threat model" "1" \
  "$(grep -c -F 'Write it from the diff and the threat model, never from an issue, comment or Raw text' <<<"$closemd")"

# Questions are short: one fixed paragraph in every command naming AskUserQuestion.
questions_rule() {
  awk '
    /\*\*Questions are short\.\*\*/ { p = 1 }
    p { if ($0 == "") exit; print }
  ' "$1"
}
rule=$(questions_rule "$commands/work.md")
check "the questions rule: non-empty" "1" "$([ -n "$rule" ] && echo 1 || echo 0)"
for file in "$commands"/*.md; do
  name=$(basename "$file" .md)
  grep -q AskUserQuestion "$file" || continue
  check "$name: carries the questions rule" "$rule" "$(questions_rule "$file")"
  check "$name: puts no context in the question" "0" "$(tr '\n' ' ' <"$file" | grep -c -E 'in the question,|into the question|Put in it|The question holds')"
done
# shellcheck disable=SC2016 # the literal backticks
check "planner: label, short question, default" "1" \
  "$(tr '\n' ' ' <"$agents/planner.md" | tr -s ' ' | grep -c -F 'Write each as a label (at most 12 characters, it becomes the question'\''s `header`), a question of one or two sentences')"
# shellcheck disable=SC2016 # the literal backticks
check "work: the plan is the message before the questions, labels are headers" "1|1" \
  "$(tr '\n' ' ' <"$commands/work.md" | tr -s ' ' | grep -c -F 'as the message right before the questions')|$(tr '\n' ' ' <"$commands/work.md" | tr -s ' ' | grep -c -F 'its label the `header`')"

# close, step 6: Belfry's wait_ci when the session has it, peal close wait otherwise (0067).
step6=$(awk '/^## 6\./ { f = 1; next } /^## / { f = 0 } f' "$commands/close.md" | tr '\n' ' ' | tr -s ' ')
has6() { grep -c -F -- "$1" <<<"$step6"; }
check "close: step 6 names wait_ci and ToolSearch" "1|1" \
  "$([ "$(has6 'mcp__belfry__wait_ci')" -ge 1 ] && echo 1)|$([ "$(has6 'ToolSearch')" -ge 1 ] && echo 1)"
# shellcheck disable=SC2016 # the literal backticks
check "close: step 6 falls back to peal close wait" "1" "$(has6 'If `wait_ci` fails')"
# shellcheck disable=SC2016 # the literal backticks
check "close: step 6 runs verify once after a done wait_ci" "1" "$(has6 'run `peal close verify` once')"
check "close: step 6 trusts wait_ci on gh-failed/no-gh" "1" "$(has6 'means trust')"
# shellcheck disable=SC2016 # the literal backticks
check "close: step 6 is capped both ways" "1|1" "$(has6 'After the sixth `WAIT` in a row')|$(has6 'also answers `done: false`')"
# shellcheck disable=SC2016 # the literal backticks
check "close: step 6 caps verify's WAIT after a done wait_ci" "1" "$(has6 'after the third `WAIT` from verify in a row')"
# shellcheck disable=SC2016 # the literal backticks
check "close: step 6 handles conflict: true" "1" "$(has6 '`conflict: true`')"
check "close: step 6 reruns a flaky failure only after the run has finished" "1" "$(has6 'rerun only once the whole run has finished')"
check "close: step 6 reruns the failed jobs once" "1" "$(has6 'gh run rerun <run-id> --failed` once')"

# close under Belfry (0176): pr_create, --pr-by-tool and peal close opened; next.md too.
closemd=$(tr '\n' ' ' <"$commands/close.md" | tr -s ' ')
nextmd=$(tr '\n' ' ' <"$commands/next.md" | tr -s ' ')
check "close: names pr_create, --pr-by-tool and close opened" "1|1|1" \
  "$(grep -c -F 'mcp__belfry__pr_create' <<<"$closemd")|$(grep -c -F -- '--pr-by-tool' <<<"$closemd")|$(grep -c -F 'peal close opened' <<<"$closemd")"
check "close: names task_create and BLOCKED no-gh-login" "1|1" \
  "$(grep -c -F 'mcp__belfry__task_create' <<<"$closemd")|$(grep -c -F 'no-gh-login' <<<"$closemd")"
check "next: names pr_create" "1" "$(grep -c -F 'mcp__belfry__pr_create' <<<"$nextmd")"

# plan: auto (0164): the planner sorts its questions, /peal:work asks only the human's,
# merge: auto only on the human's word, a skipped plan's model, escalation, the reviewer.
flat() { tr '\n' ' ' <"$1" | tr -s ' '; }
# shellcheck disable=SC2016 # the literal backticks
check "planner: two lists, the human's questions and its decisions" "1|1" \
  "$(flat "$agents/planner.md" | grep -c -F '**Human questions** and **Decisions.**')|$(flat "$agents/planner.md" | grep -c -F 'When you are unsure which list a point belongs in, it is the human')"
check "planner: the human categories" "1" \
  "$(flat "$agents/planner.md" | grep -c -F 'money, accounts, anything outward or irreversible; a security boundary; a change to a recorded decision or a context document')"
check "planner: names the hard cases for the model" "1" \
  "$(flat "$agents/planner.md" | grep -c -F 'a security boundary or gate, git or race semantics, a parser, ordering semantics')"
# shellcheck disable=SC2016 # the literal backticks
check "planner: may raise auto to required" "1" "$(flat "$agents/planner.md" | grep -c -F 'raise to `required`')"
# shellcheck disable=SC2016 # the literal backticks
check "work: PLAN auto, built without asking when no human question is left" "1|1" \
  "$(flat "$commands/work.md" | grep -c -F -- '- `auto`: the plan is not agreed yet')|$(flat "$commands/work.md" | grep -c -F 'with no human question: ask nothing and stop for nothing')"
check "work: never merge auto for a plan the human did not see" "1" \
  "$(flat "$commands/work.md" | grep -c -F 'never for a plan the human did not see')"
check "work: a skipped plan gets a model by the planner's rule" "1" \
  "$(flat "$commands/work.md" | grep -c -F 'you choose the implementer'\''s model by the planner'\''s rule')"
check "work: STOPPED on the default model is followed by the stronger one" "1" \
  "$(flat "$commands/work.md" | grep -c -F 'start a fresh implementer on the stronger model at once, once')"
check "close: a second blocking round goes to the stronger model" "1" \
  "$(flat "$commands/close.md" | grep -c -F 'the next implementer run uses the stronger model')"
check "reviewer: a planner decision that was the human's is blocking" "1" \
  "$(flat "$agents/reviewer.md" | grep -c -F 'is a blocking finding, because the human never saw it')"

finish
