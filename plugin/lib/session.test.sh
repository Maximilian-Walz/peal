#!/usr/bin/env bash
# Harness for the session hooks (lib/session.sh): the SessionStart orientation, the turn
# budget and heartbeat of PostToolUse, the SessionEnd autosave, against throwaway
# repositories with a bare remote:
#
#   bash plugin/lib/session.test.sh
#
# Reaping at SessionStart is in claim.test.sh, with the rest of releasing.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

# hook DIR NAME JSON -> the hook NAME run in DIR with JSON on stdin; its status, stdout
# and stderr as "status:output".
hook() {
  local out
  out=$(cd "$1" && "$PEAL" hook "$2" <<<"$3" 2>&1)
  printf '%s:%s' "$?" "$out"
}

# peal_repo -> repo, with a committed .peal/config.yml of small size tiers.
peal_repo() {
  local work
  work=$(repo)
  mkdir "$work/.peal"
  printf 'sizes: {S: 3, M: 5, L: 8}\n' >"$work/.peal/config.yml"
  publish "$work"
  printf '%s\n' "$work"
}

orientation() {
  local work wt other
  work=$(peal_repo)
  put "$work" backlog 0001 split-origin "milestone: m1"
  put "$work" backlog 0002 first-piece "milestone: m1" "part-of: 0001"
  put "$work" backlog 0003 second-piece "part-of: 0002"
  put "$work" backlog 0004 other-claim
  put "$work" "done" 0005 done-split
  put "$work" "done" 0006 done-piece "part-of: 0005"
  (cd "$work" && "$PEAL" claim 0002 && "$PEAL" claim 0004) >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0002-first-piece
  other=$(dirname "$work")/work-wt/0004-other-claim

  check "orientation: in a task's worktree" "0:Peal:
Current milestone: m1, Milestone m1 (docs/milestones/m1.md)
Task: 0002, tasks/doing/0002-first-piece.md: this worktree's task and this session's whole scope. Read it first.
Other claims:
  0004 claimed-live other-claim wt:$other
Open splits:
  0001 Title of 0001: 0/3 done, open: 0001 free, 0002 claimed-live, 0003 free" "$(hook "$wt" session-start '{"source":"startup"}')"
  check "orientation: CLAUDE_PROJECT_DIR over the working directory" "Task: 0002" \
    "$(CLAUDE_PROJECT_DIR=$wt hook "$work" session-start '{}' | sed -n 3p | cut -d, -f1)"
  check "orientation: no task here" "Task: none in this worktree. /peal:work claims one into a worktree of its own." \
    "$(hook "$work" session-start '{"source":"resume"}' | sed -n 3p)"
  check "orientation: the heartbeat" "1" "$([ -e "$(git -C "$wt" rev-parse --absolute-git-dir)/peal-heartbeat" ] && echo 1)"

  # Without a current milestone.
  sed -i.bak 's/^state: current/state: open/' "$work/docs/milestones/m1.md" && rm "$work/docs/milestones/m1.md.bak"
  publish "$work"
  check "orientation: no current milestone" "Current milestone: none" "$(hook "$work" session-start '{}' | sed -n 2p)"
}

budget() {
  local work wt gd out
  work=$(peal_repo)
  put "$work" backlog 0001 small-task "size: S"
  put "$work" backlog 0002 unsized-task
  (cd "$work" && "$PEAL" claim 0001 && "$PEAL" claim 0002) >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0001-small-task
  gd=$(git -C "$wt" rev-parse --absolute-git-dir)

  check "budget: counted, silent" "0:" "$(hook "$wt" post-tool-use '{"tool_name":"Bash"}')"
  check "budget: a subagent's call is not counted" "0:" "$(hook "$wt" post-tool-use '{"agent_id":"a1"}')"
  check "budget: the count" "1" "$(cat "$gd/peal-turns")"
  hook "$wt" post-tool-use '{}' >/dev/null
  out=$(hook "$wt" post-tool-use '{}')
  check "budget: the nudge at the tier" "2:TURN BUDGET: 3 tool calls on task 0001, size S, whose tier is 3." "$(printf '%s\n' "$out" | head -n 1)"
  check "budget: once" "0:" "$(hook "$wt" post-tool-use '{}')"
  check "budget: still counting" "4" "$(cat "$gd/peal-turns")"
  hook "$wt" session-start '{"source":"resume"}' >/dev/null
  check "budget: a resumed session keeps the count" "4" "$(cat "$gd/peal-turns")"
  hook "$wt" session-start '{"source":"startup"}' >/dev/null
  check "budget: a new session starts again" "0" "$(cat "$gd/peal-turns")"
  for _ in 1 2; do hook "$wt" post-tool-use '{}' >/dev/null; done
  check "budget: and nudges again" "2" "$(hook "$wt" post-tool-use '{}' | head -n 1 | cut -d: -f1)"

  # An unsized task nudges at M.
  wt=$(dirname "$work")/work-wt/0002-unsized-task
  for _ in 1 2 3 4; do hook "$wt" post-tool-use '{}' >/dev/null; done
  check "budget: unsized, at M" "2:TURN BUDGET: 5 tool calls on task 0002, size unsized, taken as M, whose tier is 5." \
    "$(hook "$wt" post-tool-use '{}' | head -n 1)"

  # Outside a task's worktree nothing is counted, but the heartbeat beats.
  check "budget: no task here" "0:" "$(hook "$work" post-tool-use '{}')"
  check "budget: no count on main" "0" "$([ -e "$work/.git/peal-turns" ] && echo 1 || echo 0)"
  check "budget: the heartbeat on main" "1" "$([ -e "$work/.git/peal-heartbeat" ] && echo 1)"
}

autosave() {
  local work wt
  work=$(peal_repo)
  put "$work" backlog 0001 saved-task
  (cd "$work" && "$PEAL" claim 0001) >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0001-saved-task
  remote_tip() { git -C "$work" ls-remote origin refs/heads/task/0001-saved-task | cut -f1; }

  echo draft >"$wt/draft.txt"
  check "autosave: a clear is no end" "0:" "$(hook "$wt" session-end '{"reason":"clear"}')"
  check "autosave: a subagent's end is not the session's" "0:" "$(hook "$wt" session-end '{"reason":"other","agent_id":"a1"}')"
  check "autosave: nothing so far" "?? draft.txt" "$(git -C "$wt" status --porcelain)"

  check "autosave: silent" "0:" "$(hook "$wt" session-end '{"reason":"prompt_input_exit"}')"
  check "autosave: committed" "wip: session-end autosave [0001]" "$(git -C "$wt" log -1 --format=%s)"
  check "autosave: clean" "" "$(git -C "$wt" status --porcelain)"
  check "autosave: pushed" "$(git -C "$wt" rev-parse HEAD)" "$(remote_tip)"

  # Clean but unpushed: pushed.
  git -C "$wt" commit -q --allow-empty -m "wip: local"
  hook "$wt" session-end '{"reason":"logout"}' >/dev/null
  check "autosave: an unpushed commit pushed" "$(git -C "$wt" rev-parse HEAD)" "$(remote_tip)"

  # No upstream yet: pushed and tracked.
  git -C "$wt" branch -q --unset-upstream
  git -C "$wt" commit -q --allow-empty -m "wip: untracked"
  hook "$wt" session-end '{"reason":"other"}' >/dev/null
  check "autosave: no upstream, pushed" "$(git -C "$wt" rev-parse HEAD)" "$(remote_tip)"
  check "autosave: and tracked" "origin/task/0001-saved-task" "$(git -C "$wt" rev-parse --abbrev-ref '@{upstream}')"

  # The main checkout is no task's: nothing is committed there.
  echo stray >"$work/stray.txt"
  hook "$work" session-end '{"reason":"other"}' >/dev/null
  check "autosave: not on main" "?? stray.txt" "$(git -C "$work" status --porcelain)"
}

cases() {
  orientation
  budget
  autosave
}

for_each_awk cases
finish
