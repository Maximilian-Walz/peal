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
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

# hook DIR NAME JSON -> the hook NAME run in DIR with JSON on stdin; its status, stdout
# and stderr as "status:output".
hook() {
  local out
  out=$(cd "$1" && "$PEAL" hook "$2" <<<"$3" 2>&1)
  printf '%s:%s' "$?" "$out"
}

# hook_stdout DIR NAME JSON -> like hook, but stdout only, stderr dropped: what a
# SessionStart hook's caller actually shows the session, since a hook's stderr never
# reaches it. Cases that must land in the orientation, not only on stderr, use this.
hook_stdout() {
  local out
  out=$(cd "$1" && "$PEAL" hook "$2" <<<"$3" 2>/dev/null)
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

# guarded_repo -> repo, with a committed .peal/config.yml recording the guardrails stage.
guarded_repo() {
  local work
  work=$(repo)
  mkdir "$work/.peal"
  printf 'stages: [tasks, guardrails]\n' >"$work/.peal/config.yml"
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
  local work wt before
  work=$(peal_repo)
  put "$work" backlog 0001 saved-task
  (cd "$work" && "$PEAL" claim 0001) >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0001-saved-task
  remote_tip() { git -C "$work" ls-remote origin refs/heads/task/0001-saved-task | cut -f1; }

  echo draft >"$wt/draft.txt"
  # An untracked symlink to /dev/null (a sandbox's /dev/null mount) sits beside it: real
  # work, and something that is not.
  ln -s /dev/null "$wt/dev-null"
  check "autosave: a clear is no end" "0:" "$(hook "$wt" session-end '{"reason":"clear"}')"
  check "autosave: a subagent's end is not the session's" "0:" "$(hook "$wt" session-end '{"reason":"other","agent_id":"a1"}')"
  check "autosave: nothing so far, raw git lists both (the control)" "?? dev-null
?? draft.txt" "$(git -C "$wt" status --porcelain)"

  check "autosave: silent" "0:" "$(hook "$wt" session-end '{"reason":"prompt_input_exit"}')"
  check "autosave: committed" "wip: session-end autosave [0001]" "$(git -C "$wt" log -1 --format=%s)"
  check "autosave: the link never staged" "" "$(git -C "$wt" ls-files dev-null)"
  check "autosave: the link still there, raw status, nothing else" "?? dev-null" "$(git -C "$wt" status --porcelain)"
  check "autosave: pushed" "$(git -C "$wt" rev-parse HEAD)" "$(remote_tip)"

  # Only the link left: no work to autosave, so no commit at all.
  before=$(git -C "$wt" rev-parse HEAD)
  check "autosave: only the link, silent" "0:" "$(hook "$wt" session-end '{"reason":"logout"}')"
  check "autosave: HEAD unchanged, no commit made" "$before" "$(git -C "$wt" rev-parse HEAD)"

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

# gates -> a fresh clone whose config records the `guardrails` stage gets its git gates
# from the SessionStart hook itself (lib/githooks.sh, peal_hooks_ensure), named directly
# after "Peal:" (0059).
gates() {
  local work dir hooksdir out

  work=$(guarded_repo)
  dir=$(cd "$work/.git" && pwd)/peal/hooks
  hooksdir=$(cd "$work/.git" && pwd)/hooks

  out=$(hook "$work" session-start '{"source":"startup"}')
  check "gates: installs the hooks, right after Peal:" \
    "0:Peal:
installed Peal's git hooks in $dir (core.hooksPath); they chain to the hooks in $hooksdir
Current milestone: m1, Milestone m1 (docs/milestones/m1.md)
Task: none in this worktree. /peal:work claims one into a worktree of its own.
Next to adopt: review-task, m1 current, no review task. For the human: /peal:next says more; nothing changes unasked." "$out"
  check "gates: core.hooksPath" "$dir" "$(git -C "$work" config core.hooksPath)"

  out=$(hook "$work" session-start '{"source":"startup"}')
  check "gates: a second start, no hooks line" "0" \
    "$(printf '%s\n' "$out" | grep -c "installed Peal's git hooks")"

  # Without guardrails: nothing installed, no line.
  work=$(repo)
  out=$(hook "$work" session-start '{"source":"startup"}')
  check "gates: no guardrails stage, no line" "0" "$(printf '%s\n' "$out" | grep -c 'git hooks')"
  check "gates: no guardrails stage, core.hooksPath stays unset" "" "$(git -C "$work" config core.hooksPath)"

  # A foreign core.hooksPath: the warning, naming the command, left unchanged, in the
  # stdout orientation (not only on stderr, which a SessionStart hook's caller drops).
  work=$(guarded_repo)
  git -C "$work" config core.hooksPath custom-hooks
  out=$(hook_stdout "$work" session-start '{"source":"startup"}')
  check "gates: a foreign core.hooksPath warns, right after Peal:" \
    "0:Peal:
peal: Peal's git hooks are not installed: core.hooksPath is custom-hooks; to install them chained to it, run: .peal/peal hooks install
Current milestone: m1, Milestone m1 (docs/milestones/m1.md)
Task: none in this worktree. /peal:work claims one into a worktree of its own.
Next to adopt: review-task, m1 current, no review task. For the human: /peal:next says more; nothing changes unasked." "$out"
  check "gates: a foreign core.hooksPath is left alone" "custom-hooks" "$(git -C "$work" config core.hooksPath)"

  # A forced failure: the common directory's peal/ blocked by a plain file. The command
  # must reach stdout too, not only stderr.
  work=$(guarded_repo)
  : >"$work/.git/peal"
  out=$(hook_stdout "$work" session-start '{"source":"startup"}')
  check "gates: a failure exits 0, names the command, in stdout" "0:1" \
    "${out%%:*}:$(printf '%s\n' "$out" | grep -c "could not be installed.*\\.peal/peal hooks install")"
}

# hint -> /peal:next's SessionStart hint (lib/next.sh, peal_next_hint): shown on
# startup/clear outside a task's worktree, silent otherwise, and (issues storage) no gh
# call beyond what the orientation already makes.
hint() {
  local work wt out n1 n2 n3

  work=$(peal_repo)
  put "$work" backlog 0001 solo-task
  (cd "$work" && "$PEAL" claim 0001) >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0001-solo-task

  check "hint: shown on startup, outside a task's worktree" \
    "Next to adopt: tasks. For the human: /peal:next says more; nothing changes unasked." \
    "$(hook "$work" session-start '{"source":"startup"}' | tail -n 1)"
  check "hint: shown on clear too" "1" \
    "$(hook "$work" session-start '{"source":"clear"}' | grep -c '^Next to adopt:')"
  check "hint: silent on resume" "0" \
    "$(hook "$work" session-start '{"source":"resume"}' | grep -c '^Next to adopt:')"
  check "hint: silent inside a task's worktree" "0" \
    "$(hook "$wt" session-start '{"source":"startup"}' | grep -c '^Next to adopt:')"

  # State A: stages: [tasks] only, 12 done, no milestones stage. guardrails wins (the
  # catalogue's order: the stages of peal init, then review-task last). Declining it
  # leaves milestones (12 done meets its threshold), the next in that order.
  work=$(peal_repo)
  printf 'stages: [tasks]\n' >>"$work/.peal/config.yml"
  publish "$work" >/dev/null 2>&1
  for i in 0001 0002 0003 0004 0005 0006 0007 0008 0009 0010 0011 0012; do put "$work" "done" "$i" "task-$i"; done
  check "hint: state A, names guardrails" "1" \
    "$(hook "$work" session-start '{"source":"startup"}' | grep -c '^Next to adopt: guardrails')"
  at "$work" "$PEAL" next --decline guardrails >/dev/null 2>&1
  check "hint: state A, guardrails declined, names milestones" "1" \
    "$(hook "$work" session-start '{"source":"startup"}' | grep -c '^Next to adopt: milestones')"

  # Everything this task's catalogue knows is set up, m1's review task is filed, and
  # .peal/review.md already there (m0, the fixture's own milestone, is otherwise always
  # done, so review-steps would fire): NONE.
  work=$(peal_repo)
  printf 'stages: [tasks, guardrails, milestones, belfry]\n' >>"$work/.peal/config.yml"
  publish "$work" >/dev/null 2>&1
  put "$work" backlog 0001 review-m1 "milestone: m1" "depends: [milestone]"
  : >"$work/.peal/review.md"
  check "hint: silent once nothing is left" "0" \
    "$(hook "$work" session-start '{"source":"startup"}' | grep -c '^Next to adopt:')"

  # A malformed declined date: the orientation still runs, no hint, status 0.
  work=$(peal_repo)
  printf 'declined:\n  guardrails: [not-a-date]\n' >>"$work/.peal/config.yml"
  publish "$work" >/dev/null 2>&1
  out=$(hook "$work" session-start '{"source":"startup"}')
  check "hint: a malformed declined date, status 0, no hint, orientation intact" \
    "0:Peal:
Current milestone: m1, Milestone m1 (docs/milestones/m1.md)
Task: none in this worktree. /peal:work claims one into a worktree of its own." "$out"

  # Issues storage: the hint reuses the orientation's own list and milestones (never gh
  # of its own). A real baseline: the same worktree, the same startup (so the same fetch
  # and peal_reap's own re-list happen either way), only review-task qualifies (every
  # stage recorded, m1 current with no review task filed) so the first startup hints;
  # declining it leaves review-steps (m0, closed in the issues fixture too, counts as
  # done, and there is no .peal/review.md yet), a feature item within the stages, still
  # with no .peal/review.md; declining that too (a local file edit each time, no gh call)
  # finally leaves NONE, so the third is silent. Equal gh call counts throughout prove
  # the hint itself, whatever it says, costs none of its own.
  command -v jq >/dev/null 2>&1 || return 0
  ISSUES_CONFIG=$'stages: [tasks, guardrails, milestones, belfry]\n' issues_repo
  : >"$FAKE_GH/log"
  out=$(hook "$work" session-start '{"source":"startup"}')
  n1=$(wc -l <"$FAKE_GH/log" | tr -d ' ')
  check "hint: issues storage, the hinted run actually hints" "1" \
    "$(printf '%s\n' "$out" | grep -c '^Next to adopt: review-task')"

  at "$work" "$PEAL" next --decline review-task >/dev/null 2>&1
  : >"$FAKE_GH/log"
  out=$(hook "$work" session-start '{"source":"startup"}')
  n2=$(wc -l <"$FAKE_GH/log" | tr -d ' ')
  check "hint: issues storage, a feature item within the stages hints next" "1" \
    "$(printf '%s\n' "$out" | grep -c '^Next to adopt: review-steps')"
  check "hint: issues storage, no gh call of its own" "$n1" "$n2"

  at "$work" "$PEAL" next --decline review-steps >/dev/null 2>&1
  : >"$FAKE_GH/log"
  out=$(hook "$work" session-start '{"source":"startup"}')
  n3=$(wc -l <"$FAKE_GH/log" | tr -d ' ')
  check "hint: issues storage, the baseline run is silent" "0" \
    "$(printf '%s\n' "$out" | grep -c '^Next to adopt:')"
  check "hint: issues storage, still no gh call of its own" "$n1" "$n3"
}

cases() {
  orientation
  budget
  autosave
  gates
  hint
}

for_each_awk cases
finish
