#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq's $variables, not the shell's
# Harness for the close (lib/close.sh): peal close begin, finish, body, abort, verify and
# wait, the Stop hook and peal check's Outcomes, on each storage (task files, and issues;
# both on lib/fake-gh, so only when jq is here), against throwaway repositories with a
# bare remote:
#
#   bash plugin/lib/close.test.sh
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

if ! command -v jq >/dev/null; then
  echo "close.test.sh: no jq here, which the fake gh needs; skipped" >&2
  [ -z "${PEAL_REQUIRE_JQ-}" ] || exit 1
  exit 0
fi
# This harness may run inside a Claude Code session, whose variables would leak in.
unset CLAUDE_CODE_SESSION_ID CLAUDE_PROJECT_DIR PEAL_CLOSE_WAIT_BUDGET PEAL_CLOSE_WAIT_INTERVAL

# The storage the cases run on: files or issues.
kind=files

# new_repo [CONFIG-LINE...] -> work, a new repository on the storage of kind with a fake
# GitHub, those lines in its .peal/config.yml.
new_repo() {
  if [ $kind = files ]; then
    work=$(repo)
    fake_github "$work"
    mkdir "$work/.peal"
    printf '%s\n' "remote: origin" "$@" >"$work/.peal/config.yml"
  else
    ISSUES_CONFIG="" issues_repo
    printf '\n' >>"$work/.peal/config.yml"
    [ $# -eq 0 ] || printf '%s\n' "$@" >>"$work/.peal/config.yml"
  fi
  publish "$work"
}

# id N -> task N's id on this storage: 0001 as a file, 1 as an issue.
id() {
  if [ $kind = files ]; then printf '%04d\n' "$1"; else printf '%s\n' "$1"; fi
}

# task N SLUG [MERGE] -> task N put on the storage, with a Scope and a Done when; MERGE
# auto gives it merge: auto.
task() {
  local body=$'Why.\n\n## Scope\n\n`a.txt`\n\n## Done when\n\n- a.txt says built\n\n## Raw\n\nthe human said so\n\n## Notes\n'
  if [ $kind = files ]; then
    mkdir -p "$work/tasks/backlog"
    printf -- '---\n%s---\n\n# %s — Title of %s\n\n%s\n---\n\n## Outcome\n\n<!-- fill in at close -->\n' \
      "${3:+merge: $3$'\n'}" "$(id "$1")" "$(id "$1")" "$body" >"$work/tasks/backlog/$(id "$1")-$2.md"
    publish "$work"
  else
    issue "$1" "Title of $1" --body "$body" ${3:+--label "merge: $3"}
  fi
}

# ready N SLUG [MERGE] -> task N put on the storage, the hooks installed, the task
# claimed; wt its worktree, text the file its Outcome goes in.
ready() {
  task "$1" "$2" "${3-}"
  at "$work" "$PEAL" hooks install >/dev/null
  wt=$(at "$work" "$PEAL" claim "$(id "$1")" --print-path 2>/dev/null | tail -n 1)
  text=""
}

# build -> a commit on the task's branch, pushed when it has an upstream.
build() {
  echo built >"$wt/a.txt"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "feat: build a.txt [$(id 1)]"
  git -C "$wt" rev-parse -q --verify '@{upstream}' >/dev/null 2>&1 && git -C "$wt" push -q 2>/dev/null
  return 0
}

# begin -> peal close begin in wt; text the file the Outcome goes in.
begin() {
  local out
  out=$(at "$wt" "$PEAL" close begin 2>&1)
  text=$(printf '%s\n' "$out" | sed -n 's/^Outcome: write it in \(.*\), under ## Outcome\.$/\1/p')
  case $text in /*) ;; ?*) text=$wt/$text ;; esac
  printf '%s\n' "$out"
}

# outcome TEXT -> the Outcome's section replaced by TEXT.
outcome() {
  PEAL_NOTE=$1 awk '$0 == "## Outcome" { print; print ""; print ENVIRON["PEAL_NOTE"]; exit } { print }' "$text" >"$text.new"
  mv "$text.new" "$text"
}

# close_finish ARGS... -> peal close finish in wt, with a summary.
close_finish() {
  at "$wt" "$PEAL" close finish --summary "- built a.txt" "$@"
}

# closing -> the last commit a close makes on a branch with work on it: the task's move
# (task files), or none (issues).
closing() {
  if [ $kind = files ]; then echo "docs(tasks): close 0001 [0001]"; else echo "feat: build a.txt [1]"; fi
}

sentinel() {
  [ -f "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-close" ] && echo armed || echo clear
}

prs() { jq length "$FAKE_GH/pulls.json"; }

# other_clone CMD... -> CMD run in a fresh clone of the remote, without Peal's hooks, its
# main pushed afterwards: a change that reaches main while the task is worked.
other_clone() {
  local dir
  dir=$(scratch_dir)/other
  git clone -q "$(dirname "$work")/remote.git" "$dir" 2>/dev/null
  (cd "$dir" && "$@") && git -C "$dir" push -q origin main 2>/dev/null
}

begin_cases() {
  local out
  new_repo
  ready 1 first-task
  check_refused "begin: no task here" "holds no task to close" at "$work" "$PEAL" close begin
  check_refused "begin: arguments" "takes no arguments" at "$wt" "$PEAL" close begin now
  git -C "$work" config --unset core.hooksPath
  check_refused "begin: hooks not installed" "hooks are not installed" at "$wt" "$PEAL" close begin
  at "$work" "$PEAL" hooks install >/dev/null
  mkdir -p "$wt/tasks/backlog"
  printf -- '---\n---\n\n# 0009 — Smuggled\n' >"$wt/tasks/backlog/0009-smuggled-task.md"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "docs(tasks): smuggle [$(id 1)]"
  check_refused "begin: a backlog file added on the branch" "adds backlog task files" at "$wt" "$PEAL" close begin
  git -C "$wt" rm -q "tasks/backlog/0009-smuggled-task.md"
  git -C "$wt" commit -q -m "docs(tasks): unsmuggle [$(id 1)]"
  if [ $kind = files ]; then
    cp "$wt/tasks/doing/0001-first-task.md" "$wt/tasks/doing/0002-second-task.md"
    check_refused "begin: two tasks under doing/" "2 tasks under tasks/doing/" at "$wt" "$PEAL" close begin
    rm "$wt/tasks/doing/0002-second-task.md"
  fi
  check "begin: nothing armed by a refusal" "clear" "$(sentinel)"

  # The notes: main moved on and conflicts, a milestone changed, an idea queued.
  build
  other_clone sh -c 'echo other >a.txt && echo more >b.txt && git add -A && git commit -q -m other && touch c && git add c && git commit -q -m third'
  mkdir -p "$wt/docs/milestones"
  echo "# changed" >"$wt/docs/milestones/m9.md"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "docs: a milestone [$(id 1)]"
  at "$wt" "$PEAL" idea "later idea here" <<<"$(ID=NNNN TITLE="A later idea" text)" >/dev/null
  begin >"$work/../begin.out"
  out=$(cat "$work/../begin.out")
  check "begin: armed" "armed" "$(sentinel)"
  check "begin: said so" "close begun: task $(id 1). Until peal close finish (or abort), the Stop hook holds this session to a finished close." \
    "$(printf '%s\n' "$out" | head -n 1)"
  check "begin: behind main" "NOTE: this branch is 2 commit(s) behind origin/main, not counting task files. Merge it in if that matters here (git merge origin/main); never rebase a pushed branch." \
    "$(printf '%s\n' "$out" | grep 'behind')"
  check "begin: the conflict" "  a.txt" "$(printf '%s\n' "$out" | grep -A1 'would conflict' | tail -n 1)"
  check "begin: the milestone file" "  docs/milestones/m9.md" "$(printf '%s\n' "$out" | grep -A1 'milestone files' | tail -n 1)"
  check "begin: the queued idea" "  later-idea-here — A later idea" "$(printf '%s\n' "$out" | grep -A1 'queued on this branch' | tail -n 1)"
  check "begin: sections not empty" "" "$(printf '%s\n' "$out" | grep 'empty in task')"
  check "begin: the Done when" "- a.txt says built" "$(printf '%s\n' "$out" | sed -n '/^--- Done when/,$p' | grep a.txt)"
  check "begin: the Outcome's file" "1" "$([ -f "$text" ] && grep -c '^## Outcome$' "$text")"
  if [ $kind = files ]; then
    check "begin: the task's own file" "$wt/tasks/doing/0001-first-task.md" "$text"
  fi

  new_repo "pr:" "  sections: [\"For the player: what a player notices\", Screens]"
  task 1 bare-task
  if [ $kind = files ]; then
    printf -- '---\n---\n\n# 0001 — Bare\n\n## Raw\n\nx\n\n---\n\n## Outcome\n' >"$work/tasks/backlog/0001-bare-task.md"
    publish "$work"
  else
    gh_save issues 'map(.body = "Just this.")'
  fi
  at "$work" "$PEAL" hooks install >/dev/null
  wt=$(at "$work" "$PEAL" claim "$(id 1)" --print-path 2>/dev/null | tail -n 1)
  out=$(begin)
  check "begin: empty sections" "NOTE: ## Scope and ## Done when are empty in task $(id 1). Fine for a task closed with nothing built; otherwise fill in what was agreed or built: the review checks the diff against it." \
    "$(printf '%s\n' "$out" | grep 'empty in task')"
  check "begin: the PR sections" "  For the player: what a player notices
  Screens" "$(printf '%s\n' "$out" | grep -A2 '^PR sections' | tail -n 2)"
  check "begin: no Done when" "(no Done when section)" "$(printf '%s\n' "$out" | tail -n 1)"
}

finish_cases() {
  local body out status stopflag
  stopflag=$(scratch_dir)/stop
  new_repo "pr:" "  sections: [\"For the player: what a player notices\"]" "checks:" "  close: [\"test ! -e $stopflag\"]"
  ready 1 first-task
  build
  check_refused "finish: no close begun" "no close in progress" close_finish --section "For the player" "Nothing."
  begin >/dev/null

  # Refusals, each before anything changes.
  check_refused "finish: no summary" "no --summary" at "$wt" "$PEAL" close finish --section "For the player" "Nothing."
  check_refused "finish: a section missing" "the PR section 'For the player' is missing" close_finish
  check_refused "finish: an unknown section" "'Screens' is not one of the PR sections" close_finish --section Screens x
  check_refused "finish: an empty section" "section 'For the player' is empty" close_finish --section "For the player" " "
  check_refused "finish: a section twice" "given twice" close_finish --section "For the player" a --section "For the player" b
  check_refused "finish: an empty Outcome" "has no Outcome yet" close_finish --section "For the player" "Nothing."
  outcome $'Built a.txt.\n\n<!-- more -->'
  check_refused "finish: a placeholder left" "still holds a placeholder" close_finish --section "For the player" "Nothing."
  outcome $'Built a.txt.\n\n### Escalations\n\n- one\n- two\n- three\n- four'
  check_refused "finish: more than three escalations" "4 escalations" close_finish --section "For the player" "Nothing."
  outcome $'Built a.txt.\n\n### Escalations\n\n- Is a.txt the right name?'
  echo stray >"$wt/stray.txt"
  check_refused "finish: another path dirty" "?? stray.txt" close_finish --section "For the player" "Nothing."
  rm "$wt/stray.txt"
  git -C "$work" config --unset core.hooksPath
  check_refused "finish: hooks not installed" "hooks are not installed" close_finish --section "For the player" "Nothing."
  at "$work" "$PEAL" hooks install >/dev/null
  touch "$stopflag"
  check_refused "finish: a close check fails" "the close check 'test ! -e" close_finish --section "For the player" "Nothing."
  rm "$stopflag"
  check "finish: nothing changed by a refusal" "armed|0|0" \
    "$(sentinel)|$(prs)|$(at "$work" "$PEAL" list --no-pr "$(id 1)" | grep -c awaiting-merge)"

  # The body, as finish will open the pull request with it.
  body=$(at "$wt" "$PEAL" close body --summary-file <(printf -- '- built a.txt\n- tested it\n') --section-file "For the player" <(echo "Nothing to see."))
  check "body: the judgement first" "**Needs your judgement:** 1 escalation(s), under the Outcome's Escalations." "$(printf '%s\n' "$body" | head -n 1)"
  check "body: the summary" "- built a.txt
- tested it" "$(printf '%s\n' "$body" | sed -n 3,4p)"
  if [ $kind = files ]; then
    check "body: the task" "Task 0001." "$(printf '%s\n' "$body" | sed -n 6p)"
  else
    check "body: what closes the issue" "Fixes #1" "$(printf '%s\n' "$body" | sed -n 6p)"
  fi
  check "body: the section" "## For the player

Nothing to see." "$(printf '%s\n' "$body" | sed -n '/^## For the player/,/^Nothing/p')"
  check "body: the Outcome" "## Outcome

Built a.txt.

### Escalations

- Is a.txt the right name?" "$(printf '%s\n' "$body" | sed -n '/^## Outcome/,/right name/p')"
  check "body: the commits" "- feat: build a.txt [$(id 1)]" "$(printf '%s\n' "$body" | grep '^- feat')"
  check "body: no claim commit" "" "$(printf '%s\n' "$body" | grep 'claim')"
  check "body: no ideas yet" "" "$(printf '%s\n' "$body" | grep 'Ideas filed')"

  # Finished: pushed, the pull request open, the sentinel cleared.
  at "$wt" "$PEAL" idea "later idea here" <<<"$(ID=NNNN TITLE="A later idea" text)" >/dev/null
  out=$(close_finish --section "For the player" "Nothing." 2>&1)
  status=$?
  check "finish: done" "0" "$status"
  check "finish: said so" "closed $(id 1): pull request #$(jq '.[0].number' "$FAKE_GH/pulls.json") $(jq -r '.[0].html_url' "$FAKE_GH/pulls.json")" \
    "$(printf '%s\n' "$out" | grep '^closed')"
  check "finish: the sentinel cleared" "clear" "$(sentinel)"
  check "finish: one pull request" "1" "$(prs)"
  check "finish: its title, head and base" "Title of $(id 1) [$(id 1)]|$(git -C "$wt" symbolic-ref --short HEAD)|main" \
    "$(jq -r '.[0] | "\(.title)|\(.head.ref)|\(.base.ref)"' "$FAKE_GH/pulls.json")"
  body=$(jq -r '.[0].body' "$FAKE_GH/pulls.json")
  check "finish: the body credits the idea" "- $(id 2): A later idea" "$(printf '%s\n' "$body" | grep '^- .*A later idea' | sed 's/ (.*//')"
  check "finish: the idea filed" "0" "$(at "$wt" "$PEAL" read "$(id 2)" >/dev/null 2>&1; echo $?)"
  check "finish: the queue empty" "" "$(at "$wt" "$PEAL" ideas)"
  check "finish: pushed" "0" "$(git -C "$wt" rev-list --count '@{upstream}..HEAD')"
  check "finish: clean" "" "$(git -C "$wt" status --porcelain)"
  check "finish: the close commit" "$(closing)" "$(git -C "$wt" log -1 --format=%s)"
  if [ $kind = files ]; then
    check "finish: moved to done, the Outcome in it" "Built a.txt." \
      "$(git -C "$wt" show HEAD:tasks/done/0001-first-task.md | peal_text_section Outcome | sed -n 2p)"
    check "finish: awaiting merge" "awaiting-merge" "$(at "$work" "$PEAL" list --no-pr 0001 | cut -d ' ' -f 2)"
  else
    check "finish: awaiting merge" "awaiting-merge" "$(at "$work" "$PEAL" list 1 | cut -d ' ' -f 2)"
  fi

  # Run again after the Outcome changes: the same pull request, its body updated.
  begin >/dev/null
  if [ $kind = files ]; then
    check_refused "finish again: begin needs the task under doing/" "holds no task" at "$wt" "$PEAL" close begin
    printf '%s\n' "$(id 1)" | { printf '\n'; cat; date -u +%Y-%m-%dT%H:%M:%SZ; } >"$(git -C "$wt" rev-parse --absolute-git-dir)/peal-close"
    text=$wt/tasks/done/0001-first-task.md
  fi
  outcome "Built a.txt, and named it so."
  if [ $kind = files ]; then
    git -C "$wt" commit -q -am "docs(tasks): reword [$(id 1)]"
  fi
  out=$(close_finish --section "For the player" "Still nothing." 2>&1)
  check "finish again: updated" "0|updated the title and body of pull request #$(jq '.[0].number' "$FAKE_GH/pulls.json")|1" \
    "$?|$(printf '%s\n' "$out" | grep '^updated')|$(prs)"
  check "finish again: the new body" "Still nothing." "$(jq -r '.[0].body' "$FAKE_GH/pulls.json" | grep Still)"
}

# merge_cases -> a task holding merge: auto needs the reviewer's merge-auto line; keep
# leaves the field, withdraw removes it from the task and says so in the pull request.
merge_cases() {
  local review out body
  review=$(scratch_dir)/review
  new_repo
  ready 1 first-task auto
  build
  begin >"$review.begin"
  out=$(cat "$review.begin")
  check "merge: begin notes it" "1" "$(printf '%s\n' "$out" | grep -c '^NOTE: task .* holds merge: auto')"
  outcome "Built a.txt."
  check_refused "merge: no review given" "holds merge: auto, so the reviewer's report decides" close_finish
  printf 'No findings. Ready to close.\n' >"$review"
  check_refused "merge: a review without the line" "has no line merge-auto: keep" close_finish --review-file "$review"
  check "merge: nothing changed by a refusal" "armed|0" "$(sentinel)|$(prs)"
  printf 'No findings.\n\n`merge-auto: keep`\n' >"$review"
  body=$(at "$wt" "$PEAL" close body --summary "- built a.txt" --review-file "$review")
  check "merge: keep says nothing" "" "$(printf '%s\n' "$body" | grep 'withdrawn')"

  printf 'The diff rewrote the parser.\nmerge-auto: withdraw\n' >"$review"
  body=$(at "$wt" "$PEAL" close body --summary "- built a.txt" --review-file "$review")
  check "merge: the body says withdraw first" "**merge: auto withdrawn:** the review found the diff larger or riskier than the plan that earned it, so this pull request waits for a human." \
    "$(printf '%s\n' "$body" | head -n 1)"
  out=$(close_finish --review-file "$review" 2>&1)
  check "merge: withdraw, finished" "0|1" "$?|$(printf '%s\n' "$out" | grep -c '^withdrew merge: auto from task')"
  check "merge: the pull request says so" "1" "$(jq -r '.[0].body' "$FAKE_GH/pulls.json" | grep -c '^\*\*merge: auto withdrawn')"
  if [ $kind = files ]; then
    check "merge: gone from the task's file" "" "$(git -C "$wt" show HEAD:tasks/done/0001-first-task.md | grep '^merge:')"
    check "merge: the Outcome kept" "Built a.txt." \
      "$(git -C "$wt" show HEAD:tasks/done/0001-first-task.md | peal_text_section Outcome | sed -n 2p)"
    check "merge: clean" "" "$(git -C "$wt" status --porcelain)"
  else
    check "merge: the label gone" "in progress" "$(labels 1)"
  fi

  new_repo
  ready 1 first-task auto
  build
  begin >/dev/null
  outcome "Built a.txt."
  printf 'No findings.\nmerge-auto: keep\n' >"$review"
  out=$(close_finish --review-file "$review" 2>&1)
  check "merge: keep, finished" "0|0" "$?|$(printf '%s\n' "$out" | grep -c 'withdrew')"
  if [ $kind = files ]; then
    check "merge: kept in the task's file" "merge: auto" "$(git -C "$wt" show HEAD:tasks/done/0001-first-task.md | grep '^merge:')"
  else
    check "merge: the label kept" "merge: auto" "$(labels 1 | tr ',' '\n' | grep merge)"
  fi

  # Without merge: auto, a withdraw means nothing, and no report is needed.
  new_repo
  ready 1 first-task
  build
  begin >/dev/null
  outcome "Built a.txt."
  printf 'merge-auto: withdraw\n' >"$review"
  body=$(at "$wt" "$PEAL" close body --summary "- built a.txt" --review-file "$review")
  check "merge: no field, nothing withdrawn" "" "$(printf '%s\n' "$body" | grep 'withdrawn')"
}

# rerun_cases -> a finish that stops at the push, or at the pull request, goes on when run
# again.
rerun_cases() {
  local url out
  new_repo
  ready 1 first-task
  build
  begin >/dev/null
  outcome "Built a.txt."
  url=$(git -C "$work" remote get-url origin)
  git -C "$wt" remote set-url origin "$url.gone"
  check_fails "rerun: the push fails" 1 "the push failed" close_finish
  check "rerun: still armed, committed, no pull request" "armed|$(closing)|0" \
    "$(sentinel)|$(git -C "$wt" log -1 --format=%s)|$(prs)"
  git -C "$wt" remote set-url origin "$url"
  printf 'POST repos/*/pulls' >"$FAKE_GH/fail"
  check_fails "rerun: the pull request fails" 1 "gh pr create --base main" close_finish
  check "rerun: pushed, still armed" "0|armed" "$(git -C "$wt" rev-list --count '@{upstream}..HEAD')|$(sentinel)"
  rm "$FAKE_GH/fail"
  out=$(close_finish 2>&1)
  check "rerun: done" "0|1|clear" "$?|$(prs)|$(sentinel)"
  check "rerun: one close commit" "$([ $kind = files ] && echo 1 || echo 0)" "$(git -C "$wt" log --format=%s origin/main..HEAD | grep -c '^docs(tasks): close')"
}

# flush_cases -> the queued ideas file all or none (task files), or dequeue exactly those
# filed (issues, filed one by one).
flush_cases() {
  local out filed
  new_repo
  ready 1 first-task
  build
  at "$wt" "$PEAL" idea "first idea here" <<<"$(ID=NNNN TITLE="First idea" text)" >/dev/null
  at "$wt" "$PEAL" idea "bad idea here" <<<"$(ID=NNNN TITLE="Bad idea" text "depends: [$(id 99)]")" >/dev/null
  begin >/dev/null
  outcome "Built a.txt."
  check_refused "flush: a bad idea refuses the close" "the queued ideas were not all filed" close_finish
  check "flush: nothing filed, both still queued, nothing moved" "2|armed|0|0" \
    "$(at "$wt" "$PEAL" ideas | wc -l | tr -d ' ')|$(sentinel)|$(prs)|$(git -C "$wt" log --format=%s origin/main..HEAD | grep -c '^docs(tasks): close')"
  check "flush: no task filed" "1" "$(at "$work" "$PEAL" list --no-pr | wc -l | tr -d ' ')"
  # Mend the queue: the bad idea's depends taken out.
  sed -i.bak "/^depends: \[$(id 99)\]\$/d" "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-ideas"
  if [ $kind = issues ]; then
    # Filed one by one: the second fails after the first is filed.
    printf 'POST repos/acme/widgets/issues' >"$FAKE_GH/fail"
    echo 1 >"$FAKE_GH/fail-after"
    check_refused "flush: stops half-way" "the queued ideas were not all filed" close_finish
    check "flush: the one filed is off the queue" "bad-idea-here" "$(at "$wt" "$PEAL" ideas | cut -f 1)"
    filed=$(grep -c '^filed ' "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-ideas-filed")
    check "flush: the one filed is remembered" "1" "$filed"
    check "flush: nothing moved" "armed|0" "$(sentinel)|$(prs)"
    rm "$FAKE_GH/fail" "$FAKE_GH/fail-after"
  fi
  out=$(close_finish 2>&1)
  check "flush: then filed, and closed" "0|clear|1" "$?|$(sentinel)|$(prs)"
  check "flush: both credited" "2" "$(jq -r '.[0].body' "$FAKE_GH/pulls.json" | grep -c -e 'First idea' -e 'Bad idea')"
}

# wontfix_cases -> a task closed with nothing built still opens its pull request.
wontfix_cases() {
  local out
  new_repo
  ready 1 first-task
  begin >/dev/null
  outcome "Nothing built: the human decided against it."
  out=$(close_finish 2>&1)
  check "wontfix: closed" "0|1|clear" "$?|$(prs)|$(sentinel)"
  if [ $kind = files ]; then
    check "wontfix: the move is the pull request" "docs(tasks): close 0001 [0001]" "$(git -C "$wt" log --format=%s origin/main..HEAD | head -n 1)"
  else
    check "wontfix: an empty commit to open it on" "docs(tasks): close 1 with nothing built [1]" "$(git -C "$wt" log --format=%s origin/main..HEAD)"
  fi
  check "wontfix: the body says so" "None but the task's own." "$(jq -r '.[0].body' "$FAKE_GH/pulls.json" | grep None)"
}

abort_cases() {
  local log
  new_repo
  ready 1 first-task
  check "abort: nothing in progress" "no close in progress here: nothing to abort 0" "$(in_dir "$wt" "$PEAL" close abort "why not")"
  begin >/dev/null
  check_refused "abort: a reason" "REASON" at "$wt" "$PEAL" close abort
  check_refused "abort: a blank reason" "REASON" at "$wt" "$PEAL" close abort "  "
  at "$wt" "$PEAL" idea "later idea here" <<<"$(ID=NNNN TITLE="A later idea" text)" >/dev/null
  check "abort: aborted" "aborted the close of task $(id 1): the scope grew
The Stop hook holds nothing now. Begin again (peal close begin) when the task is done.
The ideas queued on this branch stay queued, for the close that comes." \
    "$(at "$wt" "$PEAL" close abort $'the scope\ngrew')"
  check "abort: the sentinel gone" "clear" "$(sentinel)"
  log=$(git -C "$wt" rev-parse --absolute-git-dir)/peal-close-abort.log
  check "abort: logged" "task=$(id 1) reason=the scope grew" "$(awk -F '\t' '{ print $2, $5 }' "$log")"
  check "abort: the idea still queued" "later-idea-here" "$(at "$wt" "$PEAL" ideas | cut -f 1)"
  check_refused "abort: then finish refuses" "no close in progress" close_finish
}

# stop HOOK-JSON -> the Stop hook in wt, "status:stderr".
stop() {
  local out
  out=$(cd "$wt" && "$PEAL" hook stop <<<"${1-{\}}" 2>&1)
  printf '%s:%s' "$?" "$out"
}

stop_cases() {
  local shown
  new_repo
  ready 1 first-task
  [ $kind = files ] || git -C "$wt" push -q -u origin issue/1 2>/dev/null
  check "stop: no close, silent" "0:" "$(stop)"
  echo dirty >"$wt/a.txt"
  check "stop: no close, dirty, silent" "0:" "$(stop)"
  rm "$wt/a.txt"
  begin >/dev/null
  # As the hook names it: relative to the worktree's top, where it is inside.
  shown=${text#"$wt"/}
  check "stop: the Outcome empty" "2:Peal: the close of task $(id 1) is in progress (peal close begin) and not finished:
  - the Outcome in $shown is empty
Finish it: write the Outcome, then peal close finish. If the close is off, peal close abort REASON." "$(stop)"
  check "stop: never twice in a row" "0:" "$(stop '{"stop_hook_active": true}')"
  outcome $'Built.\n<!-- more -->'
  check "stop: a placeholder" "2" "$(stop | head -n 1 | cut -d: -f1)"
  check "stop: says so" "1" "$(stop | grep -c 'still holds a placeholder')"
  outcome "Built."
  echo built >"$wt/a.txt"
  check "stop: uncommitted" "1" "$(stop | grep -c 'work is uncommitted')"
  git -C "$wt" add a.txt
  git -C "$wt" commit -q -m "feat: build [$(id 1)]"
  [ $kind = issues ] || git -C "$wt" commit -q -am "docs(tasks): outcome [$(id 1)]"
  check "stop: unpushed" "2:  - $(git -C "$wt" rev-list --count '@{upstream}..HEAD') commit(s) of $(git -C "$wt" symbolic-ref --short HEAD) are not pushed" \
    "$(stop | sed -n '1s/:.*/:/p;2p' | tr -d '\n')"
  git -C "$wt" push -q
  check "stop: all done, silent" "0:" "$(stop)"
  echo dirty >"$wt/b.txt"
  check "stop: another session's close is cleared" "0:|clear" \
    "$(printf '%s\n' other-session "$(id 1)" now >"$(git -C "$wt" rev-parse --absolute-git-dir)/peal-close"; stop '{"session_id": "this-session"}')|$(sentinel)"
  printf '%s\n' this-session "$(id 1)" now >"$(git -C "$wt" rev-parse --absolute-git-dir)/peal-close"
  check "stop: its own close is held" "2" "$(stop '{"session_id": "this-session"}' | head -n 1 | cut -d: -f1)"
  check "stop: outside a Peal project, silent" ":0" "$(cd "$(scratch_dir)" && "$PEAL" hook stop <<<'{}' 2>&1; echo ":$?")"
}

# in_dir DIR CMD... -> CMD's output and status run in DIR, "output status"; stderr dropped.
in_dir() {
  local dir=$1 out status
  shift
  out=$(cd "$dir" && "$@" 2>/dev/null)
  status=$?
  printf '%s %s' "$out" "$status"
}

# verdict -> peal close verify in wt, "verdict status".
verdict() {
  in_dir "$wt" "$PEAL" close verify
}

# pull FIELD VALUE -> the pull request's FIELD set (a JSON value).
pull() {
  gh_save pulls "map(.$1 = \$v)" --argjson v "$2"
}

# checks STATUS [CONCLUSION] -> one check run of wt's HEAD, in that state.
checks() {
  gh_save checks '[{sha: $s, status: $st, conclusion: (if $c == "" then null else $c end)}]' \
    --arg s "$(git -C "$wt" rev-parse HEAD)" --arg st "$1" --arg c "${2-}"
}

# no_gh_path -> a PATH with everything on this one but gh.
no_gh_path() {
  local dir d f
  dir=$(scratch_dir)
  local IFS=:
  for d in $PATH; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      if [ ! -x "$f" ] || [ -d "$f" ]; then continue; fi
      case ${f##*/} in gh) continue ;; esac
      [ -e "$dir/${f##*/}" ] || ln -s "$f" "$dir/${f##*/}"
    done
  done
  printf '%s\n' "$dir"
}

verify_cases() {
  local plain nogh
  new_repo
  ready 1 first-task
  plain=$(scratch_dir)
  check "verify: not a repository" "BLOCKED:not-a-repo 1" "$(in_dir "$plain" "$PEAL" close verify)"
  check "verify: on main" "BLOCKED:on-main 1" "$(in_dir "$work" "$PEAL" close verify)"
  git -C "$wt" checkout -q --detach
  check "verify: detached" "BLOCKED:detached-head 1" "$(verdict)"
  git -C "$wt" checkout -q -
  begin >/dev/null
  check "verify: the close unfinished" "BLOCKED:close-unfinished 1" "$(verdict)"
  outcome "Built a.txt."
  echo built >"$wt/a.txt"
  at "$wt" "$PEAL" close abort "verify's turn" >/dev/null
  check "verify: uncommitted" "BLOCKED:uncommitted 1" "$(verdict)"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "feat: build [$(id 1)]"
  if [ $kind = issues ]; then
    check "verify: no upstream" "BLOCKED:no-upstream 1" "$(verdict)"
    git -C "$wt" push -q -u origin issue/1 2>/dev/null
    git -C "$wt" commit -q --allow-empty -m "feat: more [1]"
  fi
  check "verify: unpushed" "BLOCKED:unpushed 1" "$(verdict)"
  git -C "$wt" push -q
  nogh=$(no_gh_path)
  check "verify: no gh" "BLOCKED:no-gh 1" "$(in_dir "$wt" env PATH="$nogh" "$PEAL" close verify)"
  check "verify: no pull request" "BLOCKED:no-pr 1" "$(verdict)"
  printf 'GET repos/*/pulls*' >"$FAKE_GH/fail"
  check "verify: gh fails" "BLOCKED:gh-failed 1" "$(verdict)"
  rm "$FAKE_GH/fail"
  begin >/dev/null
  close_finish >/dev/null 2>&1
  check "verify: no check yet" "WAIT:no-checks-yet 3" "$(verdict)"
  echo 0 >"$FAKE_GH/workflows"
  check "verify: no workflow at all" "READY:no-checks 0" "$(verdict)"
  checks in_progress
  check "verify: a check running" "WAIT:checks-pending 3" "$(verdict)"
  checks completed failure
  check "verify: a check failed" "BLOCKED:checks-failing 1" "$(verdict)"
  checks completed success
  gh_save statuses '[{sha: $s, state: "pending"}]' --arg s "$(git -C "$wt" rev-parse HEAD)"
  check "verify: a status pending" "WAIT:checks-pending 3" "$(verdict)"
  gh_save statuses '[{sha: $s, state: "error"}]' --arg s "$(git -C "$wt" rev-parse HEAD)"
  check "verify: a status failed" "BLOCKED:checks-failing 1" "$(verdict)"
  gh_save statuses '[]'
  pull mergeable null
  check "verify: mergeability unknown" "WAIT:mergeability-unknown 3" "$(verdict)"
  pull mergeable false
  check "verify: conflicts" "BLOCKED:conflicts 1" "$(verdict)"
  pull mergeable true
  check "verify: green" "READY 0" "$(verdict)"
  pull state '"closed"'
  check "verify: closed unmerged" "READY:pr-closed 0" "$(verdict)"
  pull merged true
  check "verify: merged" "READY:merged 0" "$(verdict)"
  check_refused "verify: no arguments" "takes no arguments" at "$wt" "$PEAL" close verify now

  # wait: until the verdict is not WAIT, within its budget.
  pull merged false
  pull state '"open"'
  checks in_progress
  : >"$FAKE_GH/log"
  check "wait: out of budget, the last WAIT" "WAIT:checks-pending 3|1" \
    "$(in_dir "$wt" env PEAL_CLOSE_WAIT_BUDGET=0 "$PEAL" close wait)|$(grep -c 'check-runs' "$FAKE_GH/log")"
  ( sleep 2; checks completed success ) &
  check "wait: until READY" "READY 0" "$(in_dir "$wt" env PEAL_CLOSE_WAIT_INTERVAL=1 PEAL_CLOSE_WAIT_BUDGET=30 "$PEAL" close wait)"
  wait
  checks completed failure
  check "wait: BLOCKED at once" "BLOCKED:checks-failing 1" "$(in_dir "$wt" env PEAL_CLOSE_WAIT_INTERVAL=5 "$PEAL" close wait)"
  check_refused "wait: a bad budget" "whole seconds" at "$wt" env PEAL_CLOSE_WAIT_BUDGET=soon "$PEAL" close wait
}

check_cases() {
  [ $kind = files ] || return 0
  new_repo
  put "$work" "done" 0001 finished-task
  check_refused "check: only the placeholder under done/" "tasks/done/0001-finished-task.md: done, and its Outcome is empty" at "$work" "$PEAL" check
  OUTCOME=$'Built.\n\n<!-- more -->' put "$work" "done" 0001 finished-task
  check_refused "check: a placeholder left under done/" "tasks/done/0001-finished-task.md: done, and its Outcome still holds a placeholder" at "$work" "$PEAL" check
  OUTCOME="Built." put "$work" "done" 0001 finished-task
  check "check: a written Outcome" "0:" "$(at "$work" "$PEAL" check 2>&1; echo "$?:")"

  # An idea copied out of the queue by hand and indented into the Outcome carries its own
  # placeholder; quoted like that, it does not trip this task's placeholder check.
  OUTCOME=$'Built.\n\nFiled by hand, filing having failed:\n\n  ---\n  ## Outcome\n\n  <!-- Written at close, replacing this comment. -->' \
    put "$work" "done" 0001 finished-task
  check "check: an indented, quoted placeholder passes" "0:" "$(at "$work" "$PEAL" check 2>&1; echo "$?:")"
}

cases() {
  begin_cases
  finish_cases
  merge_cases
  rerun_cases
  flush_cases
  wontfix_cases
  abort_cases
  stop_cases
  verify_cases
  check_cases
}

# run -> the cases on task files, then on issues.
run() {
  local saved=$awk_name
  kind=files
  cases
  kind=issues awk_name="$saved, issues"
  cases
  awk_name=$saved
}

# shellcheck source=common.sh
. "$PEAL_ROOT/lib/common.sh"
# shellcheck source=task-text.sh
. "$PEAL_ROOT/lib/task-text.sh"
for_each_awk run
finish
