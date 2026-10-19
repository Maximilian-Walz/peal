#!/usr/bin/env bash
# Harness for peal apply (lib/apply.sh, lib/apply.awk), against throwaway repositories
# with a bare remote:
#
#   bash plugin/lib/apply.test.sh
#
# A batch of mixed proposals as one commit, by push and through a pull request (the fake
# gh, which needs jq); filed numbers skipping a rival's; the milestone kinds, mixed with
# task ones, their states and the next current milestone, a new milestone's id; each kind
# of invalid batch changing nothing; the JSON reader's escapes; the issues storage
# refusing.
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
  {"id": "p3", "kind": "depends", "task": "@p2", "on": "@p1", "op": "add", "why": "the crate first"},
  {"id": "p4", "kind": "add", "task": "0001", "text": "Seen in the field \u00e9", "origin": "outsider", "why": "a report"},
  {"id": "p5", "kind": "move", "task": "0001", "milestone": null, "why": "not this milestone"},
  {"id": "p6", "kind": "priority", "task": "0002", "priority": "normal"},
  {"id": "p7", "kind": "priority", "task": "0004", "priority": "urgent"},
  {"id": "p8", "kind": "depends", "task": "0003", "on": "0004", "op": "remove"},
  {"id": "p9", "kind": "depends", "task": "0003", "on": "0002", "op": "add"},
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
  check "mixed: the answer" '{"id": "p1", "status": "done", "task": "0005", "detail": "filed tasks/backlog/0005-model-the-crate-for-level.md"}
{"id": "p2", "status": "done", "task": "0006", "detail": "filed tasks/backlog/0006-ship-the-crate.md"}
{"id": "p3", "status": "done", "task": "0006", "detail": "task 0006: waits for 0005"}
{"id": "p4", "status": "done", "task": "0001", "detail": "noted on 0001"}
{"id": "p5", "status": "done", "task": "0001", "detail": "task 0001: milestone none"}
{"id": "p6", "status": "done", "task": "0002", "detail": "task 0002: priority normal"}
{"id": "p7", "status": "done", "task": "0004", "detail": "task 0004: priority urgent"}
{"id": "p8", "status": "done", "task": "0003", "detail": "task 0003: no longer waits for 0004"}
{"id": "p9", "status": "done", "task": "0003", "detail": "task 0003: waits for 0002"}
{"id": "p10", "status": "done", "task": "0004", "detail": "retired tasks/done/0004-fourth-task.md"}' "$out"
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
  check "a batch changing nothing" "0:{\"id\": \"a\", \"status\": \"done\", \"task\": \"0002\", \"detail\": \"task 0002: priority normal\"}:$before" "$?:$out:$(main_sha)"
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
  check "ms mixed: the answer" '{"id": "p1", "status": "done", "milestone": "m4", "detail": "created milestone m4 (docs/milestones/m4.md)"}
{"id": "p2", "status": "done", "task": "0005", "detail": "filed tasks/backlog/0005-model-the-crate.md"}
{"id": "p3", "status": "done", "task": "0001", "detail": "task 0001: milestone m4"}
{"id": "p4", "status": "done", "milestone": "m1", "detail": "milestone m1: title, no due, no order"}
{"id": "p5", "status": "done", "milestone": "m2", "detail": "milestone m2: parked"}' "$out"
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
  check "ms mixed: the next id" '{"id": "a", "status": "done", "milestone": "m8", "detail": "created milestone m8 (docs/milestones/m8.md)"}' "$out"
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
  check "ms states: the answer" '0:{"id": "a", "status": "done", "task": "0001", "detail": "task 0001: milestone none"}
{"id": "b", "status": "done", "milestone": "m1", "detail": "milestone m1: done"}
{"id": "c", "status": "done", "milestone": "m0", "detail": "milestone m0: done already"}
{"id": "d", "status": "done", "milestone": "m3", "detail": "milestone m3: open; milestone m2: current"}
{"id": "e", "status": "done", "task": "0005", "detail": "task 0005: milestone none"}' "$st:$out"
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
  check "ms states: reopen, and a current one unparked" '0:{"id": "a", "status": "done", "milestone": "m1", "detail": "milestone m1: open"}
{"id": "b", "status": "done", "milestone": "m2", "detail": "milestone m2: current already"}' "$?:$out"
  check "ms states: reopened" "open" "$(on_main "$work" docs/milestones/m1.md >"$work.m"; peal frontmatter get "$work.m" state)"
  check "ms states: one commit" "$before" "$(git -C "$work" rev-parse origin/main~1)"
}

# ms_review -> a milestone whose only task not done is its review task closes.
ms_review() {
  local out
  setup_tasks
  put "$work" backlog 0005 review-of-m2 "milestone: m2" "depends: [milestone]"
  out=$(printf '%s' '{"proposals": [{"id": "a", "kind": "milestone_state", "milestone": "m2", "state": "close"}]}' | peal apply 2>/dev/null)
  check "ms review: its review task aside" '0:{"id": "a", "status": "done", "milestone": "m2", "detail": "milestone m2: done"}' "$?:$out"
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
  check "ms padded" '0:{"id": "a", "status": "done", "milestone": "m03", "detail": "created milestone m03 (docs/milestones/m03.md)"}
{"id": "b", "status": "done", "milestone": "m04", "detail": "created milestone m04 (docs/milestones/m04.md)"}' "$?:$out"
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
      [[ "$line" == *'"status": "invalid"'*"$pattern"* ]] || bad="$bad line $n: $line;"
    else
      [[ "$line" == *'"status": "not_applied"'* || "$line" == *'"status": "invalid"'* ]] || bad="$bad line $n: $line;"
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
    {\"id\": \"b\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"0002\", \"op\": \"add\"},
    {\"id\": \"c\", \"kind\": \"depends\", \"task\": \"0002\", \"on\": \"0001\", \"op\": \"add\"}]}" 2 "depends cycle"
  invalid "a retire still named" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"retire\", \"task\": \"0002\", \"reason\": \"gone\"},
    {\"id\": \"c\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"0002\", \"op\": \"add\"}]}" 2 "task 0002 is still named by tasks/backlog/0001-first-task.md (depends)"
  invalid "a file setting merge" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"file\", \"title\": \"Merge it now\", \"text\": \"---\\nmerge: auto\\n---\\n\\n# NNNN — T\\n\\n## Raw\\n\\nx\\n\"}]}" 2 "the text sets merge"
  invalid "a file without Raw" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"file\", \"title\": \"No raw here\", \"text\": \"# NNNN — T\\n\"}, $ok]}" 1 "no '## Raw' section"
  invalid "a file of one-word title" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"file\", \"title\": \"Crate\", \"text\": \"x\"}, $ok]}" 1 "a slug of 1 word"
  invalid "an add with a heading" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"add\", \"task\": \"0001\", \"text\": \"a\\n## Outcome\\nb\"}]}" 2 "'---' or '## ' line"
  invalid "unknown kind" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"rename\"}]}" 2 'unknown kind \"rename\"'
  invalid "fold" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"fold\", \"task\": \"0001\"}]}" 2 "not a backlog change; Belfry carries it out"
  invalid "dismiss" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"dismiss\"}, $ok]}" 1 "not a backlog change"
  invalid "an unknown field" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": null, \"size\": \"S\"}]}" 2 "field size is not one move takes"
  invalid "a nested value" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": [\"0001\"]}]}" 2 "field task is an array"
  invalid "a dangling @ref" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"@p9\", \"op\": \"add\"}]}" 2 "on @p9 names no file proposal"
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
  local ok='{"id": "ok", "kind": "priority", "task": "0002", "priority": "low"}' pre='{"id": "s", "kind": "split_milestone", "title": "Half", "from": "m1"'
  put "$work" backlog 0006 sixth-task "milestone: m1"
  publish "$work"
  git -C "$work" fetch -q origin
  invalid "split: a task not in from" "{\"proposals\": [$ok, $pre, \"tasks\": [\"0006\", \"0002\"]}]}" 2 "task 0002 is not in milestone m1"
  invalid "split: a claimed task" "{\"proposals\": [$ok, $pre, \"tasks\": [\"0004\"]}]}" 2 "task 0004 is claimed"
  invalid "split: a task in no milestone" "{\"proposals\": [$ok, $pre, \"tasks\": [\"0003\"]}]}" 2 "task 0003 is not in milestone m1"
  invalid "split: an unknown from" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"from\": \"m9\", \"tasks\": [\"0001\"]}]}" 2 "milestone m9 does not exist"
  invalid "split: no from" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"tasks\": [\"0001\"]}]}" 2 "no from"
  invalid "split: no title" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"from\": \"m1\", \"tasks\": [\"0001\"]}]}" 2 "no title"
  invalid "split: no tasks" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"from\": \"m1\", \"title\": \"Half\"}]}" 2 "no tasks"
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
  invalid "split: an array on the title" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"from\": \"m1\", \"tasks\": [\"0001\"], \"title\": [\"x\"]}]}" 2 "field title is an array"
  invalid "split: an array on from" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"tasks\": [\"0001\"], \"from\": [\"m1\"]}]}" 2 "field from is an array"
  invalid "split: a lone surrogate item" "{\"proposals\": [$ok, $pre, \"tasks\": [\"\\ud800\"]}]}" 2 "a lone surrogate"
  invalid "split: from parked at the start" "{\"proposals\": [$ok, {\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"from\": \"m3\", \"tasks\": [\"0005\"]}]}" 2 "milestone m3 is parked"
  invalid "split: a retired task" "{\"proposals\": [$ok, {\"id\": \"r\", \"kind\": \"retire\", \"task\": \"0006\", \"reason\": \"gone\"}, $pre, \"tasks\": [\"0006\"]}]}" 3 "task 0006 is retired"
  invalid "split: a later @ as from" "{\"proposals\": [{\"id\": \"s\", \"kind\": \"split_milestone\", \"title\": \"Half\", \"from\": \"@t\", \"tasks\": [\"0001\"]},
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
    {"id": "s", "kind": "split_milestone", "from": "m1", "tasks": ["0001", "0005"], "title": "Second half", "goal": "The rest.", "why": "too big"},
    {"id": "m", "kind": "move", "task": "0002", "milestone": "@s"},
    {"id": "f", "kind": "file", "title": "Filed in the half", "milestone": "@s", "text": "---\n---\n\n# NNNN — T\n\n## Raw\n\nx\n"},
    {"id": "t", "kind": "split_milestone", "from": "@s", "tasks": ["@f", "0002"], "title": "Third part"},
    {"id": "p", "kind": "priority", "task": "0001", "priority": "low"}]}' | peal apply 2>"$work.err")
  st=$?
  check "split: status" "0" "$st"
  check "split: the answer" '{"id": "s", "status": "done", "milestone": "m4", "detail": "created milestone m4 (docs/milestones/m4.md); moved 0001, 0005"}
{"id": "m", "status": "done", "task": "0002", "detail": "task 0002: milestone m4"}
{"id": "f", "status": "done", "task": "0006", "detail": "filed tasks/backlog/0006-filed-in-the-half.md"}
{"id": "t", "status": "done", "milestone": "m5", "detail": "created milestone m5 (docs/milestones/m5.md); moved 0006, 0002"}
{"id": "p", "status": "done", "task": "0001", "detail": "task 0001: priority low"}' "$out"
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
  printf '%s' '{"proposals": [{"id": "s", "kind": "split_milestone", "from": "m4", "tasks": ["0005"], "title": "Ordered", "order": 40, "due": "2027-05-05"}]}' | peal apply >/dev/null 2>&1
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
  check "pr: the filings skip the rival's number" '{"id": "p1", "status": "done", "task": "0006", "detail": "filed tasks/backlog/0006-model-the-crate-for-level.md", "change": "https://github.com/acme/widgets/pull/51"}' \
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
  check "reader: done, the id echoed" '{"id": "x\"\u0001", "status": "done", "task": "0001", "detail": "noted on 0001"}' "$out"
  # shellcheck disable=SC2016
  check "reader: stored byte for byte" "$today: \$(touch pwned) \`touch pwned2\` \\ / "$'\t'" tab
next line 😀" "$(on_main "$work" tasks/backlog/0001-first-task.md | grep -A1 "^$today")"
  check "reader: nothing run" "" "$(find "$work" -maxdepth 1 -name 'pwned*')"
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
  invalids
  defused
  reader
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
