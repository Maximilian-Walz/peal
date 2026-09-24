#!/usr/bin/env bash
# Harness for claims (lib/claim.sh, and the storage's claim and release in
# lib/store-files.sh), against throwaway repositories with a bare remote:
#
#   bash plugin/lib/claim.test.sh
#
# The offer's order and buckets, priority within a bucket; a claim, its refusals, the idempotent re-claim, a double
# claim losing the race (by number and with --next), resuming a parked claim, the scope
# overlap warning; release and reaping, with every condition that keeps a claim.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }
state_of() { at "$work" "$PEAL" list --no-pr "$1" 2>/dev/null; }
on_remote() { git -C "$work" ls-remote origin "refs/heads/$1" | cut -f2; }

# land WORK ID SLUG -> the task moved from backlog/ to done/ on main, as a merge of its
# pull request would.
land() {
  git -C "$1" pull -q --rebase origin main 2>/dev/null
  mkdir -p "$1/tasks/done"
  git -C "$1" mv "tasks/backlog/$2-$3.md" tasks/done/
  git -C "$1" commit -q -m "land $2"
  git -C "$1" push -q origin main 2>/dev/null
}

# admin WT -> the git directory of worktree WT.
admin() { git -C "$1" rev-parse --absolute-git-dir; }

offer() {
  local work out
  work=$(repo)
  put "$work" backlog 0001 unassigned-one
  put "$work" backlog 0002 current-one "milestone: m1"
  put "$work" backlog 0003 open-one "milestone: m2"
  put "$work" backlog 0004 parked-one "milestone: m3"
  put "$work" backlog 0005 current-two "milestone: m1"
  put "$work" backlog 0006 current-blocked "milestone: m1" "depends: [0001]"
  put "$work" backlog 0007 unassigned-two
  put "$work" backlog 0008 unassigned-three
  # An open split: its free members come first in their bucket.
  put "$work" backlog 0009 split-piece "milestone: m1" "part-of: 0010"
  put "$work" backlog 0010 split-origin "milestone: m1"

  out=$(peal offer current,unassigned 2>&1)
  check "offer: order, top 3, what is left" "0:CANDIDATE 0009 m1 Title of 0009 (part of 0010, 0/2 done)
CANDIDATE 0010 m1 Title of 0010 (part of 0010, 0/2 done)
CANDIDATE 0002 m1 Title of 0002
MORE m1 1
MORE unassigned 3" "$?:$out"
  out=$(peal offer unassigned,current --top 4 2>&1)
  check "offer: the pool's order, --top" "0:CANDIDATE 0001 unassigned Title of 0001
CANDIDATE 0007 unassigned Title of 0007
CANDIDATE 0008 unassigned Title of 0008
CANDIDATE 0009 m1 Title of 0009 (part of 0010, 0/2 done)
MORE m1 3" "$?:$out"
  out=$(peal offer m2 --top 10 2>&1)
  check "offer: an open milestone by id" "0:CANDIDATE 0003 m2 Title of 0003" "$?:$out"
  out=$(peal offer m1,current 2>&1)
  check "offer: current and its id are one bucket" "4" "$(printf '%s\n' "$out" | grep -c m1)"
  check_refused "offer: a parked milestone" "milestone m3 is parked" peal offer m3
  check_refused "offer: a done milestone" "milestone m0 is done" peal offer current,m0
  check_refused "offer: no such milestone" "milestone m9 does not exist" peal offer m9
  check_refused "offer: no pool" "offer: POOL" peal offer
  check_refused "offer: --top 0" "positive number" peal offer current --top 0

  # Claimed tasks leave the offer; an empty pool is nothing, and fine.
  git -C "$work" push -q origin origin/main:refs/heads/task/0003-open-one 2>/dev/null
  out=$(peal offer m2 2>&1)
  check "offer: empty" "0:" "$?:$out"
}

# Priority orders within a bucket, before the split's members, and never across buckets.
offer_priority() {
  local work out
  work=$(repo)
  put "$work" backlog 0001 current-normal "milestone: m1"
  put "$work" backlog 0002 current-low "milestone: m1" "priority: low"
  put "$work" backlog 0003 current-high "milestone: m1" "priority: high"
  put "$work" backlog 0004 split-piece "milestone: m1" "part-of: 0005"
  put "$work" backlog 0005 split-origin "milestone: m1"
  put "$work" backlog 0006 current-urgent "milestone: m1" "priority: urgent"
  put "$work" backlog 0007 current-high-two "milestone: m1" "priority: high"
  put "$work" backlog 0008 unassigned-normal
  put "$work" backlog 0009 unassigned-urgent "priority: urgent"
  put "$work" backlog 0010 open-urgent "milestone: m2" "priority: urgent"
  put "$work" backlog 0011 parked-urgent "milestone: m3" "priority: urgent"

  out=$(peal offer current,unassigned --top 20 2>&1)
  check "offer: priority within a milestone, never across" "0:CANDIDATE 0006 m1 Title of 0006
CANDIDATE 0003 m1 Title of 0003
CANDIDATE 0007 m1 Title of 0007
CANDIDATE 0004 m1 Title of 0004 (part of 0005, 0/2 done)
CANDIDATE 0005 m1 Title of 0005 (part of 0005, 0/2 done)
CANDIDATE 0001 m1 Title of 0001
CANDIDATE 0002 m1 Title of 0002
CANDIDATE 0009 unassigned Title of 0009
CANDIDATE 0008 unassigned Title of 0008" "$?:$out"
  out=$(peal claim --next --print-path 2>/dev/null | tail -1)
  check "claim --next: the most urgent first" "$(dirname "$work")/work-wt/0006-current-urgent" "$out"
}

claim() {
  local work wt out head before
  work=$(repo)
  put "$work" backlog 0001 first-task "milestone: m1"
  put "$work" "done" 0002 done-task
  put "$work" backlog 0003 blocked-task "depends: [0001]"
  put "$work" backlog 0004 parked-milestone "milestone: m3"
  put "$work" backlog 0005 elsewhere-task
  put "$work" backlog 0006 open-milestone "milestone: m2"
  head=$(git -C "$work" rev-parse HEAD)
  wt=$(dirname "$work")/work-wt/0001-first-task

  out=$(peal claim 0001 --print-path 2>&1)
  check "claim" "0:claimed 0001 task/0001-first-task $wt
$wt" "$?:$out"
  check "claim: the file in doing/" "tasks/doing/0001-first-task.md" "$(git -C "$wt" ls-files tasks/doing)"
  check "claim: the commit" "docs(tasks): claim 0001 first-task [0001]" "$(git -C "$wt" log -1 --format=%s)"
  check "claim: pushed" "refs/heads/task/0001-first-task" "$(on_remote task/0001-first-task)"
  check "claim: tracks the remote" "origin/task/0001-first-task" "$(git -C "$wt" rev-parse --abbrev-ref '@{upstream}')"
  check "claim: the caller untouched" "$head:" "$(git -C "$work" rev-parse HEAD):$(git -C "$work" status --porcelain)"
  check "claim: listed" "0001 claimed-live first-task wt:$wt" "$(state_of 0001)"
  check "claim: the turn budget at zero" "0" "$(cat "$(admin "$wt")/peal-turns")"

  # Idempotent: claimed here, the same worktree again, nothing new.
  before=$(git -C "$wt" rev-parse HEAD)
  out=$(peal claim 0001 --print-path 2>&1)
  check "re-claim: the worktree again" "0:task 0001 is claimed here already: $wt
$wt" "$?:$out"
  check "re-claim: from the worktree itself" "$wt" "$(at "$wt" "$PEAL" claim 0001 --print-path 2>/dev/null | tail -n 1)"
  check "re-claim: nothing new" "$before" "$(git -C "$wt" rev-parse HEAD)"

  git -C "$work" push -q origin origin/main:refs/heads/task/0005-elsewhere-task 2>/dev/null
  check_refused "claim: done" "task 0002 is done" peal claim 0002
  check_refused "claim: blocked" "task 0003 is blocked, needs:0001" peal claim 0003
  check_refused "claim: a parked milestone" "milestone m3 is parked" peal claim 0004
  check_refused "claim: claimed elsewhere" "task 0005 is claimed elsewhere (remote:origin)" peal claim 0005
  check_refused "claim: no such task" "no task 0042" peal claim 0042
  check_refused "claim: no id" "claim: ID" peal claim
  check_refused "claim: an id and --next" "claim: ID" peal claim 0001 --next

  # An open milestone's task is claimed by number.
  out=$(peal claim 0006 2>&1)
  check "claim: an open milestone by number" "0" "$?"

  # Awaiting merge: the branch's tip has the task under done/.
  mkdir -p "$wt/tasks/done"
  git -C "$wt" mv tasks/doing/0001-first-task.md tasks/done/
  git -C "$wt" commit -q -m close
  git -C "$wt" push -q 2>/dev/null
  check_refused "claim: awaiting merge" "task 0001 is finished and awaits the merge" peal claim 0001

  # A worktree in the way.
  put "$work" backlog 0007 in-the-way
  mkdir -p "$(dirname "$work")/work-wt/0007-in-the-way"
  check_refused "claim: a directory in the way" "0007-in-the-way is in the way" peal claim 0007
  check "claim: refused, nothing left" ":" "$(git -C "$work" branch --list 'task/0007-*'):$(on_remote task/0007-in-the-way)"
}

race() {
  local work rival out
  work=$(repo)
  put "$work" backlog 0001 wanted-task
  put "$work" backlog 0002 second-task
  rival=$(dirname "$work")/rival
  git clone -q "$(dirname "$work")/remote.git" "$rival" 2>/dev/null

  # Between this clone's look at the task and its push, the rival claims it.
  cat >"$work/.git/hooks/pre-push" <<EOF
#!/bin/sh
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
cd "$rival" && [ ! -e "$rival.won" ] && touch "$rival.won" && "$PEAL" claim 0001 >/dev/null 2>&1
exit 0
EOF
  chmod +x "$work/.git/hooks/pre-push"
  out=$(peal claim 0001 2>&1)
  check "race: lost" "3:peal: claim: task 0001 was claimed elsewhere first: the push of task/0001-wanted-task lost the race; taken back" "$?:$out"
  check "race: nothing left here" ":0:0" \
    "$(git -C "$work" branch --list 'task/*'):$(git -C "$work" worktree list --porcelain | grep -c wanted-task):$([ -e "$(dirname "$work")/work-wt/0001-wanted-task" ] && echo 1 || echo 0)"
  check "race: the rival holds it" "0001 claimed-live wanted-task remote:origin" "$(state_of 0001)"

  # --next: the best candidate lost, the next one claimed.
  rm -f "$rival.won"
  git -C "$rival" worktree remove --force "$(dirname "$work")/rival-wt/0001-wanted-task" 2>/dev/null
  git -C "$rival" branch -q -D task/0001-wanted-task
  git -C "$rival" push -q origin --delete task/0001-wanted-task 2>/dev/null
  git -C "$work" fetch -q --prune origin
  out=$(peal claim --next unassigned --print-path 2>&1)
  check "race: --next goes on to the next" "0:peal: claim: task 0001 was claimed elsewhere first: the push of task/0001-wanted-task lost the race; taken back
claimed 0002 task/0002-second-task $(dirname "$work")/work-wt/0002-second-task
$(dirname "$work")/work-wt/0002-second-task" "$?:$out"
  rm "$work/.git/hooks/pre-push"
  out=$(peal claim --next 2>&1)
  check "next: nothing left" "1:peal: claim: no free task in current,unassigned" "$?:$out"

  # A push refused for another reason is no race, and taken back too.
  put "$work" backlog 0003 refused-task
  printf '#!/bin/sh\necho "no pushes today" >&2\nexit 1\n' >"$(dirname "$work")/remote.git/hooks/pre-receive"
  chmod +x "$(dirname "$work")/remote.git/hooks/pre-receive"
  out=$(peal claim 0003 2>&1)
  check "push refused: status 2" "2" "$(peal claim 0003 >/dev/null 2>&1; echo $?)"
  check "push refused: said so" "1" "$(grep -c 'a claim not pushed is none' <<<"$out")"
  check "push refused: nothing left" "" "$(git -C "$work" branch --list 'task/0003-*')"
  rm "$(dirname "$work")/remote.git/hooks/pre-receive"
}

resume() {
  local work wt out
  work=$(repo)
  put "$work" backlog 0001 parked-task
  wt=$(dirname "$work")/work-wt/0001-parked-task
  peal claim 0001 >/dev/null 2>&1
  echo work >"$wt/work.txt"
  git -C "$wt" add work.txt
  git -C "$wt" commit -q -m "wip: some work"
  git -C "$work" worktree remove "$wt"
  check "resume: parked" "parked" "$(state_of 0001 | cut -d' ' -f2)"

  out=$(peal claim 0001 --print-path 2>&1)
  check "resume" "0:resumed 0001 task/0001-parked-task $wt
$wt" "$?:$out"
  check "resume: the work is there" "work" "$(cat "$wt/work.txt")"
  check "resume: pushed" "$(git -C "$wt" rev-parse HEAD)" "$(git -C "$work" ls-remote origin refs/heads/task/0001-parked-task | cut -f1)"
  check "resume: claimed-live" "0001 claimed-live parked-task wt:$wt" "$(state_of 0001)"

  # A stale local branch with nothing on it claims nothing, and says so.
  put "$work" backlog 0002 stale-task
  git -C "$work" branch -q task/0002-stale-task origin/main
  check_refused "resume: a stale branch" "holds nothing beyond main" peal claim 0002
}

overlap() {
  local work other out
  work=$(repo)
  put "$work" backlog 0001 other-task
  put "$work" backlog 0002 overlapping-task
  # shellcheck disable=SC2016 # backticks, not an expansion
  printf '## Scope\n\n- `src/engine/` and `docs/notes.md`, `main.c`\n' >"$work/scope.md"
  { sed -n '1,/^## Intent/p' "$work/tasks/backlog/0002-overlapping-task.md"; echo; cat "$work/scope.md"; echo
    sed -n '/^## Raw/,$p' "$work/tasks/backlog/0002-overlapping-task.md"; } >"$work/tmp.md"
  mv "$work/tmp.md" "$work/tasks/backlog/0002-overlapping-task.md"
  rm "$work/scope.md"
  publish "$work"
  other=$(dirname "$work")/work-wt/0001-other-task
  peal claim 0001 >/dev/null 2>&1
  mkdir -p "$other/src/engine" "$other/lib"
  echo x >"$other/src/engine/core.c"
  echo x >"$other/lib/main.c"
  echo x >"$other/README"
  git -C "$other" add -A
  git -C "$other" commit -q -m "feat: work [0001]"
  out=$(peal claim 0002 2>&1 >/dev/null)
  check "overlap: warned, claimed anyway" "peal: warning: Scope names main.c, which task 0001 (claimed-live) changes already: lib/main.c
peal: warning: Scope names src/engine/, which task 0001 (claimed-live) changes already: src/engine/core.c" "$out"
  check "overlap: claimed" "claimed-live" "$(state_of 0002 | cut -d' ' -f2)"
}

release() {
  local work wt out gd
  work=$(repo)
  put "$work" backlog 0001 done-work
  wt=$(dirname "$work")/work-wt/0001-done-work
  peal claim 0001 >/dev/null 2>&1

  check_refused "release: not landed" "task 0001 stays: task 0001 is not done on the main branch" peal release 0001
  land "$work" 0001 done-work
  check_refused "release: its own worktree" "stays: it is the worktree this runs in" at "$wt" "$PEAL" release 0001
  gd=$(admin "$wt")
  : >"$gd/peal-heartbeat"
  check_refused "release: live" "stays: a session worked there in the last 30 minutes" peal release 0001
  touch -t 202001010000 "$gd/peal-heartbeat"
  echo scratch >"$wt/scratch.txt"
  check_refused "release: dirty" "stays: its worktree holds uncommitted changes" peal release 0001
  git -C "$wt" add scratch.txt
  git -C "$wt" commit -q -m "wip: scratch"
  check_refused "release: unpushed" "stays: its branch holds commits not pushed" peal release 0001
  git -C "$wt" push -q 2>/dev/null
  check "release: nothing removed so far" "1" "$([ -d "$wt" ] && echo 1)"

  out=$(peal release 0001 2>&1)
  check "release" "0:released 0001 task/0001-done-work, tip kept as refs/reaped/0001-done-work" "$?:$out"
  check "release: the worktree gone" "0" "$([ -e "$wt" ] && echo 1 || echo 0)"
  check "release: the branch gone, here and there" ":" "$(git -C "$work" branch --list 'task/*'):$(on_remote task/0001-done-work)"
  check "release: the tip kept" "wip: scratch" "$(git -C "$work" log -1 --format=%s refs/reaped/0001-done-work)"
  check "release: done" "0001 done done-work" "$(state_of 0001)"
  check_refused "release: nothing left" "task 0001 has no branch here" peal release 0001
  check_refused "release: no id" "release: ID" peal release
}

reap() {
  local work dir out gd common
  work=$(repo)
  dir=$(dirname "$work")/work-wt
  # The hooks act only in a repository that uses Peal.
  mkdir "$work/.peal"
  for t in 0001-reaped-one 0002-dirty-one 0003-unpushed-one 0004-live-one 0005-working-one 0006-gone-one; do
    put "$work" backlog "${t%%-*}" "${t#*-}"
    peal claim "${t%%-*}" >/dev/null 2>&1
  done
  for t in 0001-reaped-one 0002-dirty-one 0003-unpushed-one 0004-live-one 0006-gone-one; do
    land "$work" "${t%%-*}" "${t#*-}"
  done
  echo x >"$dir/0002-dirty-one/x"
  git -C "$dir/0003-unpushed-one" commit -q --allow-empty -m "wip: more"
  : >"$(admin "$dir/0004-live-one")/peal-heartbeat"
  rm -rf "$dir/0006-gone-one"
  # A worktree outside the worktrees directory is not Peal's to reap.
  git -C "$work" fetch -q
  git -C "$work" worktree add -q -b task/0009-by-hand "$(dirname "$work")/by-hand" origin/main 2>/dev/null

  # A kept tip past its time expires; one without a time stays.
  common=$(git -C "$work" rev-parse --git-common-dir)
  git -C "$work" update-ref refs/reaped/0100-old-one HEAD
  mkdir -p "$work/$common/peal-reaped"
  echo 1000 >"$work/$common/peal-reaped/0100-old-one"
  git -C "$work" update-ref refs/reaped/0101-timeless HEAD

  out=$(at "$work" "$PEAL" hook session-start <<<'{"source":"startup"}' 2>&1 | grep -E '^(reaped|kept)')
  check "reap: landed, clean, pushed, idle ones go; the others stay" "reaped 0001 task/0001-reaped-one, tip kept as refs/reaped/0001-reaped-one
kept 0002 $dir/0002-dirty-one: landed, but its worktree holds uncommitted changes
kept 0003 $dir/0003-unpushed-one: landed, but its branch holds commits not pushed
reaped 0006 task/0006-gone-one, tip kept as refs/reaped/0006-gone-one" "$out"
  check "reap: what is left" "task/0002-dirty-one
task/0003-unpushed-one
task/0004-live-one
task/0005-working-one
task/0009-by-hand" "$(git -C "$work" for-each-ref --format='%(refname:short)' 'refs/heads/task/*')"
  check "reap: the kept tips" "refs/reaped/0001-reaped-one
refs/reaped/0006-gone-one
refs/reaped/0101-timeless" "$(git -C "$work" for-each-ref --format='%(refname)' refs/reaped/)"

  # A session never reaps the worktree it runs in.
  put "$work" backlog 0007 own-one
  peal claim 0007 >/dev/null 2>&1
  land "$work" 0007 own-one
  at "$dir/0007-own-one" "$PEAL" hook session-start <<<'{"source":"startup"}' >/dev/null 2>&1
  check "reap: not its own" "task/0007-own-one" "$(git -C "$work" branch --list --format='%(refname:short)' 'task/0007-*')"

  # Resumed or compacted sessions reap nothing.
  out=$(at "$work" "$PEAL" hook session-start <<<'{"source":"resume"}' 2>&1 | grep -cE '^(reaped|kept)')
  check "reap: only on a new session" "0" "$out"
}

cases() {
  offer
  offer_priority
  claim
  race
  resume
  overlap
  release
  reap
}

for_each_awk cases
finish
