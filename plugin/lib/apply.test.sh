#!/usr/bin/env bash
# Harness for peal apply (lib/apply.sh, lib/apply.awk), against throwaway repositories
# with a bare remote:
#
#   bash plugin/lib/apply.test.sh
#
# A batch of mixed proposals as one commit, by push and through a pull request (the fake
# gh, which needs jq); filed numbers skipping a rival's; the milestone kinds, mixed with
# task ones, their states and the next current milestone, a new milestone's id; each kind
# of invalid batch changing nothing; the JSON reader's escapes, a 1 MiB string among
# them; values ending in 20,000 newlines; the issues storage refusing.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }
main_sha() { git -C "$work" fetch -q origin; git -C "$work" rev-parse origin/main; }
tree_on_main() { git -C "$work" fetch -q origin; git -C "$work" ls-tree -r --name-only origin/main tasks; }

# setup_tasks -> work with the tasks a batch acts on: 0001..0004 in the backlog, 0003
# waiting for 0004 (which 0004's duplicate, 0002, replaces).
setup_tasks() {
  work=$(repo)
  put "$work" backlog 0001 first-task "milestone: m1"
  put "$work" backlog 0002 second-task "priority: high"
  put "$work" backlog 0003 third-task "depends: [0004]"
  put "$work" backlog 0004 fourth-task
}

# batch -> the mixed batch of the plan, as JSON.
batch() {
  cat <<'EOF'
{"proposals": [
  {"id": "p1", "kind": "file", "title": "Model the crate for level two",
   "text": "---\nmilestone: m2\npriority: low\n---\n\n# NNNN — The crate\n\n## Intent\n\nWhy.\n\n## Raw\n\nthe human said so\n\n## Notes\n\n---\n\n## Outcome\n\n<!-- fill in at close -->",
   "milestone": "m1", "priority": "high", "owner": "human", "origin": "outsider", "why": "triage found it"},
  {"id": "p2", "kind": "file", "title": "Ship the crate", "text": "---\n---\n\n# NNNN — Ship it\n\n## Raw\n\nsaid\n\n## Notes\n", "why": "after the crate"},
  {"id": "p3", "kind": "depends", "task": "@p2", "on": "@p1", "why": "the crate first"},
  {"id": "p4", "kind": "add", "task": "0001", "text": "Seen in the field \u00e9", "origin": "outsider", "why": "a report"},
  {"id": "p5", "kind": "move", "task": "0001", "milestone": null, "why": "not this milestone"},
  {"id": "p6", "kind": "priority", "task": "0002", "priority": "normal"},
  {"id": "p7", "kind": "priority", "task": "0004", "priority": "urgent"},
  {"id": "p8", "kind": "depends", "task": "0003", "on": "0004", "remove": true},
  {"id": "p9", "kind": "depends", "task": "0003", "on": "0002"},
  {"id": "p10", "kind": "retire", "task": "0004", "duplicate": "0002", "why": "the same"}
]}
EOF
}

mixed() {
  local before out st
  setup_tasks
  before=$(main_sha)
  out=$(batch | peal apply 2>"$work.err")
  st=$?
  check "mixed: status" "0" "$st"
  check "mixed: the answer" '{"id": "p1", "done": true, "outcome": "filed tasks/backlog/0005-model-the-crate-for-level.md", "task": "0005"}
{"id": "p2", "done": true, "outcome": "filed tasks/backlog/0006-ship-the-crate.md", "task": "0006"}
{"id": "p3", "done": true, "outcome": "task 0006: waits for 0005", "task": "0006"}
{"id": "p4", "done": true, "outcome": "noted on 0001", "task": "0001"}
{"id": "p5", "done": true, "outcome": "task 0001: milestone none", "task": "0001"}
{"id": "p6", "done": true, "outcome": "task 0002: priority normal", "task": "0002"}
{"id": "p7", "done": true, "outcome": "task 0004: priority urgent", "task": "0004"}
{"id": "p8", "done": true, "outcome": "task 0003: no longer waits for 0004", "task": "0003"}
{"id": "p9", "done": true, "outcome": "task 0003: waits for 0002", "task": "0003"}
{"id": "p10", "done": true, "outcome": "retired tasks/done/0004-fourth-task.md", "task": "0004"}' "$out"
  check "mixed: one commit" "$before" "$(git -C "$work" rev-parse origin/main~1)"
  check "mixed: the subject" "docs(tasks): apply 10 proposals" "$(git -C "$work" log -1 --format=%s origin/main)"
  check "mixed: the whys in the body" "- p1 (file 0005): triage found it
- p6 (priority 0002): no reason given" "$(git -C "$work" log -1 --format=%b origin/main | grep -e '^- p1 ' -e '^- p6 ')"
  check "mixed: the tree" "tasks/backlog/0001-first-task.md
tasks/backlog/0002-second-task.md
tasks/backlog/0003-third-task.md
tasks/backlog/0005-model-the-crate-for-level.md
tasks/backlog/0006-ship-the-crate.md
tasks/done/0004-fourth-task.md" "$(tree_on_main)"
  check "mixed: filed, the fields winning" "---
milestone: m1
priority: high
owner: human
origin: outsider
---

# 0005 — The crate" "$(on_main "$work" tasks/backlog/0005-model-the-crate-for-level.md | head -n 8)"
  on_main "$work" tasks/backlog/0006-ship-the-crate.md >"$work.t6"
  check "mixed: a filing waits for another" "0005" "$(peal frontmatter get "$work.t6" depends)"
  on_main "$work" tasks/backlog/0001-first-task.md >"$work.t1"
  check "mixed: moved out, noted, outsider" "origin=outsider milestone= note=$today: Seen in the field é" \
    "origin=$(peal frontmatter get "$work.t1" origin) milestone=$(peal frontmatter get "$work.t1" milestone) note=$(grep "^$today" "$work.t1")"
  on_main "$work" tasks/backlog/0002-second-task.md >"$work.t2"
  check "mixed: normal drops priority" "1" "$(peal frontmatter get "$work.t2" priority >/dev/null 2>&1; echo $?)"
  on_main "$work" tasks/backlog/0003-third-task.md >"$work.t3"
  check "mixed: re-pointed" "0002" "$(peal frontmatter get "$work.t3" depends)"
  check "mixed: retired as a duplicate, its earlier change kept" "priority=urgent outcome=Retired $today without being claimed: duplicate of 0002" \
    "priority=$(on_main "$work" tasks/done/0004-fourth-task.md >"$work.t4"; peal frontmatter get "$work.t4" priority) outcome=$(tail -n 1 "$work.t4")"
  check "mixed: the worktree untouched" "" "$(git -C "$work" status --porcelain)"
  check "mixed: peal check passes on the result" "0" "$(git -C "$work" pull -q origin main 2>/dev/null; peal check >/dev/null 2>&1; echo $?)"

  # An empty batch changes nothing and answers nothing.
  before=$(main_sha)
  out=$(printf '{"proposals": []}' | peal apply 2>/dev/null)
  check "empty batch" "0::$before" "$?:$out:$(main_sha)"
  # A batch that changes nothing (the priority it has already) writes nothing.
  out=$(printf '{"proposals": [{"id": "a", "kind": "priority", "task": "0002", "priority": "normal"}]}' | peal apply 2>/dev/null)
  check "a batch changing nothing" "0:{\"id\": \"a\", \"done\": true, \"outcome\": \"task 0002: priority normal\", \"task\": \"0002\"}:$before" "$?:$out:$(main_sha)"
}

# vouch -> the vouch kind: dropping origin: outsider, the note under Notes, the answers.
vouch() {
  local before out st
  setup_tasks
  put "$work" backlog 0005 fifth-task "origin: outsider"
  put "$work" backlog 0006 sixth-task "origin: outsider"
  put "$work" backlog 0007 seventh-task "origin: outsider"
  # 0006 has no Notes section; 0007 an outsider's note already.
  sed -i.bak '/^## Notes$/d' "$work/tasks/backlog/0006-sixth-task.md"
  sed -i.bak "s/^## Notes\$/## Notes\n\n$today: outsider said: hello/" "$work/tasks/backlog/0007-seventh-task.md"
  rm -f "$work"/tasks/backlog/*.bak
  publish "$work"
  git -C "$work" fetch -q origin
  before=$(main_sha)
  out=$(printf '%s' '{"proposals": [{"id": "v", "kind": "vouch", "task": "0007", "why": "read it, fine"}]}' | peal apply 2>/dev/null)
  st=$?
  check "vouch: status and answer" '0:{"id": "v", "done": true, "outcome": "task 0007: vouched for, a writer'"'"'s now", "task": "0007"}' "$st:$out"
  check "vouch: one commit, the subject" "$before:docs(tasks): apply 1 proposal" "$(git -C "$work" rev-parse origin/main~1):$(git -C "$work" log -1 --format=%s origin/main)"
  check "vouch: the body" "- v (vouch 0007): read it, fine" "$(git -C "$work" log -1 --format=%b origin/main | grep '^- v ')"
  on_main "$work" tasks/backlog/0007-seventh-task.md >"$work.t"
  check "vouch: no origin" "1" "$(peal frontmatter get "$work.t" origin >/dev/null 2>&1; echo $?)"
  check "vouch: the line directly under Notes, the earlier note kept" "## Notes|$today: Vouched for by a writer: read it, fine|$today: outsider said: hello" \
    "$(awk '/^## Notes$/ { n = 1 } /^---$/ { n = 0 } n && NF { printf "%s%s", sep, $0; sep = "|" }' "$work.t")"
  git -C "$work" pull -q origin main 2>/dev/null
  check "vouch: peal check passes" "0" "$(peal check >/dev/null 2>&1; echo $?)"

  # No why.
  out=$(printf '%s' '{"proposals": [{"id": "v", "kind": "vouch", "task": "0005"}]}' | peal apply 2>/dev/null)
  on_main "$work" tasks/backlog/0005-fifth-task.md >"$work.t"
  check "vouch: no why" "$today: Vouched for by a writer." "$(grep "^$today" "$work.t")"
  # A why of several lines starting with a heading, on a task without Notes.
  out=$(printf '%s' '{"proposals": [{"id": "v", "kind": "vouch", "task": "0006", "why": "## Heading\nsecond\tline\r\nthird"}]}' | peal apply 2>/dev/null)
  on_main "$work" tasks/backlog/0006-sixth-task.md >"$work.t"
  check "vouch: a multi-line why is one line, a missing Notes section added above the Outcome rule" \
    "$today: Vouched for by a writer: ## Heading second line  third|1|## Notes|$today: Vouched for by a writer: ## Heading second line  third|---|## Outcome" \
    "$(grep "^$today" "$work.t")|$(grep -c "^$today" "$work.t")|$(awk '/^## Notes$/ { n = 1 } n && NF { printf "%s%s", sep, $0; sep = "|" } /^## Outcome$/ { exit }' "$work.t")"
  git -C "$work" pull -q origin main 2>/dev/null
  check "vouch: peal check passes on a task without Notes" "0" "$(peal check >/dev/null 2>&1; echo $?)"

  # A writer's task: done, nothing written.
  git -C "$work" fetch -q origin
  before=$(main_sha)
  out=$(printf '%s' '{"proposals": [{"id": "v", "kind": "vouch", "task": "0001", "why": "x"}]}' | peal apply 2>/dev/null)
  check "vouch: already a writer's" '0:{"id": "v", "done": true, "outcome": "task 0001: already a writer'"'"'s", "task": "0001"}:'"$before" "$?:$out:$(main_sha)"

  # An add marking the task outsider's, then the vouch, in one batch.
  out=$(printf '%s' '{"proposals": [{"id": "a", "kind": "add", "task": "0002", "text": "a report", "origin": "outsider"},
    {"id": "v", "kind": "vouch", "task": "0002", "why": "checked"}]}' | peal apply 2>/dev/null)
  st=$?
  on_main "$work" tasks/backlog/0002-second-task.md >"$work.t"
  check "vouch: after an outsider's add, one batch" "0:1:$today: Vouched for by a writer: checked|$today: a report" \
    "$st:$(peal frontmatter get "$work.t" origin >/dev/null 2>&1; echo $?):$(grep "^$today" "$work.t" | paste -sd '|' -)"

  # Invalids.
  put "$work" backlog 0008 eighth-task "origin: outsider"
  git -C "$work" push -q origin "origin/main:refs/heads/task/0008-eighth-task" 2>/dev/null
  git -C "$work" fetch -q origin
  local ok='{"id": "ok", "kind": "priority", "task": "0001", "priority": "low"}'
  invalid "a vouch on a claimed task" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"vouch\", \"task\": \"0008\"}]}" 2 "task 0008 is claimed"
  invalid "a vouch on no such task" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"vouch\", \"task\": \"0042\"}]}" 2 "no task 0042"
  invalid "a vouch with an unknown field" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"vouch\", \"task\": \"0001\", \"by\": \"me\"}]}" 2 "field by is not one vouch takes"
  invalid "a vouch on an @ref" "{\"proposals\": [{\"id\": \"f\", \"kind\": \"file\", \"title\": \"Some new task\", \"text\": \"---\\norigin: outsider\\n---\\n\\n# NNNN — T\\n\\n## Raw\\n\\nx\\n\"}, {\"id\": \"b\", \"kind\": \"vouch\", \"task\": \"@f\"}]}" 2 "vouches for a task the batch files"
  invalid "a vouch carrying origin outsider" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"vouch\", \"task\": \"0001\", \"origin\": \"outsider\"}]}" 2 "a vouch is a writer's, not an outsider's"
  invalid "a vouch without a task" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"vouch\"}]}" 2 "no task"
}

# ms_batch -> a batch of task and milestone proposals, as JSON.
ms_batch() {
  cat <<'EOF'
{"proposals": [
  {"id": "p1", "kind": "milestone_create", "title": "Level two: crates", "goal": "Crates ship.", "due": "2027-01-31", "why": "planning"},
  {"id": "p2", "kind": "file", "title": "Model the crate", "text": "---\n---\n\n# NNNN — Crate\n\n## Raw\n\nx\n", "milestone": "@p1"},
  {"id": "p3", "kind": "move", "task": "0001", "milestone": "@p1"},
  {"id": "p4", "kind": "milestone_update", "milestone": "m1", "title": "First one", "due": null, "order": null},
  {"id": "p5", "kind": "milestone_state", "milestone": "m2", "state": "park", "reason": "until #12", "why": "blocked"}
]}
EOF
}

# ms_mixed -> task and milestone proposals in one commit: a milestone made, a task filed
# into it and one moved there by its @<id>, one retitled, one parked.
ms_mixed() {
  local before out st
  setup_tasks
  before=$(main_sha)
  out=$(ms_batch | peal apply 2>"$work.err")
  st=$?
  check "ms mixed: status" "0" "$st"
  check "ms mixed: the answer" '{"id": "p1", "done": true, "outcome": "created milestone m4 (docs/milestones/m4.md)", "milestone": "m4"}
{"id": "p2", "done": true, "outcome": "filed tasks/backlog/0005-model-the-crate.md", "task": "0005"}
{"id": "p3", "done": true, "outcome": "task 0001: milestone m4", "task": "0001"}
{"id": "p4", "done": true, "outcome": "milestone m1: title, no due, no order", "milestone": "m1"}
{"id": "p5", "done": true, "outcome": "milestone m2: parked", "milestone": "m2"}' "$out"
  check "ms mixed: one commit" "$before" "$(git -C "$work" rev-parse origin/main~1)"
  check "ms mixed: the subject" "docs(tasks): apply 5 proposals" "$(git -C "$work" log -1 --format=%s origin/main)"
  check "ms mixed: the body names the milestones" "- p1 (milestone_create m4): planning
- p5 (milestone_state m2): blocked" "$(git -C "$work" log -1 --format=%b origin/main | grep -e '^- p1 ' -e '^- p5 ')"
  check "ms mixed: the files changed" "M	docs/milestones/m1.md
M	docs/milestones/m2.md
A	docs/milestones/m4.md
M	tasks/backlog/0001-first-task.md
A	tasks/backlog/0005-model-the-crate.md" "$(git -C "$work" diff --name-status origin/main~1 origin/main)"
  check "ms mixed: the new milestone, init's text" "---
state: open
order: 4
due: 2027-01-31
---

# Level two: crates

## Goal

Crates ship.

## Acceptance criteria

- A checkable statement the milestone review walks through." "$(on_main "$work" docs/milestones/m4.md)"
  check "ms mixed: retitled in its heading, order removed" "---
state: current
---

# First one" "$(on_main "$work" docs/milestones/m1.md)"
  check "ms mixed: parked with its reason" "---
state: parked
order: 2
reason: 'until #12'
---

# Milestone m2" "$(on_main "$work" docs/milestones/m2.md)"
  on_main "$work" tasks/backlog/0005-model-the-crate.md >"$work.t5"
  check "ms mixed: filed into the new milestone" "m4" "$(peal frontmatter get "$work.t5" milestone)"
  check "ms mixed: peal check passes on the result" "0" "$(git -C "$work" pull -q origin main 2>/dev/null; peal check >/dev/null 2>&1; echo $?)"

  # A title in the frontmatter is set there, the heading left.
  printf -- '---\nstate: open\ntitle: Old\norder: 9\n---\n\n# Heading\n' >"$work/docs/milestones/m7.md"
  publish "$work"
  # shellcheck disable=SC2016 # a literal $(x), stored as it is
  out=$(printf '%s' '{"proposals": [{"id": "a", "kind": "milestone_update", "milestone": "m7", "title": "New: $(x)", "order": 3}]}' | peal apply 2>/dev/null)
  check "ms mixed: a frontmatter title" "0:---
state: open
title: 'New: \$(x)'
order: 3
---

# Heading" "$?:$(on_main "$work" docs/milestones/m7.md)"
  # The next new id: one past the highest numeric one.
  out=$(printf '%s' '{"proposals": [{"id": "a", "kind": "milestone_create", "title": "After"}]}' | peal apply 2>/dev/null)
  check "ms mixed: the next id" '{"id": "a", "done": true, "outcome": "created milestone m8 (docs/milestones/m8.md)", "milestone": "m8"}' "$out"
  check "ms mixed: its order one past the highest" "5" "$(on_main "$work" docs/milestones/m8.md >"$work.m8"; peal frontmatter get "$work.m8" order)"
}

# ms_states -> the four state verbs, a state a milestone has already, and the current
# milestone closed: the first open one by order made current in the same commit.
ms_states() {
  local out st before
  setup_tasks
  put "$work" backlog 0005 fifth-task "milestone: m3"
  out=$(printf '%s' '{"proposals": [
    {"id": "a", "kind": "move", "task": "0001", "milestone": null},
    {"id": "b", "kind": "milestone_state", "milestone": "m1", "state": "close"},
    {"id": "c", "kind": "milestone_state", "milestone": "m0", "state": "close"},
    {"id": "d", "kind": "milestone_state", "milestone": "m3", "state": "unpark"},
    {"id": "e", "kind": "move", "task": "0005", "milestone": null}]}' | peal apply 2>"$work.err")
  st=$?
  check "ms states: the answer" '0:{"id": "a", "done": true, "outcome": "task 0001: milestone none", "task": "0001"}
{"id": "b", "done": true, "outcome": "milestone m1: done", "milestone": "m1"}
{"id": "c", "done": true, "outcome": "milestone m0: done already", "milestone": "m0"}
{"id": "d", "done": true, "outcome": "milestone m3: open; milestone m2: current", "milestone": "m3"}
{"id": "e", "done": true, "outcome": "task 0005: milestone none", "task": "0005"}' "$st:$out"
  check "ms states: one commit, the next current" "docs(tasks): apply 5 proposals
M	docs/milestones/m1.md
M	docs/milestones/m2.md
M	docs/milestones/m3.md
M	tasks/backlog/0001-first-task.md
M	tasks/backlog/0005-fifth-task.md" "$(git -C "$work" log -1 --format=%s origin/main; git -C "$work" diff --name-status origin/main~1 origin/main)"
  check "ms states: the states" "m0 done m1 done m2 current m3 open" \
    "$(for m in m0 m1 m2 m3; do on_main "$work" "docs/milestones/$m.md" >"$work.m"; printf '%s %s ' "$m" "$(peal frontmatter get "$work.m" state)"; done | sed 's/ $//')"

  before=$(main_sha)
  out=$(printf '%s' '{"proposals": [{"id": "a", "kind": "milestone_state", "milestone": "m1", "state": "reopen"},
    {"id": "b", "kind": "milestone_state", "milestone": "m2", "state": "unpark"}]}' | peal apply 2>/dev/null)
  check "ms states: reopen, and a current one unparked" '0:{"id": "a", "done": true, "outcome": "milestone m1: open", "milestone": "m1"}
{"id": "b", "done": true, "outcome": "milestone m2: current already", "milestone": "m2"}' "$?:$out"
  check "ms states: reopened" "open" "$(on_main "$work" docs/milestones/m1.md >"$work.m"; peal frontmatter get "$work.m" state)"
  check "ms states: one commit" "$before" "$(git -C "$work" rev-parse origin/main~1)"
}

# ms_review -> a milestone whose only task not done is its review task closes.
ms_review() {
  local out
  setup_tasks
  put "$work" backlog 0005 review-of-m2 "milestone: m2" "depends: [milestone]"
  out=$(printf '%s' '{"proposals": [{"id": "a", "kind": "milestone_state", "milestone": "m2", "state": "close"}]}' | peal apply 2>/dev/null)
  check "ms review: its review task aside" '0:{"id": "a", "done": true, "outcome": "milestone m2: done", "milestone": "m2"}' "$?:$out"
}

# ms_padded -> zero-padded milestone ids give a zero-padded new one.
ms_padded() {
  local out
  work=$(repo)
  git -C "$work" rm -q docs/milestones/m0.md docs/milestones/m1.md docs/milestones/m2.md docs/milestones/m3.md
  mkdir -p "$work/docs/milestones"
  milestone_file "$work" m01 current 1
  milestone_file "$work" m02 open 2
  publish "$work"
  out=$(printf '%s' '{"proposals": [{"id": "a", "kind": "milestone_create", "title": "Third"},
    {"id": "b", "kind": "milestone_create", "title": "Fourth", "order": 1}]}' | peal apply 2>/dev/null)
  check "ms padded" '0:{"id": "a", "done": true, "outcome": "created milestone m03 (docs/milestones/m03.md)", "milestone": "m03"}
{"id": "b", "done": true, "outcome": "created milestone m04 (docs/milestones/m04.md)", "milestone": "m04"}' "$?:$out"
  check "ms padded: orders" "3 1" "$(for m in m03 m04; do on_main "$work" "docs/milestones/$m.md" >"$work.m"; printf '%s ' "$(peal frontmatter get "$work.m" order)"; done | sed 's/ $//')"
}

# invalid NAME JSON INDEX PATTERN -> the batch JSON is refused: exit 2, main unchanged,
# proposal INDEX (from 1) invalid with a detail matching PATTERN, every other valid one
# not_applied.
invalid() {
  local name=$1 json=$2 index=$3 pattern=$4 before out st line n=0 bad=""
  before=$(main_sha)
  out=$(printf '%s' "$json" | peal apply 2>/dev/null)
  st=$?
  while IFS= read -r line; do
    n=$((n + 1))
    if [ "$n" = "$index" ]; then
      [[ "$line" == *'"done": false, "outcome": '*"$pattern"* ]] || bad="$bad line $n: $line;"
    else
      [[ "$line" == *'"done": false, "outcome": '* ]] || bad="$bad line $n: $line;"
    fi
  done <<<"$out"
  check "invalid: $name" "2:$before:" "$st:$(main_sha):$bad"
}

invalids() {
  local ok='{"id": "ok", "kind": "priority", "task": "0002", "priority": "low"}'
  setup_tasks
  git -C "$work" push -q origin "origin/main:refs/heads/task/0004-fourth-task" 2>/dev/null
  git -C "$work" fetch -q origin
  put "$work" backlog 0005 fifth-task "milestone: m3"
  invalid "unknown milestone" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": \"m9\"}]}" 2 "milestone m9 does not exist"
  invalid "parked milestone" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": \"m3\"}, $ok]}" 1 "milestone m3 is parked"
  invalid "claimed task" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"priority\", \"task\": \"0004\", \"priority\": \"low\"}]}" 2 "task 0004 is claimed"
  invalid "no such task" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"priority\", \"task\": \"0042\", \"priority\": \"low\"}]}" 2 "no task 0042"
  invalid "a cycle only the batch closes" "{\"proposals\": [$ok,
    {\"id\": \"b\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"0002\"},
    {\"id\": \"c\", \"kind\": \"depends\", \"task\": \"0002\", \"on\": \"0001\"}]}" 2 "depends cycle"
  invalid "a retire still named" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"retire\", \"task\": \"0002\", \"reason\": \"gone\"},
    {\"id\": \"c\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"0002\"}]}" 2 "task 0002 is still named by tasks/backlog/0001-first-task.md (depends)"
  invalid "a file setting merge" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"file\", \"title\": \"Merge it now\", \"text\": \"---\\nmerge: auto\\n---\\n\\n# NNNN — T\\n\\n## Raw\\n\\nx\\n\"}]}" 2 "the text sets merge"
  invalid "a file without Raw" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"file\", \"title\": \"No raw here\", \"text\": \"# NNNN — T\\n\"}, $ok]}" 1 "no '## Raw' section"
  invalid "a file of one-word title" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"file\", \"title\": \"Crate\", \"text\": \"x\"}, $ok]}" 1 "a slug of 1 word"
  invalid "an add with a heading" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"add\", \"task\": \"0001\", \"text\": \"a\\n## Outcome\\nb\"}]}" 2 "'---' or '## ' line"
  invalid "unknown kind" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"rename\"}]}" 2 'unknown kind \"rename\"'
  invalid "fold" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"fold\", \"task\": \"0001\"}]}" 2 "not a backlog change; Belfry carries it out"
  invalid "dismiss" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"dismiss\"}, $ok]}" 1 "not a backlog change"
  invalid "an unknown field" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": null, \"size\": \"S\"}]}" 2 "field size is not one move takes"
  invalid "depends remove as a string" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"0002\", \"remove\": \"yes\"}]}" 2 "remove is not true or false"
  invalid "depends with the old op" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"0002\", \"op\": \"add\"}]}" 2 "field op is not one depends takes"
  invalid "split with the old from" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"from\": \"m1\", \"tasks\": [\"0001\"]}]}" 2 "field from is not one split_milestone takes"
  invalid "a bad origin on a priority" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"priority\", \"task\": \"0001\", \"priority\": \"low\", \"origin\": \"x\"}]}" 2 "origin must be outsider or writer"
  invalid "a move with an empty milestone" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": \"\"}]}" 2 "is no milestone id"
  invalid "a nested value" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": [\"0001\"]}]}" 2 "field task is an array"
  invalid "a dangling @ref" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"@p9\"}]}" 2 "on @p9 names no file proposal"
  invalid "a later @ref as task" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"priority\", \"task\": \"@c\", \"priority\": \"low\"},
    {\"id\": \"c\", \"kind\": \"file\", \"title\": \"Later one here\", \"text\": \"---\\n---\\n\\n# NNNN — T\\n\\n## Raw\\n\\nx\\n\"}]}" 1 "names no earlier file proposal"
  invalid "a retire with both" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"retire\", \"task\": \"0001\", \"reason\": \"x\", \"duplicate\": \"0002\"}]}" 2 "a reason or a duplicate, not both"
  invalid "a bad priority" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"priority\", \"task\": \"0001\", \"priority\": \"soon\"}]}" 2 "priority soon is not"
  invalid "a duplicate id" "{\"proposals\": [$ok, {\"id\": \"ok\", \"kind\": \"priority\", \"task\": \"0001\", \"priority\": \"low\"}]}" 2 "the id of proposal 1 as well"
  invalid "a lone surrogate" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"add\", \"task\": \"0001\", \"text\": \"\\ud800\"}]}" 2 "a lone surrogate"
  ms_invalids
  split_invalids
  invalid "malformed JSON" '{"proposals": [{"id": "a", "kind": "move"' 1 "no JSON document"
  invalid "not JSON at all" 'proposals' 1 "no JSON document"
}

# ms_invalids -> each kind of invalid milestone proposal, the batch changing nothing.
ms_invalids() {
  local ok='{"id": "ok", "kind": "priority", "task": "0002", "priority": "low"}' mk='{"id": "mk", "kind": "milestone_create", "title": "New one"}'
  invalid "ms: unknown milestone" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_update\", \"milestone\": \"m9\", \"order\": 1}]}" 2 "milestone m9 does not exist"
  invalid "ms: a dangling @" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": \"@zz\"}]}" 2 "milestone @zz names no earlier milestone_create or split_milestone proposal"
  invalid "ms: a later @" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_state\", \"milestone\": \"@mk\", \"state\": \"park\"}, $mk]}" 2 "names no earlier milestone_create"
  invalid "ms: an @ to a file proposal" "{\"proposals\": [{\"id\": \"f\", \"kind\": \"file\", \"title\": \"Filed one here\", \"text\": \"---\\n---\\n\\n# NNNN — T\\n\\n## Raw\\n\\nx\\n\"},
    {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": \"@f\"}]}" 2 "names no earlier milestone_create"
  invalid "ms: a bad due" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_create\", \"title\": \"x\", \"due\": \"2026-02-30\"}]}" 2 "due 2026-02-30 is not a date"
  invalid "ms: a due null on create" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_create\", \"title\": \"x\", \"due\": null}]}" 2 "due is not a date"
  invalid "ms: a fraction order" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_update\", \"milestone\": \"m2\", \"order\": 1.5}]}" 2 "order 1.5 is not an integer"
  invalid "ms: a string order" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_create\", \"title\": \"x\", \"order\": \"3\"}]}" 2 "order is not an integer"
  invalid "ms: a reason without park" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_state\", \"milestone\": \"m3\", \"state\": \"unpark\", \"reason\": \"x\"}]}" 2 "a reason is for park"
  invalid "ms: an unknown state" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_state\", \"milestone\": \"m3\", \"state\": \"parked\"}]}" 2 "state must be park, unpark, close or reopen"
  invalid "ms: a multi-line title" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_create\", \"title\": \"a\\nb\"}]}" 2 "the title is one line"
  invalid "ms: a title with a tab" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_update\", \"milestone\": \"m2\", \"title\": \"a\\tb\"}]}" 2 "the title is one line"
  invalid "ms: a multi-line reason" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_state\", \"milestone\": \"m2\", \"state\": \"park\", \"reason\": \"a\\nb\"}]}" 2 "the reason is one line"
  invalid "ms: a goal with a heading" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_create\", \"title\": \"x\", \"goal\": \"a\\n## Outcome\\nb\"}]}" 2 "the goal holds a '---' or '## ' line"
  invalid "ms: an empty update" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_update\", \"milestone\": \"m2\"}]}" 2 "nothing to update"
  invalid "ms: a move into a milestone the batch parks" "{\"proposals\": [{\"id\": \"a\", \"kind\": \"milestone_state\", \"milestone\": \"m2\", \"state\": \"park\"},
    {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": \"m2\"}]}" 2 "milestone m2 is parked"
  invalid "ms: a move into a milestone the batch closes" "{\"proposals\": [{\"id\": \"a\", \"kind\": \"milestone_state\", \"milestone\": \"m2\", \"state\": \"close\"},
    {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": \"m2\"}]}" 2 "milestone m2 is done"
  invalid "ms: a filing into a new milestone the batch parks" "{\"proposals\": [$mk, {\"id\": \"a\", \"kind\": \"milestone_state\", \"milestone\": \"@mk\", \"state\": \"park\"},
    {\"id\": \"f\", \"kind\": \"file\", \"title\": \"Filed one here\", \"milestone\": \"@mk\", \"text\": \"---\\n---\\n\\n# NNNN — T\\n\\n## Raw\\n\\nx\\n\"}]}" 3 "is parked"
  invalid "ms: a move out of a parked milestone" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0005\", \"milestone\": null}]}" 2 "milestone m3 is parked"
  invalid "ms: a close with a task not done" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_state\", \"milestone\": \"m1\", \"state\": \"close\"}]}" 2 "milestone m1 still has tasks not done: 0001"
}

# split_invalids -> each kind of invalid split_milestone, the batch changing nothing.
split_invalids() {
  local ok='{"id": "ok", "kind": "priority", "task": "0002", "priority": "low"}' pre='{"id": "s", "kind": "split_milestone", "title": "Half", "milestone": "m1"'
  put "$work" backlog 0006 sixth-task "milestone: m1"
  publish "$work"
  git -C "$work" fetch -q origin
  invalid "split: a claimed task" "{\"proposals\": [$ok, $pre, \"tasks\": [\"0004\"]}]}" 2 "task 0004 is claimed"
  invalid "split: an unknown from" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"milestone\": \"m9\", \"tasks\": [\"0001\"]}]}" 2 "milestone m9 does not exist"
  invalid "split: no from" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"tasks\": [\"0001\"]}]}" 2 "no milestone"
  invalid "split: no title" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"milestone\": \"m1\", \"tasks\": [\"0001\"]}]}" 2 "no title"
  invalid "split: no tasks" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"milestone\": \"m1\", \"title\": \"Half\"}]}" 2 "no tasks"
  invalid "split: an empty array" "{\"proposals\": [$ok, $pre, \"tasks\": []}]}" 2 "tasks is empty"
  invalid "split: an empty item" "{\"proposals\": [$ok, $pre, \"tasks\": [\"0001\", \"\"]}]}" 2 "tasks item 2 () is no task id"
  invalid "split: a number item" "{\"proposals\": [$ok, $pre, \"tasks\": [1]}]}" 2 "field tasks holds an item that is not a string"
  invalid "split: a null item" "{\"proposals\": [$ok, $pre, \"tasks\": [null]}]}" 2 "field tasks holds an item that is not a string"
  invalid "split: an object item" "{\"proposals\": [$ok, $pre, \"tasks\": [{\"a\": [1]}]}]}" 2 "field tasks holds an item that is not a string"
  invalid "split: a nested array item" "{\"proposals\": [$ok, $pre, \"tasks\": [[\"0001\"]]}]}" 2 "field tasks holds an item that is not a string"
  invalid "split: a duplicate item" "{\"proposals\": [$ok, $pre, \"tasks\": [\"0001\", \"0001\"]}]}" 2 "tasks names 0001 twice"
  invalid "split: a non-NNNN item" "{\"proposals\": [$ok, $pre, \"tasks\": [\"0001; ls\"]}]}" 2 "is no task id (NNNN)"
  invalid "split: an @ to no file proposal" "{\"proposals\": [$ok, $pre, \"tasks\": [\"@zz\"]}]}" 2 "names no earlier file proposal"
  invalid "split: tasks as a string" "{\"proposals\": [$ok, $pre, \"tasks\": \"0001\"}]}" 2 "tasks is not an array of strings"
  invalid "split: tasks null" "{\"proposals\": [$ok, $pre, \"tasks\": null}]}" 2 "no tasks"
  invalid "split: tasks on a move" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": null, \"tasks\": [\"0001\"]}]}" 2 "field tasks is not one move takes"
  invalid "split: an array on the title" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"milestone\": \"m1\", \"tasks\": [\"0001\"], \"title\": [\"x\"]}]}" 2 "field title is an array"
  invalid "split: an array on from" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"tasks\": [\"0001\"], \"milestone\": [\"m1\"]}]}" 2 "field milestone is an array"
  invalid "split: a lone surrogate item" "{\"proposals\": [$ok, $pre, \"tasks\": [\"\\ud800\"]}]}" 2 "a lone surrogate"
  invalid "split: from parked at the start" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"milestone\": \"m3\", \"tasks\": [\"0005\"]}]}" 2 "milestone m3 is parked"
  invalid "split: a retired task" "{\"proposals\": [$ok, {\"id\": \"r\", \"kind\": \"retire\", \"task\": \"0006\", \"reason\": \"gone\"}, $pre, \"tasks\": [\"0006\"]}]}" 3 "task 0006 is retired"
  invalid "split: a later @ as from" "{\"proposals\": [{\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"milestone\": \"@t\", \"tasks\": [\"0001\"]},
    {\"id\": \"t\", \"kind\": \"milestone_create\", \"title\": \"T\"}, $ok]}" 1 "names no earlier milestone_create or split_milestone"
}

# ms_split -> split_milestone proposals in a batch: one commit, the milestones and the tasks moved.
ms_split() {
  local before out st t r=""
  setup_tasks
  put "$work" backlog 0005 fifth-task "milestone: m1"
  publish "$work"
  git -C "$work" fetch -q origin
  before=$(main_sha)
  out=$(printf '%s' '{"proposals": [
    {"id": "s", "kind": "split_milestone", "milestone": "m1", "tasks": ["0001", "0005"], "title": "Second half", "goal": "The rest.", "why": "too big"},
    {"id": "m", "kind": "move", "task": "0002", "milestone": "@s"},
    {"id": "f", "kind": "file", "title": "Filed in the half", "milestone": "@s", "text": "---\n---\n\n# NNNN — T\n\n## Raw\n\nx\n"},
    {"id": "t", "kind": "split_milestone", "milestone": "@s", "tasks": ["@f", "0002"], "title": "Third part"},
    {"id": "p", "kind": "priority", "task": "0001", "priority": "low"}]}' | peal apply 2>"$work.err")
  st=$?
  check "split: status" "0" "$st"
  check "split: the answer" '{"id": "s", "done": true, "outcome": "created milestone m4 (docs/milestones/m4.md); moved 0001, 0005", "milestone": "m4"}
{"id": "m", "done": true, "outcome": "task 0002: milestone m4", "task": "0002"}
{"id": "f", "done": true, "outcome": "filed tasks/backlog/0006-filed-in-the-half.md", "task": "0006"}
{"id": "t", "done": true, "outcome": "created milestone m5 (docs/milestones/m5.md); moved 0006, 0002", "milestone": "m5"}
{"id": "p", "done": true, "outcome": "task 0001: priority low", "task": "0001"}' "$out"
  check "split: one commit" "$before" "$(git -C "$work" rev-parse origin/main~1)"
  check "split: the subject" "docs(tasks): apply 5 proposals" "$(git -C "$work" log -1 --format=%s origin/main)"
  check "split: the files changed" "A	docs/milestones/m4.md
A	docs/milestones/m5.md
M	tasks/backlog/0001-first-task.md
M	tasks/backlog/0002-second-task.md
M	tasks/backlog/0005-fifth-task.md
A	tasks/backlog/0006-filed-in-the-half.md" "$(git -C "$work" diff --name-status origin/main~1 origin/main)"
  check "split: the new milestone, init's text, order from's + 1" "---
state: open
order: 2
---

# Second half

## Goal

The rest.

## Acceptance criteria

- A checkable statement the milestone review walks through." "$(on_main "$work" docs/milestones/m4.md)"
  check "split: the second one's order, from the first's" "3" "$(on_main "$work" docs/milestones/m5.md | sed -n 's/^order: //p')"
  for t in 0001-first-task 0002-second-task 0005-fifth-task 0006-filed-in-the-half; do
    on_main "$work" "tasks/backlog/$t.md" >"$work.t"
    r="$r ${t%%-*}=$(peal frontmatter get "$work.t" milestone)"
  done
  check "split: the tasks' milestones" " 0001=m4 0002=m5 0005=m4 0006=m5" "$r"
  check "split: peal check passes" "0" "$(git -C "$work" pull -q origin main 2>/dev/null; peal check >/dev/null 2>&1; echo $?)"
  # A given order and due are used as is.
  printf '%s' '{"proposals": [{"id": "s", "kind": "split_milestone", "milestone": "m4", "tasks": ["0005"], "title": "Ordered", "order": 40, "due": "2027-05-05"}]}' | peal apply >/dev/null 2>&1
  on_main "$work" docs/milestones/m6.md >"$work.m6"
  check "split: a given order and due" "40 2027-05-05" "$(peal frontmatter get "$work.m6" order) $(peal frontmatter get "$work.m6" due)"
}

# ms_pr -> task and milestone proposals through one pull request on a main that refuses
# pushes, against the fake gh.
ms_pr() {
  local out st before
  unset PEAL_MAIN_WRITE_WAIT PEAL_MAIN_WRITE_BUDGET PEAL_PUSH_ATTEMPTS
  setup_tasks
  fake_github "$work"
  ln -s "$(dirname "$work")/remote.git" "$FAKE_GH/remote"
  mkdir -p "$work/.peal"
  printf '%s\n' "main-writes: pr" "storage:" "  issues:" "    repo: acme/widgets" >"$work/.peal/config.yml"
  before=$(main_sha)
  out=$(ms_batch | PEAL_MAIN_WRITE_INTERVAL=0 peal apply 2>"$work.err")
  st=$?
  check "ms pr: status" "0" "$st"
  check "ms pr: every line names the pull request" "5" "$(printf '%s\n' "$out" | grep -c '"change": "https://github.com/acme/widgets/pull/')"
  check "ms pr: one pull request opened" "1" "$(grep -c '^POST .*pulls$' "$FAKE_GH/log")"
  check "ms pr: its title" "docs(tasks): apply 5 proposals" "$(jq -r '.[0].title' "$FAKE_GH/pulls.json")"
  check "ms pr: main unchanged until it merges" "$before" "$(main_sha)"
}

# pr -> the mixed batch through a pull request on a main that refuses pushes, against the
# fake gh: one pull request, the apply subject, the whys in its body. Then a rival's
# main-write branch holding the next number: the filing skips it.
pr() {
  local out st rival
  unset PEAL_MAIN_WRITE_WAIT PEAL_MAIN_WRITE_BUDGET PEAL_PUSH_ATTEMPTS
  setup_tasks
  fake_github "$work"
  ln -s "$(dirname "$work")/remote.git" "$FAKE_GH/remote"
  mkdir -p "$work/.peal"
  printf '%s\n' "main-writes: pr" "storage:" "  issues:" "    repo: acme/widgets" >"$work/.peal/config.yml"

  # A rival: an open pull request from a main-write branch filing 0005.
  rival=$(git -C "$work" rev-parse origin/main)
  git -C "$work" worktree add -q "$work.rival" "$rival" 2>/dev/null
  ID=0005 text >"$work.rival/tasks/backlog/0005-rival-filing.md"
  git -C "$work.rival" add -A && git -C "$work.rival" commit -q -m "docs(tasks): file 0005 rival-filing [0005]"
  git -C "$work.rival" push -q origin "HEAD:refs/heads/peal/main-write-rival" 2>/dev/null
  gh_save pulls '. + [{number: 50, node_id: "PR_50", title: "docs(tasks): file 0005 rival-filing [0005]", body: "", state: "open",
      draft: false, merged: false, mergeable: true, author_association: "OWNER", html_url: "https://github.com/acme/widgets/pull/50",
      head: {ref: "peal/main-write-rival", sha: "x", repo: {full_name: "acme/widgets"}}, base: {ref: "main", repo: {full_name: "acme/widgets"}}}]'

  out=$(batch | PEAL_MAIN_WRITE_INTERVAL=0 peal apply 2>"$work.err")
  st=$?
  check "pr: status" "0" "$st"
  check "pr: the filings skip the rival's number" '{"id": "p1", "done": true, "outcome": "filed tasks/backlog/0006-model-the-crate-for-level.md", "task": "0006", "change": "https://github.com/acme/widgets/pull/51"}' \
    "$(printf '%s\n' "$out" | head -n 1)"
  check "pr: every line names the pull request" "10" "$(printf '%s\n' "$out" | grep -c '"change": "https://github.com/acme/widgets/pull/51"')"
  check "pr: one pull request opened" "1" "$(grep -c '^POST .*pulls$' "$FAKE_GH/log")"
  check "pr: its title" "docs(tasks): apply 10 proposals" "$(jq -r '.[] | select(.number == 51) | .title' "$FAKE_GH/pulls.json")"
  check "pr: the whys in its body" "- p1 (file 0006): triage found it" \
    "$(jq -r '.[] | select(.number == 51) | .body' "$FAKE_GH/pulls.json" | grep '^- p1 ')"

  # An invalid batch opens no pull request.
  invalid "pr: an invalid batch" '{"proposals": [{"id": "a", "kind": "move", "task": "0001", "milestone": "m9"}]}' 1 "milestone m9 does not exist"
  check "pr: no pull request for an invalid batch" "1" "$(grep -c '^POST .*pulls$' "$FAKE_GH/log")"
}

# defused -> a why holding closing keywords and @mentions reaches the commit's body inert:
# a zero-width joiner after each '#' and '@', and in an issue's URL.
defused() {
  local zwj=$'\xe2\x80\x8d' body
  setup_tasks
  printf '%s' '{"proposals": [{"id": "@x", "kind": "priority", "task": "0001", "priority": "low",
    "why": "Fixes #12, closes owner/repo#3, resolves https://github.com/o/r/issues/4 and pull/5; cc @someone"}]}' \
    | peal apply >/dev/null 2>&1
  body=$(git -C "$work" log -1 --format=%b origin/main)
  check "defused: the why" "- @${zwj}x (priority 0001): Fixes #${zwj}12, closes owner/repo#${zwj}3, resolves https://github.com/o/r/issues/${zwj}4 and pull/${zwj}5; cc @${zwj}someone" \
    "$(printf '%s\n' "$body" | grep '^- ')"
}

# reader -> the JSON reader's escapes: a text stored byte for byte, never run.
reader() {
  local out
  setup_tasks
  # shellcheck disable=SC2016 # literal $(...) and backticks, stored as they are
  out=$(printf '%s' '{"proposals": [{"id": "x\"\u0001", "kind": "add", "task": "0001", "text": "$(touch pwned) `touch pwned2` \\ \/ \t tab\nnext line \ud83d\ude00"}]}' | peal apply 2>&1)
  check "reader: done, the id echoed" '{"id": "x\"\u0001", "done": true, "outcome": "noted on 0001", "task": "0001"}' "$out"
  # shellcheck disable=SC2016
  check "reader: stored byte for byte" "$today: \$(touch pwned) \`touch pwned2\` \\ / "$'\t'" tab
next line 😀" "$(on_main "$work" tasks/backlog/0001-first-task.md | grep -A1 "^$today")"
  check "reader: nothing run" "" "$(find "$work" -maxdepth 1 -name 'pwned*')"
}

# decoder -> a string of over 1 MiB, its escapes straddling the reader's windows,
# decoded byte for byte (and in time linear in its length: this case took minutes when
# each character was appended on its own).
decoder() {
  local dir enc dec unit_enc unit_dec n
  dir=$(scratch_dir)
  unit_enc="$(printf 'abcdefghij%.0s' 1 2 3 4 5 6 7 8 9)"'\n\t\\\"\/é😀'
  unit_dec="$(printf 'abcdefghij%.0s' 1 2 3 4 5 6 7 8 9)"$'\n\t\\"/\xc3\xa9\xf0\x9f\x98\x80'
  enc=$unit_enc dec=$unit_dec n=1
  while [ ${#enc} -lt 1048576 ]; do enc=$enc$enc dec=$dec$dec n=$((n * 2)); done
  printf '{"proposals": [{"id": "x", "text": "%s"}]}' "$enc" | LC_ALL=C awk -v dir="$dir" -v arrays=tasks \
    -f "$PEAL_ROOT/lib/apply.awk" >"$dir/manifest"
  check "decoder: a 1 MiB string read" "1	id	s
1	text	s
count	1" "$(cat "$dir/manifest")"
  printf '%s' "$dec" >"$dir/expected"
  check "decoder: $n escaped runs, byte for byte" "same" "$(cmp -s "$dir/expected" "$dir/1.text" && echo same)"
}

# trailing -> an id and a why ending in 20,000 escaped newlines: the answer's id without
# them (as $(...) strips them), the commit's body with each made a space; in time linear
# in their length (stripping one newline at a time took minutes here).
trailing() {
  local nl sp out
  setup_tasks
  nl=$(printf '\\n%.0s' $(seq 20000))
  sp=$(printf ' %.0s' $(seq 20000))
  out=$(printf '{"proposals": [{"id": "x%s", "kind": "priority", "task": "0001", "priority": "low", "why": "y%s"}]}' \
    "$nl" "$nl" | peal apply 2>&1)
  check "trailing: the newlines at the end of an id stripped" \
    '{"id": "x", "done": true, "outcome": "task 0001: priority low", "task": "0001"}' "$out"
  main_sha >/dev/null
  check "trailing: the id and why in the body, newlines made spaces" "- x$sp (priority 0001): y$sp" \
    "$(git -C "$work" log -1 --format=%b origin/main | grep '^- ')"
}

# belfry_batch -> a batch as Belfry's ApplyBatch marshals it (internal/api/apply.go): each
# proposal's keys in ApplyProposal's order (id, kind, ref, the fields, why, origin), empty
# values left out.
belfry_batch() {
  cat <<'EOF'
{"proposals": [
  {"id": "1", "kind": "milestone_create", "ref": "tides", "title": "Tides", "goal": "Water rises", "due": "2026-11-01", "why": "a new theme", "origin": "writer"},
  {"id": "2", "kind": "split_milestone", "title": "Half", "milestone": "m1", "tasks": ["0001"], "origin": "writer"},
  {"id": "3", "kind": "file", "ref": "crate", "title": "Crate model", "text": "---\n---\n\n# NNNN — Crate\n\n## Raw\n\nsaid\n", "milestone": "m2", "priority": "high", "why": "from outside", "origin": "outsider"},
  {"id": "4", "kind": "move", "task": "0002", "why": "no milestone for it", "origin": "writer"},
  {"id": "5", "kind": "move", "task": "0003", "milestone": "m2", "origin": "outsider"},
  {"id": "6", "kind": "priority", "task": "0001", "priority": "low", "origin": "writer"},
  {"id": "7", "kind": "depends", "task": "0003", "on": "0001", "origin": "writer"},
  {"id": "8", "kind": "depends", "task": "0003", "on": "0004", "remove": true, "origin": "writer"},
  {"id": "9", "kind": "retire", "task": "0004", "reason": "stale", "origin": "writer"},
  {"id": "10", "kind": "milestone_update", "title": "Second", "milestone": "m2", "due": "2026-12-01", "origin": "writer"},
  {"id": "11", "kind": "milestone_state", "ref": "open-m3", "milestone": "m3", "state": "unpark", "origin": "writer"},
  {"id": "12", "kind": "priority", "item": "idea:7", "ref": "p", "into": "idea:8", "task": "0002", "priority": "urgent", "origin": "writer"}
]}
EOF
}

# belfry_shapes -> that batch carried out, the answer as Belfry's ApplyResult reads it.
belfry_shapes() {
  local before out st n r=""
  setup_tasks
  put "$work" backlog 0002 second-task "milestone: m2
priority: high"
  publish "$work"
  git -C "$work" fetch -q origin
  before=$(main_sha)
  out=$(belfry_batch | peal apply 2>"$work.err")
  st=$?
  check "belfry: status" "0" "$st"
  check "belfry: the answer" '{"id": "1", "done": true, "outcome": "created milestone m4 (docs/milestones/m4.md)", "milestone": "m4"}
{"id": "2", "done": true, "outcome": "created milestone m5 (docs/milestones/m5.md); moved 0001", "milestone": "m5"}
{"id": "3", "done": true, "outcome": "filed tasks/backlog/0005-crate-model.md", "task": "0005"}
{"id": "4", "done": true, "outcome": "task 0002: milestone none", "task": "0002"}
{"id": "5", "done": true, "outcome": "task 0003: milestone m2", "task": "0003"}
{"id": "6", "done": true, "outcome": "task 0001: priority low", "task": "0001"}
{"id": "7", "done": true, "outcome": "task 0003: waits for 0001", "task": "0003"}
{"id": "8", "done": true, "outcome": "task 0003: no longer waits for 0004", "task": "0003"}
{"id": "9", "done": true, "outcome": "retired tasks/done/0004-fourth-task.md", "task": "0004"}
{"id": "10", "done": true, "outcome": "milestone m2: title, due 2026-12-01", "milestone": "m2"}
{"id": "11", "done": true, "outcome": "milestone m3: open", "milestone": "m3"}
{"id": "12", "done": true, "outcome": "task 0002: priority urgent", "task": "0002"}' "$out"
  check "belfry: one commit" "$before" "$(git -C "$work" rev-parse origin/main~1)"
  for n in 0001-first-task 0002-second-task 0003-third-task 0005-crate-model; do
    r="$r
$n: $(on_main "$work" "tasks/backlog/$n.md" | sed -n '2,/^---$/p' | tr '\n' ' ' | sed 's/ $//')"
  done
  check "belfry: the frontmatter" "
0001-first-task: milestone: m5 priority: low ---
0002-second-task: priority: urgent ---
0003-third-task: depends: [0001] milestone: m2 ---
0005-crate-model: milestone: m2 priority: high origin: outsider ---" "$r"
  check "belfry: retired" "tasks/done/0004-fourth-task.md" "$(git -C "$work" ls-tree -r --name-only origin/main tasks/done | grep 0004)"
  git -C "$work" pull -q origin main 2>/dev/null
  check "belfry: peal check passes" "0" "$(peal check >/dev/null 2>&1; echo $?)"
}

# belfry_invalid -> an invalid batch of that shape: every line not done with an outcome.
belfry_invalid() {
  local before out st
  setup_tasks
  before=$(main_sha)
  out=$(printf '%s' '{"proposals": [
  {"id": "1", "kind": "priority", "ref": "a", "task": "0001", "priority": "low", "origin": "writer"},
  {"id": "2", "kind": "move", "task": "0002", "milestone": "m9", "origin": "outsider"}]}' | peal apply 2>/dev/null)
  st=$?
  check "belfry invalid: the answer" '{"id": "1", "done": false, "outcome": "valid, but another proposal is not; nothing was written"}
{"id": "2", "done": false, "outcome": "task 0002: milestone m9 does not exist"}' "$out"
  check "belfry invalid: exit and main" "2:$before" "$st:$(main_sha)"
}

issues() {
  issues_repo
  check_refused "issues storage refuses" "the issues storage takes no batch" peal apply < <(printf '{"proposals": []}')
}

cases() {
  mixed
  ms_mixed
  ms_split
  ms_states
  ms_review
  ms_padded
  belfry_shapes
  belfry_invalid
  vouch
  invalids
  defused
  reader
  decoder
  trailing
  if command -v jq >/dev/null; then
    pr
    ms_pr
    issues
  elif [ -n "${PEAL_REQUIRE_JQ-}" ]; then
    check "jq, which the fake gh needs" "jq" ""
  fi
}

for_each_awk cases
finish
