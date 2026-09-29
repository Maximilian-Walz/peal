#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq's $variables, not the shell's
# Harness for defer (lib/backlog.sh, peal_store_defer in both storages, the release of a
# deferred claim in lib/claim.sh) and for revising one's own claim (a split narrowing its
# origin), on task files and on issues (lib/fake-gh), through the peal CLI:
#
#   bash plugin/lib/backlog.test.sh
#
# Phase 1 writes the task's text back under its number, and refuses work on the branch,
# uncommitted changes that would go with the claim, and every check a revise makes. Once
# on main, the claim reads as given back, whatever is left of its worktree. Phase 2 is the
# release, which a deferred claim passes although its task is not done, in place from its
# own worktree, and the reaping, which lets it or its leftover worktree go once idle; a
# claim afresh takes a deferred claim's leftover over.
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
  local work wt out new before other admin
  work=$(repo)
  put "$work" backlog 0001 deferred-task "milestone: m1"
  put "$work" backlog 0002 blocking-task
  put "$work" backlog 0003 kept-task
  put "$work" backlog 0004 piece-of-deferred "part-of: 0001" "depends: [0001]"
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

  # An untracked symlink to /dev/null (a sandbox's /dev/null mount, to git and to [ -c ]
  # alike) is not counted as uncommitted work; a real file alongside it still is, and the
  # list of what is uncommitted names only the real file.
  ln -s /dev/null "$wt/dev-null"
  check "defer: raw git lists the link as untracked (the control)" "?? dev-null" \
    "$(git -C "$wt" status --porcelain | grep dev-null)"
  check "defer --dry-run: not refused for the link alone" "0" \
    "$(in_wt defer --reason x --dry-run < <(ID=0001 text "milestone: m1") >/dev/null 2>&1; echo $?)"
  echo scratch >"$wt/scratch.txt"
  out=$(in_wt defer --reason x < <(ID=0001 text "milestone: m1") 2>&1 >/dev/null)
  check "defer: still refused for a real file, listing it" "1" "$(printf '%s\n' "$out" | grep -c '^  scratch.txt$')"
  check "defer: the link left out of the list" "0" "$(printf '%s\n' "$out" | grep -c dev-null)"
  rm "$wt/scratch.txt" "$wt/dev-null"

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
  check_fails "defer: a depends cycle through its piece" 1 "defer: refused: depends cycle 0001 → 0004 → 0001" \
    in_wt defer --reason x < <(ID=0001 text "milestone: m1" "depends: [0004]")
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
next: peal release 0001" "$?:$out"
  check "defer: the text on main" "$(printf '%s\n' "$new" | sed "s/^## Notes\$/## Notes\n\nDeferred $today after a claim: blocked on 0002/")" \
    "$(on_main "$work" tasks/backlog/0001-deferred-task.md)"
  check "defer: through the pre-push gate" "docs(tasks): defer 0001 deferred-task [0001]" "$(subject)"
  check "defer: the worktree left clean" "|wip: defer capture [0001]" \
    "$(git -C "$wt" status --porcelain)|$(git -C "$wt" log -1 --format=%s)"

  # Once the defer is on main, the claim reads as given back, its worktree still there:
  # here, and in a clone that sees only the remote branch.
  check "defer: released as soon as it is on main" "0001 blocked deferred-task needs:0002" "$(peal list --no-pr 0001 2>&1)"
  other=$(dirname "$work")/other
  git clone -q "$(dirname "$work")/remote.git" "$other" 2>/dev/null
  check "defer: released, seen from a clone with the remote branch only" \
    "origin/task/0001-deferred-task|0001 blocked deferred-task needs:0002" \
    "$(git -C "$other" branch -r --list 'origin/task/0001-*' | tr -d ' ')|$(at "$other" "$PEAL" list --no-pr 0001 2>&1)"

  # Phase 2 from inside: released in place, the worktree left detached for the reaping.
  out=$(in_wt release 0001 2>&1)
  check "release from inside" "0:released 0001 task/0001-deferred-task, tip kept as refs/reaped/0001-deferred-task; the worktree stays at $wt, the SessionStart reaping removes it once idle" "$?:$out"
  check "release from inside: the branches gone, the tip kept" "||refs/reaped/0001-deferred-task" \
    "$(git -C "$work" branch --list 'task/0001-*')|$(git -C "$work" ls-remote origin 'refs/heads/task/0001-*')|$(git -C "$work" for-each-ref --format='%(refname)' 'refs/reaped/0001-*')"
  check "release from inside: the directory stays, detached" "HEAD|$(git -C "$work" rev-parse refs/reaped/0001-deferred-task)" \
    "$(git -C "$wt" rev-parse --abbrev-ref HEAD)|$(git -C "$wt" rev-parse HEAD)"
  check "release from inside: blocked by its corrected depends" "0001 blocked deferred-task needs:0002" "$(peal list --no-pr 0001 2>&1)"

  # The reaping (in a repository that uses Peal) keeps the leftover while its heartbeat is
  # fresh, and removes it once idle.
  mkdir -p "$work/.peal"
  admin=$(git -C "$wt" rev-parse --absolute-git-dir)
  touch "$admin/peal-heartbeat"
  out=$(peal hook session-start <<<'{"source":"startup"}' 2>&1 | grep -E '^(reaped|kept)')
  check "reap: not a live leftover" "" "$out"
  touch -t 202001010000 "$admin/peal-heartbeat"
  out=$(peal hook session-start <<<'{"source":"startup"}' 2>&1 | grep -E '^(reaped|kept)')
  check "reap: an idle leftover" "reaped leftover $wt" "$out"
  check "reap: the leftover gone" "|" "$(ls -d "$wt" 2>/dev/null)|$(git -C "$work" worktree list | grep 0001)"

  # A claim not deferred still stays, from elsewhere and from inside.
  peal claim 0003 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0003-kept-task
  check_refused "release: not deferred" "task 0003 stays: task 0003 is not done" peal release 0003
  check_refused "release: not deferred, from inside" "it is the worktree this runs in" in_wt release 0003
  check "release: not deferred, nothing removed" "0003 claimed-live kept-task wt:$wt" "$(peal list --no-pr 0003 2>&1)"

  # Reaping lets an idle deferred claim go, not a live one.
  in_wt defer --reason "not now" < <(ID=0003 text) >/dev/null 2>&1
  touch "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-heartbeat"
  out=$(peal hook session-start <<<'{"source":"startup"}' 2>&1 | grep -E '^(reaped|kept)')
  check "reap: not a live deferred claim" "" "$out"
  touch -t 202001010000 "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-heartbeat"
  out=$(peal hook session-start <<<'{"source":"startup"}' 2>&1 | grep -E '^(reaped|kept)')
  check "reap: an idle deferred claim" "reaped 0003 task/0003-kept-task, tip kept as refs/reaped/0003-kept-task" "$out"
  check "reap: free again" "0003 free kept-task -" "$(peal list --no-pr 0003 2>&1)"

  # Claimed again the same day, the claim forks from a main that has the defer's line.
  peal claim 0003 >/dev/null 2>&1
  check "claim again after a defer, the same day" "0003 claimed-live kept-task wt:$wt" "$(peal list --no-pr 0003 2>&1)"

  # A deferred claim's leftover, here, is taken over by the next claim.
  in_wt defer --reason "again" < <(ID=0003 text) >/dev/null 2>&1
  out=$(peal claim 0003 2>/dev/null)
  check "claim over a local leftover" "0:released 0003 task/0003-kept-task, tip kept as refs/reaped/0003-kept-task
claimed 0003 task/0003-kept-task $wt" "$?:$out"
  check "claim over a local leftover: claimed" "0003 claimed-live kept-task wt:$wt" "$(peal list --no-pr 0003 2>&1)"

  # And one that exists only on the remote, from another clone.
  in_wt defer --reason "once more" < <(ID=0003 text) >/dev/null 2>&1
  git -C "$other" fetch -q origin
  check "defer: the remote-only leftover reads free" "0003 free kept-task -" "$(at "$other" "$PEAL" list --no-pr 0003 2>&1)"
  out=$(at "$other" "$PEAL" claim 0003 2>&1)
  check "claim over a remote-only leftover" "0:released 0003 origin/task/0003-kept-task, deferred, tip kept as refs/reaped/0003-kept-task
claimed 0003 task/0003-kept-task $(dirname "$work")/other-wt/0003-kept-task" "$?:$(printf '%s\n' "$out" | grep -E '^(released|claimed) ')"
  check "claim over a remote-only leftover: claimed there" "0003 claimed-live kept-task wt:$(dirname "$work")/other-wt/0003-kept-task" \
    "$(at "$other" "$PEAL" list --no-pr 0003 2>&1)"
  check "claim over a remote-only leftover: claimed elsewhere, seen here" "0003 claimed-live kept-task remote:origin" \
    "$(peal list --fetch --no-pr 0003 2>&1)"

  # Released from elsewhere, a clean worktree git cannot delete (its directory not
  # writable) is dropped by git, emptied: the branches still go.
  peal claim 0002 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0002-blocking-task
  in_wt defer --reason "stuck" < <(ID=0002 text) >/dev/null 2>&1
  chmod a-w "$(dirname "$wt")"
  out=$(peal release 0002 2>&1)
  chmod u+w "$(dirname "$wt")"
  check "release: a worktree git cannot delete" "0:released 0002 task/0002-blocking-task, tip kept as refs/reaped/0002-blocking-task; git dropped the worktree, but its emptied directory stays at $wt: a claim of the task afresh uses it, or remove it once nothing holds it" "$?:$out"
  check "release: a worktree git cannot delete, the branches gone" "||0002 free blocking-task -" \
    "$(git -C "$work" branch --list 'task/0002-*')|$(git -C "$work" ls-remote origin 'refs/heads/task/0002-*')|$(peal list --no-pr 0002 2>&1)"
  check "claim into the emptied directory" "0:claimed 0002 task/0002-blocking-task $wt" "$?:$(peal claim 0002 2>/dev/null)"
  check "claim into the emptied directory: claimed" "0002 claimed-live blocking-task wt:$wt" "$(peal list --no-pr 0002 2>&1)"

  # The prescribed flow: defer, release in place, and the next claim takes the leftover.
  in_wt defer --reason "later" < <(ID=0002 text) >/dev/null 2>&1
  in_wt release 0002 >/dev/null 2>&1
  out=$(peal claim 0002 2>/dev/null)
  check "claim over a leftover released in place" "0:removed the leftover $wt
claimed 0002 task/0002-blocking-task $wt" "$?:$out"
  check "claim over a leftover released in place: claimed" "0002 claimed-live blocking-task wt:$wt|task/0002-blocking-task" \
    "$(peal list --no-pr 0002 2>&1)|$(git -C "$wt" symbolic-ref -q --short HEAD)"

  # Not from inside the leftover, nor over one that holds something: the reaping's.
  in_wt defer --reason "later" < <(in_wt read 0002) >/dev/null 2>&1
  in_wt release 0002 >/dev/null 2>&1
  check_refused "claim from inside the leftover" "the worktree this runs in; claim from elsewhere, or let the SessionStart reaping remove it" \
    in_wt claim 0002
  echo scratch >"$wt/scratch.txt"
  check_refused "claim over a leftover that holds something" "could not be removed*the SessionStart reaping removes it once idle" \
    peal claim 0002
  check "claim over a leftover that holds something: left alone" "scratch|0002 free blocking-task -" \
    "$(cat "$wt/scratch.txt")|$(peal list --no-pr 0002 2>&1)"
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
  check_fails "revise own claim: a depends cycle" 1 "revise: refused: depends cycle 0001 → 0003 → 0001" \
    in_wt revise 0001 --reason x < <(ID=0001 text "milestone: m1" "depends: [0003]")
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
  issue 4 "Waits for the deferred one" --body "$(printf 'Depends on #1\n\n%s' "$body")"
  peal claim 1 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/issue-1

  check_refused "issues defer: no claim here" "this worktree holds no claim" peal defer --reason x < <(ID=1 text)
  git -C "$wt" commit -q --allow-empty -m "feat: something [1]"
  check_refused "issues defer: a commit is work" "issue/1 holds work beyond origin/main" in_wt defer --reason x < <(in_wt read 1)
  git -C "$wt" reset -q --hard HEAD~1
  echo x >"$wt/x.txt"
  check_refused "issues defer: uncommitted" "uncommitted changes, which would go with the claim" in_wt defer --reason x < <(in_wt read 1)
  rm "$wt/x.txt"

  # An untracked symlink to /dev/null is not counted as uncommitted; a real file alongside
  # it still is, and the printed list names only the real file.
  ln -s /dev/null "$wt/dev-null"
  check "issues defer: raw git lists the link as untracked (the control)" "?? dev-null" \
    "$(git -C "$wt" status --porcelain | grep dev-null)"
  check "issues defer --dry-run: not refused for the link alone" "0" \
    "$(in_wt defer --reason x --dry-run < <(in_wt read 1) >/dev/null 2>&1; echo $?)"
  echo x >"$wt/x.txt"
  out=$(in_wt defer --reason x < <(in_wt read 1) 2>&1 >/dev/null)
  check "issues defer: still refused for a real file, listing it" "1" "$(printf '%s\n' "$out" | grep -c '^  x.txt$')"
  check "issues defer: the link left out of the list" "0" "$(printf '%s\n' "$out" | grep -c dev-null)"
  rm "$wt/x.txt" "$wt/dev-null"

  check_refused "issues defer: Raw" "the Raw section changed" in_wt defer --reason x < <(in_wt read 1 | sed 's/^## Raw$/## Raw\n\nmore/')
  check_refused "issues defer: parked" "milestone m3 is parked" in_wt defer --reason x < <(in_wt read 1 | sed 's/^milestone: m1$/milestone: m3/')

  check_fails "issues defer: a depends cycle" 1 "defer: refused: depends cycle #1 → #4 → #1" \
    in_wt defer --reason x < <(in_wt read 1 | sed 's/^milestone: m1$/milestone: m1\ndepends: [4]/')
  new=$(in_wt read 1 | sed 's/^milestone: m1$/milestone: m1\ndepends: [2]/')
  out=$(in_wt defer --reason "needs 2" --dry-run <<<"$new" 2>&1)
  check "issues defer --dry-run" "0:defer: a dry run; nothing changed" "$?:$(printf '%s\n' "$out" | tail -n 1)"
  out=$(in_wt defer --reason "needs 2" <<<"$new" 2>&1)
  check "issues defer" "0:deferred 1 https://github.com/acme/widgets/issues/1
next: peal release 1" "$?:$out"
  check "issues defer: the body" "Depends on #2" "$(gh_get '.[] | select(.number == 1) | .body' | head -n 1)"
  check "issues defer: the reason" "Deferred $today after a claim: needs 2" "$(gh_get '.[] | select(.issue == 1) | .body' comments)"
  # Given back at once, its worktree still there: the label off, the mark on it.
  check "issues defer: the label off" "" "$(labels 1)"
  check "issues defer: released as soon as it is deferred" "1 blocked deferred-one needs:2" "$(peal list 1 2>&1)"
  # Released from inside, in place; an untracked symlink to /dev/null left in the
  # worktree is no obstacle.
  ln -s /dev/null "$wt/dev-null"
  git -C "$wt" push -q -u origin issue/1 2>/dev/null
  check "issues release: the branch on the remote before" "1" "$(git -C "$work" ls-remote origin 'refs/heads/issue/1' | wc -l | tr -d ' ')"
  out=$(in_wt release 1 2>&1)
  check "issues release from inside" "0:released 1 issue/1, tip kept as refs/reaped/issue-1; the worktree stays at $wt, the SessionStart reaping removes it once idle" "$?:$out"
  check "issues release from inside: the branches gone" "|" \
    "$(git -C "$work" branch --list 'issue/1')|$(git -C "$work" ls-remote origin 'refs/heads/issue/1')"
  check "issues release from inside: detached" "HEAD" "$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  check "issues release: the label off" "" "$(labels 1)"
  check "issues release: blocked" "1 blocked deferred-one needs:2" "$(peal list 1 2>&1)"

  # The same text given back: only the comment.
  peal claim 2 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/issue-2
  out=$(in_wt defer --reason "later" < <(in_wt read 2) 2>&1)
  check "issues defer: unchanged" "0:deferred 2 https://github.com/acme/widgets/issues/2" "$?:$(printf '%s\n' "$out" | head -n 1)"
  check "issues defer: unchanged, commented" "Deferred $today after a claim: later" "$(gh_get '.[] | select(.issue == 2) | .body' comments)"
  # Released in place from inside, the next claim takes the leftover over.
  in_wt release 2 >/dev/null 2>&1
  out=$(peal claim 2 2>/dev/null)
  check "issues claim over a leftover released in place" "0:removed the leftover $wt
claimed 2 issue/2 $wt" "$?:$out"
  check "issues claim over a leftover: claimed" "2 claimed-live blocking-one wt:$wt|in progress" "$(peal list 2 2>&1)|$(labels 2)"

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

# depend (Belfry's tasks.commands.defer): a task made to wait for another, straight into
# the storage; a live claim of this clone given back on the way.
depend_files() {
  local work wt out before
  work=$(repo)
  put "$work" backlog 0001 waits-for-four
  put "$work" backlog 0002 blocking-task
  put "$work" backlog 0003 claimed-task
  put "$work" backlog 0004 waits-for-one "depends: [0001]"
  put "$work" backlog 0005 free-task
  put "$work" backlog 0006 built-task
  put "$work" backlog 0007 remote-task
  put "$work" backlog 0008 merging-task
  put "$work" "done" 0009 finished-task
  at "$work" "$PEAL" hooks install >/dev/null

  # A free task, through the installed pre-push gate.
  out=$(peal depend 0005 0002 2>&1)
  check "depend: free task" "0:task 0005: waits for 0002" "$?:$out"
  check "depend: the subject" "docs(tasks): defer 0005 free-task, waits for 0002 [0005]" "$(subject)"
  check "depend: depends" "depends: [0002]" "$(on_main "$work" tasks/backlog/0005-free-task.md | grep '^depends:')"
  check "depend: the note" "$today: waits for 0002" "$(on_main "$work" tasks/backlog/0005-free-task.md | grep 'waits for')"
  check "depend: listed blocked" "0005 blocked free-task needs:0002" "$(peal list 0005 2>&1)"
  before=$(on_main "$work" tasks/backlog/0005-free-task.md | git hash-object --stdin)
  out=$(peal depend 0005 0002 2>&1)
  check "depend: repeated" "0:task 0005: waits for 0002 already" "$?:$out"
  check "depend: repeated writes nothing" "$before" "$(on_main "$work" tasks/backlog/0005-free-task.md | git hash-object --stdin)"
  peal depend 0005 0003 >/dev/null 2>&1
  check "depend: a second one added" "depends: [0002, 0003]" "$(on_main "$work" tasks/backlog/0005-free-task.md | grep '^depends:')"

  # Refusals.
  check_refused "depend: itself" "cannot wait for itself" peal depend 0002 0002
  check_refused "depend: unknown ON" "no task 0099" peal depend 0002 0099
  check_refused "depend: unknown ID" "no task 0099" peal depend 0099 0002
  check_refused "depend: ON not an id" "no task id" peal depend 0002 '0002; x'
  check_refused "depend: ID not an id" "no task id" peal depend 'x y' 0002
  check_refused "depend: done ID" "task 0009 is done" peal depend 0009 0002
  out=$(peal depend 0002 0009 2>&1)
  check "depend: ON done accepted, with a note" "0:peal: depend: note: task 0009 is done already; the dependency is recorded all the same
task 0002: waits for 0009" "$?:$out"
  before=$(git -C "$work" rev-parse origin/main)
  check_fails "depend: a depends cycle" 1 "depend: refused: depends cycle 0001 → 0004 → 0001" peal depend 0001 0004
  git -C "$work" fetch -q origin
  check "depend: a cycle writes nothing" "$before" "$(git -C "$work" rev-parse origin/main)"
  git -C "$work" push -q origin main:refs/heads/task/0007-remote-task
  check_refused "depend: a remote-only claim" "claimed elsewhere" peal depend 0007 0002
  git -C "$work" checkout -q -b task/0008-merging-task
  git -C "$work" mv tasks/backlog/0008-merging-task.md tasks/done/0008-merging-task.md
  git -C "$work" commit -q -m "docs(tasks): done 0008 [0008]"
  git -C "$work" checkout -q main
  check_refused "depend: awaiting merge" "task 0008 is awaiting-merge" peal depend 0008 0002

  # This clone's live claim with work on it, then with nothing built.
  peal claim 0006 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0006-built-task
  echo code >"$wt/code.txt"
  git -C "$wt" add code.txt
  git -C "$wt" commit -q -m "feat: code [0006]"
  check_refused "depend: work on the claim" "task/0006-built-task holds work beyond the claim" in_wt depend 0006 0003
  git -C "$wt" reset -q --hard HEAD~1
  echo scratch >"$wt/scratch.txt"
  check_refused "depend: uncommitted beside the task" "uncommitted changes besides" in_wt depend 0006 0003
  rm "$wt/scratch.txt"
  out=$(in_wt depend 0006 0003 2>&1)
  check "depend: the claim given back" "0:task 0006: waits for 0003
next: peal release 0006" "$?:$out"
  check "depend: the deferred note" "Deferred $today after a claim: waits for 0003" \
    "$(on_main "$work" tasks/backlog/0006-built-task.md | grep '^Deferred')"
  check "depend: the marker" "1" "$([ -f "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-deferred" ] && echo 1)"
  check "depend: claim reads as given back" "0006 blocked built-task needs:0003" "$(peal list --no-pr 0006 2>&1)"
  peal release 0006 >/dev/null 2>&1
  check "depend: release" "0" "$?"
  git -C "$work" pull -q --rebase origin main 2>/dev/null
  git -C "$work" mv tasks/backlog/0003-claimed-task.md tasks/done/0003-claimed-task.md
  git -C "$work" commit -q -m "docs(tasks): 0003 done [0003]"
  git -C "$work" push -q --no-verify origin main
  out=$(peal claim 0006 2>&1)
  check "depend: claimed afresh once 0003 is done" "0:claimed 0006 task/0006-built-task $(dirname "$work")/work-wt/0006-built-task" "$?:$(printf "%s\n" "$out" | tail -n 1)"

  # create -> "filed:" -> depend, as Belfry chains them.
  out=$(peal create --owner ai --title "Chained follow up task" < <(ID=NNNN text) 2>&1)
  check "depend: create's filed line" "0:filed: 0010" "$?:$(printf '%s\n' "$out" | tail -n 1)"
  out=$(peal depend 0010 0002 2>&1)
  check "depend: on the filed task" "0:task 0010: waits for 0002" "$?:$out"
}

depend_issues() {
  local work wt out body
  issues_repo
  body=$(printf '## Intent\n\nWhy.\n\n## Raw\n\nthe human said so\n\n## Notes\n')
  issue 1 "Claimed one" --body "$body"
  issue 2 "Blocking one" --body "$body"
  issue 3 "Free one" --body "$body"
  issue 4 "Waits for three" --body "$(printf 'Depends on #3\n\n%s' "$body")"
  issue 5 "Labelled one" --body "$body"
  out=$(peal depend 3 2 2>&1)
  check "issues depend: free task" "0:task 3: waits for 2" "$?:$out"
  check "issues depend: the body" "Depends on #2" "$(gh_get '.[] | select(.number == 3) | .body' | head -n 1)"
  check "issues depend: the note" "$today: waits for #2" "$(gh_get '.[] | select(.issue == 3) | .body' comments)"
  check "issues depend: listed blocked" "3 blocked free-one needs:2" "$(peal list 3 2>&1)"
  out=$(peal depend 3 2 2>&1)
  check "issues depend: repeated" "0:task 3: waits for 2 already" "$?:$out"
  check "issues depend: repeated comments nothing" "1" "$(gh_get '.[] | select(.issue == 3) | .body' comments | wc -l | tr -d ' ')"
  check_fails "issues depend: a depends cycle" 1 "depend: refused: depends cycle #3 → #4 → #3" peal depend 3 4

  # The claim of this clone, nothing built: given back.
  peal claim 1 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/issue-1
  git -C "$wt" commit -q --allow-empty -m "feat: something [1]"
  check_refused "issues depend: a commit is work" "issue/1 holds work beyond origin/main" in_wt depend 1 2
  git -C "$wt" reset -q --hard HEAD~1
  out=$(in_wt depend 1 2 2>&1)
  check "issues depend: the claim given back" "0:task 1: waits for 2
next: peal release 1" "$?:$out"
  check "issues depend: the label off" "" "$(labels 1)"
  check "issues depend: the deferred note" "Deferred $today after a claim: waits for #2" "$(gh_get '.[] | select(.issue == 1) | .body' comments)"
  check "issues depend: the marker" "1" "$([ -f "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-deferred" ] && echo 1)"
  check "issues depend: listed blocked" "1 blocked claimed-one needs:2" "$(peal list 1 2>&1)"
}

cases() {
  files
  files_own
  depend_files
  if command -v jq >/dev/null; then
    issues
    depend_issues
  elif [ -n "${PEAL_REQUIRE_JQ-}" ]; then
    check "jq, which the fake gh needs" "jq" ""
  fi
}

for_each_awk cases
finish
