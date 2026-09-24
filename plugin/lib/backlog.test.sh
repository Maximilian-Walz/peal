#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq's $variables, not the shell's
# Harness for defer (lib/backlog.sh, peal_store_defer in both storages, the release of a
# deferred claim in lib/claim.sh) and for revising one's own claim (a split narrowing its
# origin), on task files and on issues (lib/fake-gh), through the peal CLI:
#
#   bash plugin/lib/backlog.test.sh
#
# Phase 1 writes the task's text back under its number, and refuses work on the branch,
# uncommitted changes that would go with the claim, and every check a revise makes; phase 2
# is the release, which a deferred claim passes although its task is not done, and the
# reaping, which lets it go once idle.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }
in_wt() { at "$wt" "$PEAL" "$@"; }
subject() { git -C "$work" fetch -q origin; git -C "$work" log -1 --format=%s origin/main; }

files() {
  local work wt out new before
  work=$(repo)
  put "$work" backlog 0001 deferred-task "milestone: m1"
  put "$work" backlog 0002 blocking-task
  put "$work" backlog 0003 kept-task
  at "$work" "$PEAL" hooks install >/dev/null
  peal claim 0001 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0001-deferred-task
  before=$(git -C "$work" rev-parse origin/main)

  check_refused "defer: no reason" "defer: --reason R" in_wt defer </dev/null
  check_refused "defer: no text" "no text on stdin" in_wt defer --reason x </dev/null
  check_refused "defer: no claim here" "this worktree holds no claim" peal defer --reason x < <(ID=0001 text)

  # Work on the branch, or uncommitted beside the task's own file, refuses.
  echo code >"$wt/code.txt"
  git -C "$wt" add code.txt
  git -C "$wt" commit -q -m "feat: code [0001]"
  check_refused "defer: work on the branch" "task/0001-deferred-task holds work beyond the claim" \
    in_wt defer --reason x < <(ID=0001 text "milestone: m1")
  git -C "$wt" reset -q --hard HEAD~1
  echo scratch >"$wt/scratch.txt"
  check_refused "defer: uncommitted beside the task" "uncommitted changes besides tasks/doing/0001-deferred-task.md" \
    in_wt defer --reason x < <(ID=0001 text "milestone: m1")
  rm "$wt/scratch.txt"
  git -C "$work" push -q origin "$(git -C "$work" commit-tree -p task/0001-deferred-task -m more "task/0001-deferred-task^{tree}"):refs/heads/task/0001-deferred-task" 2>/dev/null
  git -C "$wt" fetch -q origin
  check_refused "defer: the remote branch holds more" "origin/task/0001-deferred-task holds commits this worktree does not have" \
    in_wt defer --reason x < <(ID=0001 text "milestone: m1")
  git -C "$wt" push -q -f origin HEAD:refs/heads/task/0001-deferred-task 2>/dev/null
  git -C "$wt" fetch -q origin

  # The checks of a revise, but no change is fine.
  check_refused "defer: Raw changed" "the Raw section changed" in_wt defer --reason x < <(ID=0001 RAW=other text "milestone: m1")
  check_refused "defer: Outcome filled" "fills in the Outcome" in_wt defer --reason x < <(ID=0001 OUTCOME=Built. text "milestone: m1")
  check_refused "defer: another number" "the first heading must be '# 0001 — Title'" in_wt defer --reason x < <(ID=0002 text)
  check_refused "defer: into a parked milestone" "milestone m3 is parked" in_wt defer --reason x < <(ID=0001 text "milestone: m3")
  check_refused "defer: unknown depends" "depends: 0099 is no task" in_wt defer --reason x < <(ID=0001 text "depends: [0099]")
  check_refused "defer: part-of" "part-of changed" in_wt defer --reason x < <(ID=0001 text "part-of: 0002")
  check_refused "defer: no Notes" "no '## Notes' section" in_wt defer --reason x < <(ID=0001 text "milestone: m1" | sed '/^## Notes/d')
  check "defer: refusals push nothing" "$before" "$(git -C "$work" fetch -q; git -C "$work" rev-parse origin/main)"

  # A wip commit of the task's own file is no work; nor is an uncommitted edit of it.
  echo "learned something" >>"$wt/tasks/doing/0001-deferred-task.md"
  git -C "$wt" commit -q -am "wip: session-end autosave [0001]" >/dev/null
  echo "and more" >>"$wt/tasks/doing/0001-deferred-task.md"
  new=$(ID=0001 text "milestone: m1" "depends: [0002]" | sed 's/^## Notes$/## Notes\n\nNeeds 0002 first./')
  out=$(in_wt defer --reason "blocked on 0002" --dry-run <<<"$new" 2>&1)
  check "defer --dry-run: the note" "1" "$(grep -c "^+Deferred $today after a claim: blocked on 0002" <<<"$out")"
  check "defer --dry-run: nothing pushed" "$before" "$(git -C "$work" fetch -q; git -C "$work" rev-parse origin/main)"
  check "defer --dry-run: no marker" "" "$(ls "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-deferred" 2>/dev/null)"

  out=$(in_wt defer --reason "blocked on 0002" <<<"$new" 2>&1)
  check "defer" "0:deferred 0001 tasks/backlog/0001-deferred-task.md
next, from outside this worktree: peal release 0001" "$?:$out"
  check "defer: the text on main" "$(printf '%s\n' "$new" | sed "s/^## Notes\$/## Notes\n\nDeferred $today after a claim: blocked on 0002/")" \
    "$(on_main "$work" tasks/backlog/0001-deferred-task.md)"
  check "defer: through the pre-push gate" "docs(tasks): defer 0001 deferred-task [0001]" "$(subject)"
  check "defer: the worktree left clean" "|wip: defer capture [0001]" \
    "$(git -C "$wt" status --porcelain)|$(git -C "$wt" log -1 --format=%s)"
  check "defer: still claimed until released" "0001 claimed-live deferred-task wt:$wt" "$(peal list --no-pr 0001 2>&1)"

  # Phase 2: the release, never from inside; once deferred, a task not done may go.
  check_refused "release: from inside" "it is the worktree this runs in" in_wt release 0001
  out=$(peal release 0001 2>&1)
  check "release a deferred claim" "0:released 0001 task/0001-deferred-task, tip kept as refs/reaped/0001-deferred-task" "$?:$out"
  check "release: branch and worktree gone" "||" \
    "$(git -C "$work" branch --list 'task/0001-*')|$(git -C "$work" ls-remote origin 'refs/heads/task/0001-*')|$(git -C "$work" worktree list | grep 0001)"
  check "release: blocked by its corrected depends" "0001 blocked deferred-task needs:0002" "$(peal list --no-pr 0001 2>&1)"

  # A claim not deferred still stays.
  peal claim 0003 >/dev/null 2>&1
  check_refused "release: not deferred" "task 0003 stays: task 0003 is not done" peal release 0003

  # Reaping (in a repository that uses Peal) lets an idle deferred claim go, not a live one.
  mkdir -p "$work/.peal"
  wt=$(dirname "$work")/work-wt/0003-kept-task
  in_wt defer --reason "not now" < <(ID=0003 text) >/dev/null 2>&1
  touch "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-heartbeat"
  out=$(peal hook session-start <<<'{"source":"startup"}' 2>&1 | grep -E '^(reaped|kept)')
  check "reap: not a live deferred claim" "" "$out"
  touch -t 202001010000 "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-heartbeat"
  out=$(peal hook session-start <<<'{"source":"startup"}' 2>&1 | grep -E '^(reaped|kept)')
  check "reap: an idle deferred claim" "reaped 0003 task/0003-kept-task, tip kept as refs/reaped/0003-kept-task" "$out"
  check "reap: free again" "0003 free kept-task -" "$(peal list --no-pr 0003 2>&1)"
}

files_own() {
  local work wt out new
  work=$(repo)
  put "$work" backlog 0001 split-origin "milestone: m1"
  put "$work" backlog 0002 other-task
  at "$work" "$PEAL" hooks install >/dev/null
  peal claim 0001 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0001-split-origin

  # The split's pieces, filed onto main; then the origin narrowed on its own branch.
  out=$(in_wt create --part-of 0001 first-piece < <(text "part-of: ORIGIN" "depends: [ORIGIN]") 2>&1)
  check "split from the claim" "0:filed 0003 tasks/backlog/0003-first-piece.md — milestone: -, plan: -, size: - — \"Title of 0003\"" "$?:$out"
  new=$(ID=0001 TITLE="The narrowed origin" text "milestone: m1")
  out=$(in_wt revise 0001 --reason "split: 0003 has the rest" --dry-run <<<"$new" 2>&1)
  check "revise own claim --dry-run" "0:revise: a dry run; nothing recorded" "$?:$(printf '%s\n' "$out" | tail -n 1)"
  check "revise own claim --dry-run: nothing committed" "docs(tasks): claim 0001 split-origin [0001]" "$(git -C "$wt" log -1 --format=%s)"
  out=$(in_wt revise 0001 --reason "split: 0003 has the rest" <<<"$new" 2>&1)
  check "revise own claim" "0:1" "$?:$(grep -c '^committed [0-9a-f]* docs(tasks): record the revision of 0001 \[0001\]$' <<<"$out")"
  check "revise own claim: the file" "$(printf '%s\n' "$new" | sed "s/^## Notes\$/## Notes\n\nRevised $today: split: 0003 has the rest/")" \
    "$(cat "$wt/tasks/doing/0001-split-origin.md")"
  check "revise own claim: the commit" "docs(tasks): record the revision of 0001 [0001]|" \
    "$(git -C "$wt" log -1 --format=%s)|$(git -C "$wt" status --porcelain)"
  check "revise own claim: main untouched" "$(ID=0001 text "milestone: m1")" "$(on_main "$work" tasks/backlog/0001-split-origin.md)"
  check_refused "revise own claim: Raw" "the Raw section changed" in_wt revise 0001 --reason x < <(ID=0001 RAW=x text)
  check_refused "revise own claim: no change" "nothing to revise" in_wt revise 0001 --reason x <"$wt/tasks/doing/0001-split-origin.md"
  check_refused "revise own claim: depends unknown" "depends: 0099 is no task" in_wt revise 0001 --reason x < <(ID=0001 text "depends: [0099]")
  check_refused "revise own claim: parked" "milestone m3 is parked" in_wt revise 0001 --reason x < <(ID=0001 text "milestone: m3")
  check_refused "revise own claim: part-of" "part-of changed" in_wt revise 0001 --reason x < <(ID=0001 text "milestone: m1" "part-of: 0002")
  check_refused "revise: another claim from here" "task 0001 is claimed" \
    at "$work" "$PEAL" revise 0001 --reason x < <(ID=0001 TITLE=y text)
  # A revision of the claim's own file is no work: planning found the block.
  out=$(in_wt defer --reason "0003 first" < <(in_wt read 0001) 2>&1)
  check "defer: after a revise" "0:deferred 0001 tasks/backlog/0001-split-origin.md" "$?:$(printf '%s\n' "$out" | head -n 1)"
  check "defer: the narrowed text on main" "# 0001 — The narrowed origin" "$(on_main "$work" tasks/backlog/0001-split-origin.md | grep '^# ')"
}

issues() {
  local work wt out new body
  issues_repo
  body=$(printf '## Intent\n\nWhy.\n\n## Raw\n\nthe human said so\n\n## Notes\n')
  issue 1 "Deferred one" --milestone m1 --body "$body"
  issue 2 "Blocking one" --body "$body"
  issue 3 "Origin one" --body "$body"
  peal claim 1 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/issue-1

  check_refused "issues defer: no claim here" "this worktree holds no claim" peal defer --reason x < <(ID=1 text)
  git -C "$wt" commit -q --allow-empty -m "feat: something [1]"
  check_refused "issues defer: a commit is work" "issue/1 holds work beyond origin/main" in_wt defer --reason x < <(in_wt read 1)
  git -C "$wt" reset -q --hard HEAD~1
  echo x >"$wt/x.txt"
  check_refused "issues defer: uncommitted" "uncommitted changes, which would go with the claim" in_wt defer --reason x < <(in_wt read 1)
  rm "$wt/x.txt"
  check_refused "issues defer: Raw" "the Raw section changed" in_wt defer --reason x < <(in_wt read 1 | sed 's/^## Raw$/## Raw\n\nmore/')
  check_refused "issues defer: parked" "milestone m3 is parked" in_wt defer --reason x < <(in_wt read 1 | sed 's/^milestone: m1$/milestone: m3/')

  new=$(in_wt read 1 | sed 's/^milestone: m1$/milestone: m1\ndepends: [2]/')
  out=$(in_wt defer --reason "needs 2" --dry-run <<<"$new" 2>&1)
  check "issues defer --dry-run" "0:defer: a dry run; nothing changed" "$?:$(printf '%s\n' "$out" | tail -n 1)"
  out=$(in_wt defer --reason "needs 2" <<<"$new" 2>&1)
  check "issues defer" "0:deferred 1 https://github.com/acme/widgets/issues/1
next, from outside this worktree: peal release 1" "$?:$out"
  check "issues defer: the body" "Depends on #2" "$(gh_get '.[] | select(.number == 1) | .body' | head -n 1)"
  check "issues defer: the reason" "Deferred $today after a claim: needs 2" "$(gh_get '.[] | select(.issue == 1) | .body' comments)"
  check_refused "issues release: from inside" "it is the worktree this runs in" in_wt release 1
  out=$(peal release 1 2>&1)
  check "issues release a deferred claim" "0:released 1 issue/1, tip kept as refs/reaped/issue-1" "$?:$out"
  check "issues release: the label off" "" "$(labels 1)"
  check "issues release: blocked" "1 blocked deferred-one needs:2" "$(peal list 1 2>&1)"

  # The same text given back: only the comment.
  peal claim 2 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/issue-2
  out=$(in_wt defer --reason "later" < <(in_wt read 2) 2>&1)
  check "issues defer: unchanged" "0:deferred 2 https://github.com/acme/widgets/issues/2" "$?:$(printf '%s\n' "$out" | head -n 1)"
  check "issues defer: unchanged, commented" "Deferred $today after a claim: later" "$(gh_get '.[] | select(.issue == 2) | .body' comments)"

  # Revising one's own claim: the origin of a split narrowed.
  peal claim 3 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/issue-3
  new=$(in_wt read 3 | sed 's/^# 3 — Origin one$/# 3 — Narrowed origin/')
  out=$(in_wt revise 3 --reason "split" <<<"$new" 2>&1)
  check "issues revise own claim" "0:recorded the revision of 3 on issue 3" "$?:$out"
  check "issues revise own claim: the title" "Narrowed origin" "$(gh_get '.[] | select(.number == 3) | .title')"
  check "issues revise own claim: the hooks' copy" "# 3 — Narrowed origin" \
    "$(grep '^# ' "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-task.md")"
  check_refused "issues revise: claimed, from elsewhere" "revise: task 3 is claimed-live" peal revise 3 --reason x <<<"$new"
}

cases() {
  files
  files_own
  if command -v jq >/dev/null; then
    issues
  elif [ -n "${PEAL_REQUIRE_JQ-}" ]; then
    check "jq, which the fake gh needs" "jq" ""
  fi
}

for_each_awk cases
finish
