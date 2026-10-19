#!/usr/bin/env bash
# Harness for peal apply (lib/apply.sh, lib/apply.awk), against throwaway repositories
# with a bare remote:
#
#   bash plugin/lib/apply.test.sh
#
# A batch of mixed proposals as one commit, by push and through a pull request (the fake
# gh, which needs jq); filed numbers skipping a rival's; each kind of invalid batch
# changing nothing; the JSON reader's escapes; the issues storage refusing.
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
  invalid "a milestone kind" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"milestone_create\", \"title\": \"x\"}]}" 2 "not yet"
  invalid "an unknown field" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": \"0001\", \"milestone\": null, \"size\": \"S\"}]}" 2 "field size is not one move takes"
  invalid "a nested value" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"move\", \"task\": [\"0001\"]}]}" 2 "field task is an array"
  invalid "a dangling @ref" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"depends\", \"task\": \"0001\", \"on\": \"@p9\", \"op\": \"add\"}]}" 2 "on @p9 names no file proposal"
  invalid "a later @ref as task" "{\"proposals\": [{\"id\": \"b\", \"kind\": \"priority\", \"task\": \"@c\", \"priority\": \"low\"},
    {\"id\": \"c\", \"kind\": \"file\", \"title\": \"Later one here\", \"text\": \"---\\n---\\n\\n# NNNN — T\\n\\n## Raw\\n\\nx\\n\"}]}" 1 "names no earlier file proposal"
  invalid "a retire with both" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"retire\", \"task\": \"0001\", \"reason\": \"x\", \"duplicate\": \"0002\"}]}" 2 "a reason or a duplicate, not both"
  invalid "a bad priority" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"priority\", \"task\": \"0001\", \"priority\": \"soon\"}]}" 2 "priority soon is not"
  invalid "a duplicate id" "{\"proposals\": [$ok, {\"id\": \"ok\", \"kind\": \"priority\", \"task\": \"0001\", \"priority\": \"low\"}]}" 2 "the id of proposal 1 as well"
  invalid "a lone surrogate" "{\"proposals\": [$ok, {\"id\": \"b\", \"kind\": \"add\", \"task\": \"0001\", \"text\": \"\\ud800\"}]}" 2 "a lone surrogate"
  invalid "malformed JSON" '{"proposals": [{"id": "a", "kind": "move"' 1 "no JSON document"
  invalid "not JSON at all" 'proposals' 1 "no JSON document"
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
  invalids
  defused
  reader
  if command -v jq >/dev/null; then
    pr
    issues
  elif [ -n "${PEAL_REQUIRE_JQ-}" ]; then
    check "jq, which the fake gh needs" "jq" ""
  fi
}

for_each_awk cases
finish
