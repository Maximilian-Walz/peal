#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq's $variables, not the shell's
# Harness for the issues storage (lib/store-issues.sh and its awk), through the peal CLI,
# against throwaway repositories whose GitHub is lib/fake-gh:
#
#   bash plugin/lib/store-issues.test.sh
#
# What the task-file harnesses cover, on issues: every state (the label, the refs, the
# pull requests), the depends expansion, the board and the overview, priority and touches labels,
# and the same
# records as task files for the same tasks; read, create, revise, set-milestone,
# comment, retire and finish; offer, claim and release, with a claim made by Belfry's
# conventions resumed and Peal's claim recognised by Belfry's; the session hooks and
# the idea queue on an issue's branch.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

if ! command -v jq >/dev/null; then
  echo "store-issues.test.sh: no jq here, which the fake gh needs; skipped" >&2
  [ -z "${PEAL_REQUIRE_JQ-}" ] || exit 1
  exit 0
fi

peal() { at "$work" "$PEAL" "$@"; }
list() { at "$work" "$PEAL" list "$@"; }
calls() { grep -c "$1" "$FAKE_GH/log"; }

# hook DIR NAME JSON -> the hook NAME run in DIR with JSON on stdin, "status:output".
hook() {
  local out
  out=$(cd "$1" && "$PEAL" hook "$2" <<<"$3" 2>&1)
  printf '%s:%s' "$?" "$out"
}

# belfry_claim N -> issue N claimed as Belfry's github-issues backend claims it: the
# worker's worktree <clone>-wt/issue-N on issue/N (from origin's issue/N when it exists,
# else origin/main), then the server's label.
belfry_claim() {
  local dir
  dir=$(dirname "$work")/work-wt/issue-$1
  if git -C "$work" rev-parse -q --verify "refs/remotes/origin/issue/$1" >/dev/null; then
    git -C "$work" worktree add -q --track -b "issue/$1" "$dir" "origin/issue/$1" 2>/dev/null
  else
    git -C "$work" worktree add -q --no-track -b "issue/$1" "$dir" origin/main 2>/dev/null
  fi
  gh_save issues 'map(if .number == $n then .labels += [{name: "in progress"}] else . end)' --argjson n "$1"
}

# belfry_sees N -> what Belfry makes of issue N's claim: whether its worker would reuse
# a worktree (IssueWorktree: <clone>-wt/issue-N holding a .git) and its state from the
# label.
belfry_sees() {
  local dir state=free
  dir=$(dirname "$work")/work-wt/issue-$1
  labels "$1" | tr ',' '\n' | grep -qx "in progress" && state=claimed-live
  if [ -e "$dir/.git" ] && [ "$(git -C "$dir" symbolic-ref --short HEAD)" = "issue/$1" ]; then
    echo "reusing $dir, $state"
  else
    echo "a new worktree, $state"
  fi
}

states() {
  local work err
  issues_repo
  check "empty: nothing" "0:" "$(list 2>&1; echo "$?:")"
  check "empty: nothing, really" "" "$(list 2>&1)"

  issue 1 "Free task" --milestone m1
  issue 2 "Done task" --closed
  issue 3 "Blocked task" --body $'Why.\n\nDepends on #1'
  issue 4 "Labelled task" --label "in progress"
  issue 5 "Remote task" --label "in progress"
  git -C "$work" push -q origin origin/main:refs/heads/issue/5 2>/dev/null
  git -C "$work" fetch -q origin
  issue 6 "Live task"
  git -C "$work" worktree add -q -b issue/6 "$work-6" origin/main 2>/dev/null
  scratch+=("$work-6")
  issue 7 "Parked task" --label "in progress"
  git -C "$work" worktree add -q -b issue/7 "$work-7" origin/main 2>/dev/null
  git -C "$work-7" commit -q --allow-empty -m wip
  git -C "$work" worktree remove "$work-7"
  issue 8 "Merging task"
  pr 9 $'Does it.\n\nFixes #8'
  issue 10 "Draft task" --label "in progress"
  pr 11 "closes #10" --draft
  git -C "$work" worktree add -q -b issue/10 "$work-10" origin/main 2>/dev/null
  scratch+=("$work-10")
  git -C "$work-10" commit -q --allow-empty -m work
  issue 12 "Stranger's pull request"
  pr 13 "Fixes #12" --fork NONE
  issue 14 "Collaborator's pull request"
  pr 15 "Resolves #14 and prefixes #1" --fork COLLABORATOR
  issue 16 "Closed pull request"
  pr 17 "Fixes #16" --closed
  issue 18 "Retired task" --not-planned
  issue 19 "Opened by a stranger" --assoc NONE
  issue 20 "Stale branch"
  git -C "$work" branch -q issue/20 origin/main

  check "every state" "1 free free-task m1
2 done done-task
3 blocked blocked-task needs:1
4 claimed-live labelled-task labelled
5 claimed-live remote-task remote:origin
6 claimed-live live-task wt:$work-6
7 parked parked-task 1 commit(s) ahead, last $today
8 awaiting-merge merging-task pr:#9 https://github.com/acme/widgets/pull/9
10 awaiting-merge draft-task pr:#11 https://github.com/acme/widgets/pull/11 draft wt:$work-10 unpushed
12 free stranger-s-pull-request -
14 awaiting-merge collaborator-s-pull-request pr:#15 https://github.com/acme/widgets/pull/15
16 free closed-pull-request -
18 done retired-task
20 free stale-branch -" "$(list 2>&1)"
  check "--no-pr: the pull requests are read all the same" "8 awaiting-merge merging-task pr:#9 https://github.com/acme/widgets/pull/9" \
    "$(list --no-pr 8 2>&1)"
  check "--state and ids" "4 claimed-live labelled-task labelled
6 claimed-live live-task wt:$work-6" "$(list --state claimed-live 4 6 20 2>&1)"
  check_refused "list: no id" "list: '1x' is no task id" list 1x

  # From another worktree: the same answer.
  check "any worktree, the same answer" "$(list 2>&1)" "$(at "$work-6" "$PEAL" list 2>&1)"

  # A filter label: only its issues are tasks, whoever opened them, and it is no field.
  issues_repo_label
  check "label: only its issues, whoever opened them" "2 free labelled-by-a-stranger -
3 free labelled-sized -" "$(list 2>&1)"
  check "label: no field" "---
size: M
---

# 3 — Labelled sized" "$(peal read 3 2>&1)"
  check "label: asked for" "1" "$(calls 'issues?state=open&per_page=100&labels=tasks$')"

  # A task depending on an issue older than the closed ones listed: read on its own.
  issues_repo
  issue 1 "Long done" --closed
  issue 2 "Recently done" --closed
  issue 3 "Waits for old" --body "Depends on #1"
  issue 4 "Waits for nothing" --body "Depends on #99"
  err=$(PEAL_ISSUES_CLOSED=1 list 2>&1 >/dev/null)
  check "an older dependency is read" "2 done recently-done
3 free waits-for-old -
4 blocked waits-for-nothing needs:99" "$(PEAL_ISSUES_CLOSED=1 list 2>/dev/null)"
  check "an unknown dependency warns" "peal: warning: task 4 depends on 99, which is no task" "$err"

  # gh failing is an error, not an empty list.
  printf 'GET repos/acme/widgets/pulls*' >"$FAKE_GH/fail"
  check_refused "gh failing" "gh api repos/acme/widgets/pulls?state=open&per_page=100 failed: gh: HTTP 502" list
  rm -f "$FAKE_GH/fail"
}

# issues_repo_label -> issues_repo with the filter label tasks, and issues around it.
issues_repo_label() {
  ISSUES_CONFIG='    label: tasks
' issues_repo
  issue 1 "Not labelled"
  issue 2 "Labelled by a stranger" --label tasks --assoc NONE
  issue 3 "Labelled sized" --label tasks --label "size: M"
}

expansion() {
  local work err
  issues_repo
  issue 1 "M one a" --milestone m1
  issue 2 "M one done" --milestone m1 --closed
  issue 3 "M one review" --milestone m1 --body "Depends on milestone"
  issue 4 "Waits for human" --body $'Depends on human, #1\n\n## Raw\n\nsaid'
  issue 5 "Prose depends" --body "Depends on the weather"
  issue 6 "Mixed depends" --body "Depends on #2 and later #1"
  issue 10 "Origin task"
  issue 11 "Piece one" --body "Part of #10"
  issue 12 "Piece two" --body "part of: #10"
  issue 13 "Piece two a" --closed --body "Part of #12"
  issue 14 "Waits for split" --body "Depends on #10"
  check "milestone, human, prose, splits" "1 free m-one-a m1
2 done m-one-done
3 blocked m-one-review needs:1
4 blocked waits-for-human needs:human,1
5 free prose-depends -
6 free mixed-depends -
10 free origin-task - split:10 1/4
11 free piece-one - split:10 1/4
12 free piece-two - split:12 1/2
13 done piece-two-a
14 blocked waits-for-split needs:10,11,12" "$(list 2>&1)"
  check "read: the prose stays in the body" "---
depends: [2]
---

# 6 — Mixed depends

Depends on #2 and later #1" "$(peal read 6 2>&1)"
}

board() {
  local work out
  issues_repo
  issue 1 'Say "hi" \ bye' --milestone m1 --label "plan: required" --label "size: M" --label "needs: display" \
    --label "needs:gpu" --label "kind: bug" --body "Depends on human"
  issue 2 "Piece task" --label "model: opus" --body "Part of #1"
  issue 3 "Merging task"
  pr 4 "Fixes #3"
  out=$(peal board 2>&1)
  check "board" '{"id":"1","state":"blocked","slug":"say-hi-bye","title":"Say \"hi\" \\ bye","milestone":"m1","depends":["human"],"size":"M","plan":"required","needs":["display","gpu"],"url":"https://github.com/acme/widgets/issues/1"}
{"id":"2","state":"free","slug":"piece-task","title":"Piece task","part_of":"1","url":"https://github.com/acme/widgets/issues/2"}
{"id":"3","state":"awaiting-merge","slug":"merging-task","title":"Merging task","pr":"#4","url":"https://github.com/acme/widgets/issues/3"}
{"milestone":{"id":"m1","title":"m1","state":"current","order":1,"due":"2026-10-01"}}
{"milestone":{"id":"m2","title":"m2","state":"open","order":2,"due":"2026-12-01"}}
{"milestone":{"id":"m0","title":"m0","state":"done","order":3}}
{"milestone":{"id":"m3","title":"m3","state":"parked","order":4,"reason":"until later"}}' "$out"
  check "milestones" "m1 current 1 2026-10-01 m1
m2 open 2 2026-12-01 m2
m0 done 3 - m0
m3 parked 4 - m3" "$(peal milestones 2>&1)"

  issues_repo
  issue 1 "Current task" --milestone m1
  issue 2 "Current done" --milestone m1 --closed
  issue 3 "Unassigned task"
  issue 4 "Open task" --milestone m2 --body "Depends on #1"
  issue 5 "Parked task" --milestone m3
  issue 6 "Left behind" --milestone m0
  check "overview" "m1 (current) — 1 open, 1 done
  1  free           current-task

No milestone — 1 open, 0 done
  3  free           unassigned-task

m2 (open) — 1 open, 0 done
  4  blocked        open-task  needs:1

m3 (parked) — 1 open, 0 done
  5  free           parked-task

m0 (done) — 1 open, 0 done
  6  free           left-behind" "$(peal overview 2>&1 | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
}

# normal -> the list or board on stdin without the ids' leading zeros, paths and urls.
normal() {
  sed -E -e 's/(^|[^0-9])0+([1-9])/\1\2/g' -e 's/(^|[^0-9])0+([1-9])/\1\2/g' -e 's/,"(path|url)":"[^"]*"//'
}

# The same tasks as task files and as issues give the same list and board, but for the
# ids' zeros and where the task is (path or url).
parity() {
  local work files issues
  work=$(repo)
  ID=0001 TITLE="Title of 1" put "$work" backlog 0001 title-of-1 "milestone: m1"
  ID=0002 TITLE="Title of 2" put "$work" "done" 0002 title-of-2
  ID=0003 TITLE="Title of 3" put "$work" backlog 0003 title-of-3 "depends: [0001]"
  ID=0004 TITLE="Title of 4" put "$work" backlog 0004 title-of-4 "part-of: 0001" "size: M" "plan: required" \
    "needs: [gpu, display]" "depends: [human, 0002]"
  ID=0005 TITLE="Title of 5" put "$work" backlog 0005 title-of-5 "milestone: m2" "depends: [milestone]"
  ID=0006 TITLE="Title of 6" put "$work" backlog 0006 title-of-6 "milestone: m2"
  ID=0007 TITLE="Title of 7" put "$work" backlog 0007 title-of-7 "priority: low"
  ID=0008 TITLE="Title of 8" put "$work" backlog 0008 title-of-8
  ID=0009 TITLE="Title of 9" put "$work" backlog 0009 title-of-9 "priority: high"
  ID=0010 TITLE="Title of 10" put "$work" backlog 0010 title-of-10 "priority: urgent"
  ID=0011 TITLE="Title of 11" put "$work" backlog 0011 title-of-11 "owner: human"
  ID=0012 TITLE="Title of 12" put "$work" backlog 0012 title-of-12 "depends: [0011]"
  files=$work
  issues_repo
  issue 1 "Title of 1" --milestone m1
  issue 2 "Title of 2" --closed
  issue 3 "Title of 3" --body "Depends on #1"
  issue 4 "Title of 4" --label "size: M" --label "plan: required" --label "needs: gpu" --label "needs: display" \
    --body $'Part of #1\nDepends on human, #2'
  issue 5 "Title of 5" --milestone m2 --body "Depends on milestone"
  issue 6 "Title of 6" --milestone m2
  issue 7 "Title of 7" --label "priority: low"
  issue 8 "Title of 8"
  issue 9 "Title of 9" --label "priority: high"
  issue 10 "Title of 10" --label "priority: urgent"
  issue 11 "Title of 11" --label "owner: human"
  issue 12 "Title of 12" --body "Depends on #11"
  issues=$work
  check "parity: list" "$(at "$files" "$PEAL" list --no-pr 2>&1 | normal)" "$(at "$issues" "$PEAL" list 2>&1)"
  check "parity: board" "$(at "$files" "$PEAL" board --no-pr 2>&1 | grep -v '^{"milestone"' | normal)" \
    "$(at "$issues" "$PEAL" board 2>&1 | grep -v '^{"milestone"' | normal)"
  check "parity: milestones" "$(at "$files" "$PEAL" milestones | cut -d' ' -f1,2 | sort)" \
    "$(at "$issues" "$PEAL" milestones | cut -d' ' -f1,2 | sort)"
  check "parity: offer" "$(at "$files" "$PEAL" offer current,unassigned,m2 --top 9 2>&1 | normal)" \
    "$(at "$issues" "$PEAL" offer current,unassigned,m2 --top 9 2>&1)"
  check "parity: a human task, and one waiting on it" "11 free title-of-11 - owner:human
12 blocked title-of-12 needs:11" "$(at "$issues" "$PEAL" list 2>&1 | grep -e '^11 ' -e '^12 ')"
  check "parity: the offer's order" "10 9 8 7" "$(at "$issues" "$PEAL" offer unassigned --top 9 2>&1 | cut -d' ' -f2 | paste -sd' ' -)"
  work=$issues
  check "parity: read" "---
plan: required
size: M
depends: [human, 2]
part-of: 1
needs: [gpu, display]
---

# 4 — Title of 4" "$(peal read 4 2>&1)"
}

writes() {
  local work out n
  ISSUES_CONFIG='task:
  fields:
    kind: [bug, feature]
' issues_repo
  issue 1 "An origin" --milestone m1
  issue 2 "Old done" --closed

  # create: the frontmatter to milestone, labels and reference lines.
  out=$(peal create a-new-thing < <(TITLE="A new thing" text "milestone: m1" "size: S" "plan: skipped" \
    "needs: [gpu]" "depends: [1, human]" "kind: bug") 2>&1)
  check "create" "0:filed 3 https://github.com/acme/widgets/issues/3 — milestone: m1, plan: skipped, size: S — \"A new thing\"" "$?:$out"
  check "create: the title, milestone and labels" "A new thing|m1|plan: skipped,size: S,kind: bug,needs: gpu" \
    "$(gh_get '.[] | select(.number == 3) | "\(.title)|\(.milestone.title)|\([.labels[].name] | join(","))"')"
  check "create: the body" "Depends on #1, human

## Intent

Why.

## Raw

the human said so

## Notes

---

## Outcome

<!-- fill in at close -->" "$(gh_get '.[] | select(.number == 3) | .body')"
  check "read: the text back" "$(TITLE="A new thing" ID=3 text "milestone: m1" "plan: skipped" "size: S" \
    "depends: [1, human]" "needs: [gpu]" "kind: bug")" "$(peal read 3 2>&1)"
  check_refused "create: unknown milestone" "milestone m9 does not exist" peal create two-words < <(text "milestone: m9")
  check_refused "create: parked milestone" "milestone m3 is parked" peal create two-words < <(text "milestone: m3")
  check_refused "create: unknown dependency" "depends: 99 is no task" peal create two-words < <(text "depends: [99]")
  check_refused "create: unknown field" "unknown field colour" peal create two-words < <(text "colour: red")
  check_refused "create: a field's value" "kind chore is not one of bug,feature" peal create two-words < <(text "kind: chore")
  check_refused "create: no Raw" "no '## Raw' section" peal create two-words < <(printf '# NNNN — T\n')
  check "create: nothing filed on a refusal" "3" "$(gh_get 'length')"
  # A dependency on an older issue, read on its own.
  gh_save issues 'map(if .number == 2 then .closed_long_ago = true else . end)'
  out=$(PEAL_ISSUES_CLOSED=0 peal create waits-for-old < <(text "depends: [2]") 2>&1)
  check "create: an issue beyond the list" "0:filed 4" "$?:${out%% https*}"

  # A split: ORIGIN and PARTn become numbers, the pieces edited once they are known.
  out=$(peal create --part-of 1 first-piece second-piece < <(TITLE="First" text "part-of: ORIGIN" "depends: [PART2]"
    echo "-----NEXT TASK-----"; TITLE="Second" RAW="see ORIGIN and NNNN" text "part-of: ORIGIN") 2>&1)
  check "split" "0:filed 5 https://github.com/acme/widgets/issues/5 — milestone: -, plan: -, size: - — \"First\"
filed 6 https://github.com/acme/widgets/issues/6 — milestone: -, plan: -, size: - — \"Second\"" "$?:$out"
  check "split: the pieces' references" "5 part-of: 1 depends: 6
6 part-of: 1 raw: see 1 and 6" "$(for n in 5 6; do printf '%s part-of: %s' "$n" "$(peal read "$n" | awk '/^part-of:/ { print $2 }')"
    d=$(peal read "$n" | awk '/^depends:/ { print $2 }' | tr -d '[]'); [ -z "$d" ] || printf ' depends: %s' "$d"
    r=$(peal read "$n" | sed -n '/^## Raw/,/^## Notes/p' | sed -n 3p); [ "$n" = 5 ] || printf ' raw: %s' "$r"; echo; done)"
  check "split: the list" "1 free an-origin m1 split:1 0/3
5 blocked first needs:6
6 free second - split:1 0/3" "$(list 1 5 6 2>&1)"

  # A batch says where it was found.
  out=$(peal create --batch 1 found-thing < <(TITLE="Found" text) 2>&1)
  check "batch" "0:filed 7" "$?:${out%% https*}"
  check "batch: where it was found" "Found while working on #1." \
    "$(gh_get '.[] | select(.number == 7) | .body' | sed -n '/^## Notes/,/^---/p' | sed -n 3p)"

  # revise: the text rewritten, the reason a comment; the Raw section never.
  peal read 7 | sed 's/^Why\.$/Why, better./; s/^---$/---/' | awk '
    NR == 1 { print; print "milestone: m2"; print "size: L"; next } { print }' >"$work.new"
  out=$(peal revise 7 --reason "sharper" --dry-run <"$work.new" 2>&1)
  check "revise: dry run" "0:revise: a dry run; nothing changed" "$?:$(printf '%s\n' "$out" | tail -n 1)"
  check "revise: dry run changes nothing" "0" "$(gh_get '[.[] | select(.number == 7) | .labels[]] | length')"
  out=$(peal revise 7 --reason "sharper" <"$work.new" 2>&1)
  check "revise" "0:revised 7 https://github.com/acme/widgets/issues/7" "$?:$out"
  check "revise: the text" "$(cat "$work.new")" "$(peal read 7 2>&1)"
  check "revise: the reason" "Revised $today: sharper" "$(gh_get '.[] | select(.issue == 7) | .body' comments)"
  gh_save issues 'map(if .number == 7 then .labels += [{name: "good first issue"}] else . end)'
  sed 's/^size: L$/size: S/' "$work.new" | peal revise 7 --reason "smaller" >/dev/null 2>&1
  check "revise: a label replaced, others kept" "good first issue,size: S" "$(labels 7 | tr ',' '\n' | sort | paste -sd, -)"
  check_refused "revise: the same text" "nothing to revise" peal revise 7 --reason again < <(peal read 7)
  check_refused "revise: Raw changed" "the Raw section changed" peal revise 7 --reason x < <(peal read 7 | sed 's/the human said so/they did not/')
  check_refused "revise: the heading's number" "the first heading must be '# 7 — Title'" peal revise 7 --reason x < <(peal read 7 | sed 's/^# 7 /# 8 /')
  check_refused "revise: part-of" "part-of changed" peal revise 5 --reason x < <(peal read 5 | sed 's/^part-of: 1$/part-of: 2/')
  check_refused "revise: a done task" "revise: task 2 is done" peal revise 2 --reason x < <(echo)
  check_refused "revise: not an issue" "no task 99" peal revise 99 --reason x < <(echo)

  # set-milestone and comment.
  out=$(peal set-milestone 7 m1 2>&1)
  check "set-milestone" "0:task 7: milestone m1" "$?:$out"
  check "set-milestone: on the issue" "m1" "$(gh_get '.[] | select(.number == 7) | .milestone.title')"
  check "set-milestone: none" "task 7: milestone none|null" "$(peal set-milestone 7 2>&1)|$(gh_get '.[] | select(.number == 7) | .milestone')"
  check_refused "set-milestone: done" "milestone m0 is done" peal set-milestone 7 m0
  check_refused "set-milestone: unknown" "milestone m9 does not exist" peal set-milestone 7 m9
  check_refused "set-milestone: the same" "none already" peal set-milestone 7
  check "comment" "task 1: noted|a note" "$(peal comment 1 "a note" 2>&1)|$(gh_get '.[] | select(.issue == 1) | .body' comments)"

  # retire: closed as not planned, the reason a comment; refused while named.
  check_refused "retire: named by a piece" "task 1 is still named by:" peal retire 1 --reason "no"
  check_refused "retire: done" "task 2 is done" peal retire 2 --reason "no"
  check_refused "retire: named by a sibling" "5 first (depends)" peal retire 6 --reason "no"
  out=$(peal retire 4 --reason "not worth it" 2>&1)
  check "retire" "0:retired 4 https://github.com/acme/widgets/issues/4" "$?:$out"
  check "retire: closed, not planned" "closed not_planned Retired $today without being claimed: not worth it" \
    "$(gh_get '.[] | select(.number == 4) | "\(.state) \(.state_reason)"') $(gh_get '.[] | select(.issue == 4) | .body' comments)"
  check "retire: done" "4 done title-of-4" "$(list 4 2>&1)"

  # finish done: only on the issue's branch, where it says what closes it.
  check_refused "finish: not on the branch" "not on issue 1's branch (issue/1), but on main" peal finish 1
  git -C "$work" worktree add -q -b issue/1 "$work-1" origin/main 2>/dev/null
  scratch+=("$work-1")
  check "finish" "finished 1: the pull request's body says \"Fixes #1\"; its merge closes the issue" \
    "$(at "$work-1" "$PEAL" finish 1 2>&1)"
  # A claimed task is not revised, retired or moved.
  check_refused "revise: claimed" "revise: task 1 is claimed-live (wt:$work-1)" peal revise 1 --reason x < <(peal read 1)
  check_refused "retire: claimed" "retire: task 1 is claimed-live" peal retire 1 --reason x
  check_refused "set-milestone: claimed" "set-milestone: task 1 is claimed-live" peal set-milestone 1 m2
}

claims() {
  local work out wt
  issues_repo
  issue 1 "Current one" --milestone m1
  issue 2 "Parked one" --milestone m3
  issue 3 "Unassigned one"
  issue 4 "Belfry's one"
  issue 5 "Continued one"
  issue 6 "Blocked one" --body "Depends on #3"

  check "offer" "CANDIDATE 1 m1 Current one
CANDIDATE 3 unassigned Unassigned one
MORE unassigned 2" "$(peal offer current,unassigned --top 2 2>&1)"
  check_refused "offer: parked" "milestone m3 is parked" peal offer m3

  # claim: the worktree, the branch and the label, as Belfry makes them.
  wt=$(dirname "$work")/work-wt/issue-1
  out=$(peal claim 1 --print-path 2>&1)
  check "claim" "0:claimed 1 issue/1 $wt
$wt" "$?:$out"
  check "claim: the label" "in progress" "$(labels 1)"
  check "claim: the branch" "issue/1" "$(git -C "$wt" symbolic-ref --short HEAD)"
  check "claim: nothing pushed" "" "$(git -C "$work" ls-remote origin refs/heads/issue/1)"
  check "claim: the text kept for the hooks" "# 1 — Current one" "$(grep '^# ' "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-task.md")"
  check "claim: listed" "1 claimed-live current-one wt:$wt" "$(list 1 2>&1)"
  check "claim again: the worktree again" "task 1 is claimed here already: $wt
$wt" "$(peal claim 1 --print-path 2>&1)"
  check "Belfry recognises Peal's claim" "reusing $wt, claimed-live" "$(belfry_sees 1)"
  check_refused "claim: parked milestone" "milestone m3 is parked" peal claim 2
  check_refused "claim: blocked" "task 6 is blocked, needs:3" peal claim 6
  issue 7 "Elsewhere" --label "in progress"
  check_refused "claim: claimed elsewhere" "task 7 is claimed elsewhere (labelled)" peal claim 7
  check_refused "claim: no such issue" "no task 99" peal claim 99

  # Belfry's claim, resumed: the worktree it made is this task's.
  belfry_claim 4
  out=$(peal claim 4 --print-path 2>&1)
  check "Peal resumes Belfry's claim" "0:task 4 is claimed here already: $(dirname "$work")/work-wt/issue-4
$(dirname "$work")/work-wt/issue-4" "$?:$out"
  # Belfry's worktree before its label (the label comes when the session starts).
  gh_save issues 'map(if .number == 4 then .labels = [] else . end)'
  check "Belfry's worktree alone is a claim" "4 claimed-live belfry-s-one wt:$(dirname "$work")/work-wt/issue-4" "$(list 4 2>&1)"

  # A branch an earlier session pushed is continued.
  git -C "$work" push -q origin origin/main:refs/heads/issue/5 2>/dev/null
  git clone -q "$(dirname "$work")/remote.git" "$work-o" 2>/dev/null
  scratch+=("$work-o")
  git -C "$work-o" checkout -q issue/5
  git -C "$work-o" commit -q --allow-empty -m "earlier work"
  git -C "$work-o" push -q origin issue/5 2>/dev/null
  out=$(peal claim 5 2>&1)
  check "claim: continues the remote's branch" "0:claimed 5 issue/5 $(dirname "$work")/work-wt/issue-5" "$?:$out"
  check "claim: with its work" "earlier work" "$(git -C "$(dirname "$work")/work-wt/issue-5" log -1 --format=%s)"

  # --next: the best free task.
  check "claim --next" "claimed 3 issue/3 $(dirname "$work")/work-wt/issue-3" "$(peal claim --next 2>&1)"

  # A label that cannot be set: taken back.
  issue 8 "Unlucky one"
  printf 'POST repos/acme/widgets/issues/8/labels' >"$FAKE_GH/fail"
  check_refused "claim: the label fails" "could not label issue 8 'in progress'; taken back" peal claim 8
  rm -f "$FAKE_GH/fail"
  check "claim: nothing left" "|8 free unlucky-one -" \
    "$(git -C "$work" branch --list issue/8)|$(list 8 2>&1)"

  # release: refused until the issue is closed, then everything goes, the label too.
  check_refused "release: not landed" "task 3 stays: task 3 is not done on the main branch" peal release 3
  check_refused "release: no branch" "task 6 has no branch here" peal release 6
  gh_save issues 'map(if .number == 3 then .state = "closed" else . end)'
  out=$(peal release 3 2>&1)
  check "release" "0:released 3 issue/3, tip kept as refs/reaped/issue-3" "$?:$out"
  check "release: gone" "|" "$(git -C "$work" branch --list issue/3)|$(git -C "$work" worktree list | grep issue-3)"
  check "release: the label stays on a closed issue" "in progress" "$(labels 3)"
  check "release: no label call for it" "0" "$(calls 'DELETE repos/acme/widgets/issues/3/labels')"

  # A parked claim: a local branch ahead, no worktree; the claim resumes it.
  git -C "$work" worktree remove "$(dirname "$work")/work-wt/issue-5"
  gh_save issues 'map(if .number == 5 then .labels = [] else . end)'
  check "parked" "5 parked continued-one 1 commit(s) ahead, last $today" "$(list 5 2>&1)"
  check "claim: resumes a parked claim" "resumed 5 issue/5 $(dirname "$work")/work-wt/issue-5|in progress" \
    "$(peal claim 5 2>&1)|$(labels 5)"

  # Released while open (a claim given up): the label comes off.
  gh_save issues 'map(if .number == 1 then .state = "closed" else . end)'
  git -C "$wt" commit -q --allow-empty -m "done"
  git -C "$wt" push -q -u origin issue/1 2>/dev/null
  gh_save issues 'map(if .number == 1 then .state = "open" else . end)'
  # shellcheck disable=SC2016 # expanded by the inner shell
  out=$(at "$work" bash -c 'PEAL_ROOT=$1; for f in common config claim tasks store github; do . "$1/lib/$f.sh"; done
    peal_store_load && peal_store_release 1' _ "$PEAL_ROOT" 2>&1)
  check "release: an open issue's label comes off" "released 1 issue/1, tip kept as refs/reaped/issue-1|" "$out|$(labels 1)"
  check "release: the pushed branch deleted" "" "$(git -C "$work" ls-remote origin refs/heads/issue/1)"
}

session() {
  local work wt out
  ISSUES_CONFIG='sizes: {S: 3, M: 5, L: 8}
' issues_repo
  issue 1 "Sized one" --label "size: S"
  issue 2 "Other one"
  (cd "$work" && "$PEAL" claim 1 && "$PEAL" claim 2) >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/issue-1
  out=$(hook "$wt" session-start '{"source":"startup"}')
  check "orientation: in an issue's worktree" "0:Peal:
Current milestone: m1, m1 (https://github.com/acme/widgets/milestone/2)
Task: 1, $(git -C "$wt" rev-parse --absolute-git-dir)/peal-task.md: this worktree's task and this session's whole scope. Read it first.
Other claims:
  2 claimed-live other-one wt:$(dirname "$work")/work-wt/issue-2" "$out"
  : >"$FAKE_GH/log"
  check "budget: counted" "0:" "$(hook "$wt" post-tool-use '{}')"
  hook "$wt" post-tool-use '{}' >/dev/null
  check "budget: the size from the label" "2:TURN BUDGET: 3 tool calls on task 1, size S, whose tier is 3." \
    "$(hook "$wt" post-tool-use '{}' | head -n 1)"
  check "budget: no gh call per tool call" "" "$(cat "$FAKE_GH/log")"
  # A worktree Belfry made, no copy kept yet: read once, then kept.
  rm -f "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-task.md"
  : >"$FAKE_GH/log"
  hook "$wt" post-tool-use '{}' >/dev/null
  hook "$wt" post-tool-use '{}' >/dev/null
  check "budget: the text read once" "1" "$(calls 'GET repos/acme/widgets/issues/1$')"

  # The idea queue on an issue's branch, flushed as a batch found in it.
  out=$(at "$wt" "$PEAL" idea some-new-idea < <(TITLE="Some new idea" text) 2>&1)
  check "idea: queued on an issue's branch" "0:queued some-new-idea — milestone: -, plan: -, size: - — \"Some new idea\"" "$?:$out"
  out=$(at "$wt" "$PEAL" ideas --flush 2>&1)
  check "ideas: flushed" "0:filed 3" "$?:${out%% https*}"
  check "ideas: found in the task" "Found while working on #1." \
    "$(gh_get '.[] | select(.number == 3) | .body' | sed -n '/^## Notes/,/^---/p' | sed -n 3p)"

  # SessionEnd pushes the issue's branch.
  printf 'x\n' >"$wt/new-file"
  hook "$wt" session-end '{"reason":"logout"}' >/dev/null
  git -C "$work" fetch -q origin
  check "session-end: pushed" "wip: session-end autosave [1]" "$(git -C "$work" log -1 --format=%s origin/issue/1)"
}

commit_msg() {
  local work
  issues_repo
  check "an issue's id in a subject" "0" \
    "$(at "$work" bash -c 'printf "feat: a thing [42]\n" >"$1" && "$2" githook commit-msg "$1" >/dev/null 2>&1; echo $?' _ "$work.msg" "$PEAL")"
}

repo_of() {
  local url
  for url in https://github.com/acme/widgets https://github.com/acme/widgets.git git@github.com:acme/widgets.git \
      ssh://git@github.com/acme/widgets https://token@github.com/acme/widgets.git/; do
    check "repo of $url" "acme/widgets" "$(bash -c '. "$1/lib/github.sh"; peal_github_repo_of "$2"' _ "$PEAL_ROOT" "$url")"
  done
  check "repo of another host" "1:" "$(bash -c '. "$1/lib/github.sh"; peal_github_repo_of "$2"; echo "$?:"' _ "$PEAL_ROOT" https://gitlab.com/acme/widgets)"
}

# Depends cycles: shown with the issues' numbers, and refused where a text would close one.
cycles() {
  local work body
  issues_repo
  body=$(printf '## Intent\n\nWhy.\n\n## Raw\n\nthe human said so\n\n## Notes\n')
  issue 1 "Cycle a" --body "Depends on #2"
  issue 2 "Cycle b" --body "Depends on #1"
  issue 3 "Origin one" --body "$body"
  issue 4 "Waits for origin" --body "Depends on #3"
  check "cycles: list" "1 blocked cycle-a needs:2 cycle: #1 → #2 → #1
2 blocked cycle-b needs:1 cycle: #2 → #1 → #2
3 free origin-one -
4 blocked waits-for-origin needs:3" "$(list 2>&1)"
  check "cycles: board" '{"id":"1","state":"blocked","slug":"cycle-a","title":"Cycle a","depends":["2"],"cycle":"#1 → #2 → #1","url":"https://github.com/acme/widgets/issues/1"}' \
    "$(peal board 2>&1 | sed -n 1p)"
  check_refused "cycles: check" "peal: depends cycle #1 → #2 → #1" peal check

  check_fails "cycles: split" 1 "create: refused: depends cycle PART1 → #4 → PART1" \
    peal create --part-of 3 a-piece < <(text "part-of: ORIGIN" "depends: [4]")
  check_fails "cycles: revise" 1 "revise: refused: depends cycle #3 → #4 → #3" \
    peal revise 3 --reason x < <(printf -- '---\ndepends: [4]\n---\n\n'; peal read 3 2>/dev/null)
  check "cycles: nothing filed or changed" "4|$body" "$(gh_get 'length')|$(gh_get '.[] | select(.number == 3) | .body')"
}

# Priority as labels: read (the higher of two; normal is none), written by create and
# revise.
priority() {
  local work out
  issues_repo
  issue 1 "Both" --label "priority: low" --label "priority: high"
  issue 2 "Normal" --label "priority: normal"
  issue 3 "Unknown" --label "priority: soon"
  check "priority: board" '{"id":"1","state":"free","slug":"both","title":"Both","priority":"high"}
{"id":"2","state":"free","slug":"normal","title":"Normal"}
{"id":"3","state":"free","slug":"unknown","title":"Unknown"}' "$(peal board 2>&1 | grep -v '^{"milestone"' | normal)"
  check "priority: read, the higher of two" "priority: high" "$(peal read 1 | grep '^priority')"
  check "priority: read, normal is none" "" "$(peal read 2 | grep '^priority')"

  out=$(peal create urgent-thing < <(TITLE="Urgent" text "priority: urgent") 2>&1)
  check "priority: create" "0:filed 4" "$?:${out%% https*}"
  check "priority: the label" "priority: urgent" "$(labels 4)"
  peal create normal-thing < <(TITLE="Normal" text "priority: normal") >/dev/null 2>&1
  check "priority: normal makes no label" "" "$(labels 5)"
  check "priority: read back" "---
priority: urgent
---" "$(peal read 4 | sed -n 1,3p)"
  peal read 4 | sed 's/^priority: urgent$/priority: low/' | peal revise 4 --reason "can wait" >/dev/null 2>&1
  check "priority: revise replaces the label" "priority: low" "$(labels 4)"
  peal read 4 | sed '/^priority:/d' | peal revise 4 --reason "as any" >/dev/null 2>&1
  check "priority: revise to normal drops it" "" "$(labels 4)"
  check_refused "priority: a word Peal does not know" "priority soon is not urgent, high, normal or low" \
    peal create odd-thing < <(text "priority: soon")
}

# The owner as the label "owner: human": read, written by create and revise; a task
# depending on a human task waits until its issue is closed.
owner() {
  local work out
  issues_repo
  issue 1 "Human" --label "owner: human"
  issue 2 "Waits" --body "Depends on #1"
  issue 3 "Ai" --label "owner: ai"
  check "owner: board" '{"id":"1","state":"free","slug":"human","title":"Human","owner":"human"}
{"id":"2","state":"blocked","slug":"waits","title":"Waits","depends":["1"]}
{"id":"3","state":"free","slug":"ai","title":"Ai"}' "$(peal board 2>&1 | grep -v '^{"milestone"' | normal)"
  check "owner: the offer leaves it out" "CANDIDATE 3 unassigned Ai" "$(peal offer unassigned 2>&1)"
  check "owner: read" "owner: human" "$(peal read 1 | grep '^owner')"
  check "owner: read, ai is none" "" "$(peal read 3 | grep '^owner')"
  out=$(peal create human-thing < <(TITLE="Human thing" text "owner: human") 2>&1)
  check "owner: create" "0:filed 4" "$?:${out%% https*}"
  check "owner: the label" "owner: human" "$(labels 4)"
  peal create ai-thing < <(TITLE="Ai thing" text "owner: ai") >/dev/null 2>&1
  check "owner: ai makes no label" "" "$(labels 5)"
  { printf -- '---\nowner: human\n'; peal read 5 | sed 1d; } | peal revise 5 --reason "only the human" >/dev/null 2>&1
  check "owner: revise adds the label" "owner: human" "$(labels 5)"
  peal read 5 | sed '/^owner:/d' | peal revise 5 --reason "an AI can" >/dev/null 2>&1
  check "owner: revise to ai drops it" "" "$(labels 5)"
  check_refused "owner: a word Peal does not know" "owner robot is not ai or human" \
    peal create odd-thing < <(text "owner: robot")
  issue 6 "Human done" --closed --label "owner: human"
  issue 7 "After" --body "Depends on #6"
  check "owner: a human task done frees what waits on it" "7 free after -" "$(peal list 7 2>&1)"
}

# touches as labels, one per path: read into a list, written by create and revise, a label
# over GitHub's 50 characters refused before anything is filed.
touches() {
  local work out long
  issues_repo
  issue 1 "Two" --label "touches: docs/api.md" --label "touches: ui/**/*.tscn" --label "size: S"
  issue 2 "One" --label "touches: scripts/rank"
  check "touches: board" '{"id":"1","state":"free","slug":"two","title":"Two","size":"S","touches":["docs/api.md","ui/**/*.tscn"]}
{"id":"2","state":"free","slug":"one","title":"One","touches":["scripts/rank"]}' "$(peal board 2>&1 | grep -v '^{"milestone"' | normal)"
  check "touches: read, a list" "touches: [docs/api.md, ui/**/*.tscn]" "$(peal read 1 | grep '^touches')"
  check "touches: read, one is a list too" "touches: [scripts/rank]" "$(peal read 2 | grep '^touches')"

  out=$(peal create touching-thing < <(TITLE="Touching" text "touches: [plugin/lib/board.awk, '**/*.md']") 2>&1)
  check "touches: create" "0:filed 3" "$?:${out%% https*}"
  check "touches: the labels" "touches: plugin/lib/board.awk,touches: **/*.md" "$(labels 3)"
  check "touches: read back" "touches: [plugin/lib/board.awk, '**/*.md']" "$(peal read 3 | grep '^touches')"
  peal read 3 | sed 's|^touches: .*|touches: [docs/design.md]|' | peal revise 3 --reason "narrower" >/dev/null 2>&1
  check "touches: revise replaces the labels" "touches: docs/design.md" "$(labels 3)"
  peal read 3 | sed '/^touches:/d' | peal revise 3 --reason "unknown" >/dev/null 2>&1
  check "touches: revise drops them" "" "$(labels 3)"

  # "touches: " and 41 characters make 50, the most a label holds.
  long=plugin/lib/aaaaaaaaaaaaaaaaaaaaaaaaaa.awk
  out=$(peal create fits-thing < <(TITLE="Fits" text "touches: [$long]") 2>&1)
  check "touches: a label of 50 characters" "0:filed 4|touches: $long" "$?:${out%% https*}|$(labels 4)"
  check_refused "touches: a label over 50 characters" \
    "touches: ${long}x is too long for a label (\"touches: ${long}x\" is over 50 characters)" \
    peal create long-thing < <(text "touches: [${long}x]")
  check "touches: nothing filed" "4" "$(gh_get 'length')"
}

cases() {
  states
  expansion
  cycles
  board
  parity
  priority
  owner
  touches
  writes
  claims
  session
  commit_msg
  repo_of
}

for_each_awk cases
finish
