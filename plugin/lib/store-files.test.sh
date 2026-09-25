#!/usr/bin/env bash
# Harness for the writes of the task-file storage (lib/store-files.sh, lib/task-check.awk,
# lib/task-text.sh, lib/ideas.sh), against throwaway repositories with a bare remote:
#
#   bash plugin/lib/store-files.test.sh
#
# Filing (single, --part-of, --batch), numbering by push-as-lock through a lost race, the
# idea queue, revise, retire, set-milestone, comment, read and finish, and each refusal,
# a depends cycle among them.
# Every write lands on the remote's main without touching the calling worktree.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }
subject() { git -C "$work" log -1 --format=%s origin/main; }
ids_on_main() { git -C "$work" fetch -q origin; git -C "$work" ls-tree -r --name-only origin/main tasks | sed -n 's|^tasks/[a-z]*/||p'; }

# texts TEXT... -> the texts joined by the separator lines.
texts() {
  local first=1 t
  for t in "$@"; do
    [ $first = 1 ] || echo -----NEXT TASK-----
    printf '%s\n' "$t"
    first=0
  done
}

create() {
  local work out head
  work=$(repo)
  head=$(git -C "$work" rev-parse HEAD)

  out=$(text "milestone: m1" "plan: required" "size: M" | peal create "The first one" 2>&1)
  check "create" "0:filed 0001 tasks/backlog/0001-the-first-one.md — milestone: m1, plan: required, size: M — \"Title of 0001\"" "$?:$out"
  check "create: the file" "$(ID=0001 text "milestone: m1" "plan: required" "size: M")" "$(on_main "$work" tasks/backlog/0001-the-first-one.md)"
  check "create: the subject" "docs(tasks): file 0001 the-first-one [0001]" "$(subject)"
  check "create: the worktree untouched" "$head:" "$(git -C "$work" rev-parse HEAD):$(git -C "$work" status --porcelain)"

  # The number: one past every task file and every task branch, local or remote.
  git -C "$work" branch -q task/0007-claimed-elsewhere
  text | peal create second-one >/dev/null 2>&1
  git -C "$work" push -q origin HEAD:refs/heads/task/0012-remote-claim 2>/dev/null
  git -C "$work" fetch -q origin
  text | peal create third-one >/dev/null 2>&1
  check "create: numbers" "0001-the-first-one.md
0008-second-one.md
0013-third-one.md" "$(ids_on_main)"

  # A split: ORIGIN and PART1..n substituted, one commit.
  out=$(texts "$(text "part-of: ORIGIN" "depends: [PART2]" "milestone: m3")" "$(text "part-of: ORIGIN" "depends: [ORIGIN]")" \
    | peal create --part-of 0001 piece-one piece-two 2>&1)
  check "split" "0:filed 0014 tasks/backlog/0014-piece-one.md — milestone: m3, plan: -, size: - — \"Title of 0014\"
filed 0015 tasks/backlog/0015-piece-two.md — milestone: -, plan: -, size: - — \"Title of 0015\"" "$?:$out"
  check "split: substituted" "$(ID=0014 text "part-of: 0001" "depends: [0015]" "milestone: m3")" \
    "$(on_main "$work" tasks/backlog/0014-piece-one.md)"
  check "split: subject" "docs(tasks): file 0014-0015, split of 0001 [0001]" "$(subject)"
  check "split: one commit" "1" "$(git -C "$work" rev-list --count origin/main~1..origin/main)"

  # A batch: ideas found in a task.
  out=$(texts "$(text)" "$(TITLE=Other text "milestone: m2")" | peal create --batch 0008 idea-one idea-two 2>&1)
  check "batch" "0:filed 0016 tasks/backlog/0016-idea-one.md — milestone: -, plan: -, size: - — \"Title of 0016\"
filed 0017 tasks/backlog/0017-idea-two.md — milestone: m2, plan: -, size: - — \"Other\"" "$?:$out"
  check "batch: subject" "docs(tasks): file 0016-0017, found in 0008 [0008]" "$(subject)"

  # The template files as it is.
  out=$(peal create from-the-template <"$PEAL_ROOT/templates/task.md" 2>&1)
  check "the template" "0:filed 0018 tasks/backlog/0018-from-the-template.md — milestone: -, plan: skipped, size: - — \"Title\"" "$?:$out"

  # The project's own fields: declared ones pass, with their values checked.
  mkdir -p "$work/.peal"
  printf 'task:\n  fields:\n    area: [engine, ui]\n    team:\n' >"$work/.peal/config.yml"
  out=$(text "area: ui" "team: sam" | peal create own-fields 2>&1)
  check "own fields" "0:filed 0019 tasks/backlog/0019-own-fields.md — milestone: -, plan: -, size: - — \"Title of 0019\"" "$?:$out"
  check_refused "own field, wrong value" "own-fields: area art is not one of engine,ui" \
    peal create own-fields < <(text "area: art")
}

refusals() {
  local work before
  work=$(repo)
  put "$work" backlog 0001 existing-task
  before=$(git -C "$work" rev-parse origin/main)

  check_refused "illegal frontmatter" "bad-one:3: expected , or ]" peal create bad-one < <(text "milestone: m1" "depends: [0001")
  check_refused "unknown field" "bad-one: unknown field team" peal create bad-one < <(text "team: me")
  check_refused "unknown depends id" "bad-one: depends: 0099 is no task" peal create bad-one < <(text "depends: [0099]")
  check_refused "depends: not an id" "bad-one: depends: soon is no task id, milestone or human" peal create bad-one < <(text "depends: [soon]")
  check_refused "depends: milestone without one" "bad-one: depends: milestone needs a milestone" peal create bad-one < <(text "depends: [milestone]")
  check_refused "unknown milestone" "bad-one: milestone m9 does not exist" peal create bad-one < <(text "milestone: m9")
  check_refused "done milestone" "bad-one: milestone m0 is done" peal create bad-one < <(text "milestone: m0")
  check_refused "parked milestone" "bad-one: milestone m3 is parked" peal create bad-one < <(text "milestone: m3")
  check_refused "milestone as a list" "bad-one: milestone takes a single value" peal create bad-one < <(text "milestone: [m1]")
  check_refused "plan" "bad-one: plan maybe is not required or skipped" peal create bad-one < <(text "plan: maybe")
  check_refused "size" "bad-one: size XL is not one of" peal create bad-one < <(text "size: XL")
  check_refused "priority" "bad-one: priority soon is not urgent, high, normal or low" peal create bad-one < <(text "priority: soon")
  check_refused "merge" "bad-one: merge always is not auto" peal create bad-one < <(text "merge: always")
  check_refused "merge: a single value" "bad-one: merge takes a single value" peal create bad-one < <(text "merge: [auto]")
  check_refused "priority as a list" "bad-one: priority takes a single value" peal create bad-one < <(text "priority: [high]")
  check_refused "touches: a comma" "bad-one: touches: src/{a,b}.c holds a comma" peal create bad-one < <(text "touches: ['src/{a,b}.c']")
  check_refused "touches: absolute" "bad-one: touches: /etc/hosts is absolute" peal create bad-one < <(text "touches: [/etc/hosts]")
  check_refused "touches: empty entry" "bad-one: touches: an empty entry" peal create bad-one < <(text "touches: ['']")
  check_refused "part-of outside a split" "bad-one: part-of is written by a split only" peal create bad-one < <(text "part-of: 0001")
  check_refused "PARTn outside a split" "bad-one: depends: PART1 is no task id" peal create bad-one < <(text "depends: [PART1]")
  check_refused "no NNNN heading" "bad-one: the first heading must be '# NNNN — Title'" peal create bad-one < <(ID=0005 text)
  check_refused "no Raw" "bad-one: no '## Raw' section" peal create bad-one < <(text | grep -v '^## Raw')
  check_refused "empty" "the text for bad-one is empty" peal create bad-one </dev/null
  check_refused "one-word slug" "slug 'bad' makes 1 words; a slug is 2 to 5" peal create bad < <(text)
  check_refused "six-word slug" "makes 6 words" peal create "a b c d e f" < <(text)
  check_refused "two slugs, one text" "2 slug(s) but 1 text(s)" peal create --batch 0001 one-idea two-idea < <(text)
  check_refused "the same text twice" "the texts for one-idea and two-idea are the same" \
    peal create --batch 0001 one-idea two-idea < <(texts "$(text)" "$(text)")
  check_refused "split: no part-of" "piece-one: a piece of a split needs part-of: ORIGIN" \
    peal create --part-of 0001 piece-one < <(text)
  check_refused "split: part-of not ORIGIN" "piece-one: part-of must be ORIGIN" \
    peal create --part-of 0001 piece-one < <(text "part-of: 0001")
  check_refused "split: PARTn itself" "piece-one: depends: PART1 is this piece itself" \
    peal create --part-of 0001 piece-one piece-two < <(texts "$(text "part-of: ORIGIN" "depends: [PART1]")" "$(TITLE=x text "part-of: ORIGIN")")
  check_refused "split: PARTn out of range" "piece-one: depends: PART3 is not one of the pieces PART1..PART2" \
    peal create --part-of 0001 piece-one piece-two < <(texts "$(text "part-of: ORIGIN" "depends: [PART3]")" "$(TITLE=x text "part-of: ORIGIN")")
  check_refused "split: no such origin" "task 0042 does not exist" \
    peal create --part-of 0042 piece-one < <(text "part-of: ORIGIN")
  check_refused "split: origin not an id" "'x1' is no task id" peal create --part-of x1 piece-one < <(text "part-of: ORIGIN")
  check_refused "create: two slugs plain" "usage: peal" peal create one-one two-two
  check "refusals: nothing pushed" "$before" "$(git -C "$work" fetch -q; git -C "$work" rev-parse origin/main)"

  # A split may file a piece into a parked milestone.
  check_fails "split: parked is fine" 0 "" peal create --part-of 0001 piece-one < <(text "part-of: ORIGIN" "milestone: m3")

  # An unknown storage.
  mkdir -p "$work/.peal"
  printf 'storage:\n  kind: tickets\n' >"$work/.peal/config.yml"
  check_refused "unknown storage" "storage 'tickets' is not one Peal has (files, issues)" peal list
}

race() {
  local work rival out
  work=$(repo)
  put "$work" backlog 0001 existing-task
  rival=$(dirname "$work")/rival
  git clone -q "$(dirname "$work")/remote.git" "$rival" 2>/dev/null

  # Between this clone's fetch and its push, the rival files 0002: the push is refused,
  # and the filing goes again as 0003.
  cat >"$work/.git/hooks/pre-push" <<EOF
#!/bin/sh
[ -e "$rival.raced" ] && exit 0
touch "$rival.raced"
cd "$rival" && mkdir -p tasks/backlog && echo rival >tasks/backlog/0002-rival-task.md \
  && git add -A && git commit -q -m rival && git push -q origin HEAD:main 2>/dev/null
EOF
  chmod +x "$work/.git/hooks/pre-push"
  out=$(text | peal create my-task 2>&1)
  check "race: renumbered" "0:peal: the push lost a race (1 of 5); again on the new main
filed 0003 tasks/backlog/0003-my-task.md — milestone: -, plan: -, size: - — \"Title of 0003\"" "$?:$out"
  check "race: both filed" "0001-existing-task.md
0002-rival-task.md
0003-my-task.md" "$(ids_on_main)"

  # Losing every race gives up.
  cat >"$work/.git/hooks/pre-push" <<EOF
#!/bin/sh
cd "$rival" && git pull -q --rebase origin main 2>/dev/null && git commit -q --allow-empty -m again && git push -q origin HEAD:main 2>/dev/null
EOF
  out=$(text | PEAL_PUSH_ATTEMPTS=2 peal create lost-task 2>&1)
  check "race: gives up" "1:peal: the push lost a race (1 of 2); again on the new main
peal: gave up after 2 pushes to origin/main, each losing a race
peal: nothing was filed" "$?:$out"

  # A push refused for another reason is not retried.
  rm "$work/.git/hooks/pre-push"
  printf '#!/bin/sh\necho "no pushes today" >&2\nexit 1\n' >"$(dirname "$work")/remote.git/hooks/pre-receive"
  chmod +x "$(dirname "$work")/remote.git/hooks/pre-receive"
  out=$(text | peal create refused-task 2>&1)
  check "push refused: status 1" "1" "$(text | peal create refused-task >/dev/null 2>&1; echo $?)"
  check "push refused: said so" "1" "$(grep -c 'failed, and not from a race' <<<"$out")"
  check "push refused: git's reason" "1" "$(grep -c 'no pushes today' <<<"$out")"
}

ideas() {
  local work out
  work=$(repo)
  put "$work" backlog 0001 working-task

  # On main: filed at once.
  out=$(text "milestone: m1" | peal idea "On main" 2>&1)
  check "idea on main: filed" "0:filed 0002 tasks/backlog/0002-on-main.md — milestone: m1, plan: -, size: - — \"Title of 0002\"" "$?:$out"

  # On a task branch: queued, nothing pushed.
  git -C "$work" worktree add -q -b task/0001-working-task "$work-1" origin/main 2>/dev/null
  scratch+=("$work-1")
  work=$work-1
  out=$(text "milestone: m2" "plan: skipped" | peal idea first-idea 2>&1)
  check "idea: queued" "0:queued first-idea — milestone: m2, plan: skipped, size: - — \"Title of NNNN\"" "$?:$out"
  out=$(TITLE='Second \ thought' text "depends: [0099]" | peal idea second-idea 2>&1)
  check "idea: queued offline, ids unchecked" "0:queued second-idea — milestone: -, plan: -, size: - — \"Second \\ thought\"" "$?:$out"
  check "idea: nothing pushed" "0001-working-task.md
0002-on-main.md" "$(ids_on_main)"
  check "idea: not in the work tree" "" "$(git -C "$work" status --porcelain)"
  check "ideas" "first-idea	Title of NNNN
second-idea	Second \\ thought" "$(peal ideas)"

  check_refused "idea: refused when queued" "bad-idea: unknown field team" peal idea bad-idea < <(text "team: me")
  check_refused "idea: a separator line" "would split the queue" peal idea bad-idea < <(text; echo -----NEXT TASK-----)
  check_refused "idea: a queue marker" "would split the queue" peal idea bad-idea < <(text; echo '-----IDEA x-----')
  check "idea: refusals leave the queue" "2" "$(peal ideas | wc -l | tr -d ' ')"

  # --now files at once from a task branch too.
  out=$(TITLE=Now text | peal idea now-idea --now 2>&1)
  check "idea --now" "0:filed 0003 tasks/backlog/0003-now-idea.md — milestone: -, plan: -, size: - — \"Now\"" "$?:$out"

  # The flush checks against main: the unknown id refuses, and the queue stays.
  check_refused "flush: checked again" "second-idea: depends: 0099 is no task" peal ideas --flush
  check "flush refused: the queue stays" "2" "$(peal ideas | wc -l | tr -d ' ')"

  # Fixed by hand, the flush files them all in one push and empties the queue.
  sed -i.bak 's/depends: \[0099\]/depends: [0001]/' "$(git -C "$work" rev-parse --git-dir)/peal-ideas"
  out=$(peal ideas --flush 2>&1)
  check "flush" "0:filed 0004 tasks/backlog/0004-first-idea.md — milestone: m2, plan: skipped, size: - — \"Title of 0004\"
filed 0005 tasks/backlog/0005-second-idea.md — milestone: -, plan: -, size: - — \"Second \\ thought\"" "$?:$out"
  check "flush: subject" "docs(tasks): file 0004-0005, found in 0001 [0001]" "$(subject)"
  check "flush: the queue is empty" "" "$(peal ideas)"
  check "flush: again, nothing" "no queued ideas" "$(peal ideas --flush)"
}

revise() {
  local work new out
  work=$(repo)
  put "$work" backlog 0001 revised-task "milestone: m1" "depends: []"
  put "$work" backlog 0002 other-task "part-of: 0001"
  put "$work" backlog 0003 parked-task "milestone: m3"
  OUTCOME="It was done." put "$work" backlog 0004 worked-task
  put "$work" "done" 0005 done-task
  put "$work" backlog 0006 claimed-task

  new=$(ID=0001 TITLE="A better title" text "milestone: m2" "depends: [0006]")
  out=$(peal revise 0001 --reason "narrowed" <<<"$new" 2>&1)
  check "revise" "0:revised 0001 tasks/backlog/0001-revised-task.md" "$?:$out"
  check "revise: the text" "$(printf '%s\n' "$new" | sed "s/^## Notes\$/## Notes\n\nRevised $today: narrowed/")" \
    "$(on_main "$work" tasks/backlog/0001-revised-task.md)"
  check "revise: subject" "docs(tasks): revise 0001 revised-task [0001]" "$(subject)"
  out=$(peal revise 0001 --reason "again" --dry-run < <(ID=0001 TITLE="A dry title" text "milestone: m2" "depends: [0006]") 2>&1)
  check "revise --dry-run: the change" "1" "$(grep -c '^+# 0001 — A dry title' <<<"$out")"
  check "revise --dry-run: nothing pushed" "docs(tasks): revise 0001 revised-task [0001]" "$(subject)"

  local cur
  cur=$(on_main "$work" tasks/backlog/0001-revised-task.md)
  check_refused "revise: no change" "the text is the same" peal revise 0001 --reason x <<<"$cur"
  check_refused "revise: Raw changed" "the Raw section changed" peal revise 0001 --reason x < <(ID=0001 RAW=other text "milestone: m2")
  check_refused "revise: Raw dropped" "the Raw section changed" peal revise 0001 --reason x < <(ID=0001 text "milestone: m2" | sed '/^## Raw/d')
  check_refused "revise: Outcome filled" "fills in the Outcome" peal revise 0001 --reason x < <(ID=0001 OUTCOME=Done. text "milestone: m2")
  check_refused "revise: Outcome dropped" "the Outcome heading was added or dropped" peal revise 0001 --reason x < <(ID=0001 text "milestone: m2" | sed '/^## Outcome/d')
  check_refused "revise: no Notes" "no '## Notes' section" peal revise 0001 --reason x < <(ID=0001 text "milestone: m2" | sed '/^## Notes/d')
  check_refused "revise: another number" "the first heading must be '# 0001 — Title'" peal revise 0001 --reason x < <(ID=0009 text)
  check_refused "revise: unknown field" "unknown field team" peal revise 0001 --reason x < <(ID=0001 text "team: me")
  check_refused "revise: unknown depends" "depends: 0099 is no task" peal revise 0001 --reason x < <(ID=0001 text "depends: [0099]")
  check_refused "revise: into a parked milestone" "milestone m3 is parked; only a milestone review moves a task there" \
    peal revise 0001 --reason x < <(ID=0001 text "milestone: m3")
  check_refused "revise: out of a parked milestone" "milestone m3 is parked; only a milestone review moves a task out" \
    peal revise 0003 --reason x < <(ID=0003 text "milestone: m1")
  check_refused "revise: part-of changed" "part-of changed" peal revise 0002 --reason x < <(ID=0002 text "part-of: 0003")
  check_refused "revise: Outcome filled before" "Outcome is filled in: work happened" peal revise 0004 --reason x < <(ID=0004 TITLE=y text)
  check_refused "revise: done" "task 0005 is done" peal revise 0005 --reason x < <(ID=0005 TITLE=y text)
  check_refused "revise: no task" "no task 0042" peal revise 0042 --reason x < <(ID=0042 text)
  check_refused "revise: no reason" "revise: ID --reason R" peal revise 0001 < <(ID=0001 text)
  git -C "$work" push -q origin origin/main:refs/heads/task/0006-claimed-task 2>/dev/null
  git -C "$work" fetch -q origin
  check_refused "revise: claimed" "task 0006 is claimed (origin/task/0006-claimed-task)" peal revise 0006 --reason x < <(ID=0006 TITLE=y text)

  # A revise is refused, not replayed, when main's copy changes under it.
  local rival
  rival=$(dirname "$work")/rival
  git clone -q "$(dirname "$work")/remote.git" "$rival" 2>/dev/null
  cat >"$work/.git/hooks/pre-push" <<EOF
#!/bin/sh
[ -e "$rival.raced" ] && exit 0
touch "$rival.raced"
cd "$rival" && echo more >>tasks/backlog/0001-revised-task.md && git commit -q -am rival && git push -q origin HEAD:main 2>/dev/null
EOF
  chmod +x "$work/.git/hooks/pre-push"
  check_refused "revise: changed meanwhile" "tasks/backlog/0001-revised-task.md changed on origin/main meanwhile" \
    peal revise 0001 --reason x < <(ID=0001 TITLE=z text "milestone: m2" "depends: [0006]")
}

retire() {
  local work out
  work=$(repo)
  put "$work" backlog 0001 retired-task
  put "$work" backlog 0002 needed-task
  put "$work" backlog 0003 needs-it "depends: [0002]"
  put "$work" backlog 0004 split-origin
  put "$work" backlog 0005 a-piece "part-of: 0004"
  put "$work" "done" 0006 done-dependent "depends: [0001]"
  OUTCOME="Half built." put "$work" backlog 0007 worked-task

  out=$(peal retire 0001 --reason "overtaken by 0002" 2>&1)
  check "retire" "0:retired 0001 tasks/done/0001-retired-task.md" "$?:$out"
  check "retire: the Outcome" "$(ID=0001 text | sed '/^## Outcome$/q'; echo; echo "Retired $today without being claimed: overtaken by 0002")" \
    "$(on_main "$work" tasks/done/0001-retired-task.md)"
  check "retire: gone from the backlog" "" "$(on_main "$work" tasks/backlog/0001-retired-task.md)"
  check "retire: subject" "docs(tasks): retire 0001 retired-task [0001]" "$(subject)"
  check "retire: done" "0001 done retired-task" "$(peal list --no-pr 0001 2>/dev/null)"

  check_refused "retire: depended upon" "tasks/backlog/0003-needs-it.md (depends)" peal retire 0002 --reason x
  check_refused "retire: a split origin" "tasks/backlog/0005-a-piece.md (part-of)" peal retire 0004 --reason x
  check_refused "retire: filled Outcome" "Outcome is filled in" peal retire 0007 --reason x
  check_refused "retire: already done" "task 0001 is done" peal retire 0001 --reason x
  check_refused "retire: no reason" "retire: ID --reason R" peal retire 0003
  git -C "$work" branch -q task/0003-needs-it
  check_refused "retire: claimed" "task 0003 is claimed (task/0003-needs-it)" peal retire 0003 --reason x

  # A file without an Outcome heading gets one.
  printf -- '---\n---\n\n# 0008 — Old shape\n\n## Raw\n\nwords\n' >"$work/tasks/backlog/0008-old-shape.md"
  publish "$work"
  peal retire 0008 --reason gone >/dev/null 2>&1
  check "retire: an Outcome added" "$(printf -- '---\n---\n\n# 0008 — Old shape\n\n## Raw\n\nwords\n\n## Outcome\n\nRetired %s without being claimed: gone' "$today")" \
    "$(on_main "$work" tasks/done/0008-old-shape.md)"
}

edits() {
  local work out
  work=$(repo)
  put "$work" backlog 0001 some-task "milestone: m1" "plan: skipped"
  put "$work" "done" 0002 done-task

  out=$(peal set-milestone 0001 m2 2>&1)
  check "set-milestone" "0:task 0001: milestone m2" "$?:$out"
  check "set-milestone: the file" "$(ID=0001 text "milestone: m2" "plan: skipped")" "$(on_main "$work" tasks/backlog/0001-some-task.md)"
  check "set-milestone: subject" "docs(tasks): set milestone of 0001 to m2 [0001]" "$(subject)"
  check_fails "set-milestone: parked is fine" 0 "" peal set-milestone 0001 m3
  out=$(peal set-milestone 0001 2>&1)
  check "set-milestone: none" "0:task 0001: milestone none" "$?:$out"
  check "set-milestone: removed" "$(ID=0001 text "plan: skipped")" "$(on_main "$work" tasks/backlog/0001-some-task.md)"
  check_refused "set-milestone: no change" "already reads so" peal set-milestone 0001
  check_refused "set-milestone: unknown" "milestone m9 does not exist" peal set-milestone 0001 m9
  check_refused "set-milestone: done milestone" "milestone m0 is done" peal set-milestone 0001 m0
  check_refused "set-milestone: done task" "task 0002 is done" peal set-milestone 0002 m1

  out=$(peal comment 0001 "worth a look" 2>&1)
  check "comment" "0:task 0001: noted" "$?:$out"
  check "comment: the line" "1" "$(on_main "$work" tasks/backlog/0001-some-task.md | grep -c "^$today: worth a look\$")"
  check "comment: subject" "docs(tasks): note on 0001 [0001]" "$(subject)"
  check_refused "comment: no text" "comment: no text" peal comment 0001 ""
  printf -- '---\n---\n\n# 0003 — No notes\n' >"$work/tasks/backlog/0003-no-notes.md"
  publish "$work"
  check_refused "comment: no Notes" "has no '## Notes' section" peal comment 0003 hi
}

read_finish() {
  local work wt out
  work=$(repo)
  put "$work" backlog 0001 read-task
  check "read: from main" "$(ID=0001 text)" "$(peal read 0001)"
  check_refused "read: no task" "no task 0042" peal read 0042

  # Claimed: the branch's copy, under doing/.
  wt=$work-1
  git -C "$work" worktree add -q -b task/0001-read-task "$wt" origin/main 2>/dev/null
  scratch+=("$wt")
  mkdir -p "$wt/tasks/doing"
  git -C "$wt" mv tasks/backlog/0001-read-task.md tasks/doing/
  git -C "$wt" commit -q -m claim
  check "read: from the branch" "$(ID=0001 text)" "$(peal read 0001)"

  # finish: from doing/ to done/, staged, only with an Outcome and only on the branch.
  check_refused "finish: not on the branch" "not on task 0001's branch" peal finish 0001
  work=$wt
  check_refused "finish: no Outcome" "has no Outcome yet" peal finish 0001
  printf 'Built it.\n<!-- note -->\n' >>"$wt/tasks/doing/0001-read-task.md"
  check_refused "finish: a placeholder left" "still holds a placeholder" peal finish 0001
  ID=0001 OUTCOME="Built it." text >"$wt/tasks/doing/0001-read-task.md"
  out=$(peal finish 0001 2>&1)
  check "finish" "0:finished 0001 tasks/done/0001-read-task.md" "$?:$out"
  check "finish: staged" "R  tasks/doing/0001-read-task.md -> tasks/done/0001-read-task.md" "$(git -C "$wt" status --porcelain)"
  check "finish: twice, left as it is" "finished 0001 already: tasks/done/0001-read-task.md|0" "$(peal finish 0001 2>&1)|$?"
}

# A text that would close a depends cycle is refused, naming it; nothing is pushed.
cycles() {
  local work before out
  work=$(repo)
  put "$work" backlog 0001 first-task "depends: [0002]"
  put "$work" backlog 0002 second-task
  put "$work" backlog 0003 third-task "depends: [0001]"
  put "$work" backlog 0004 review-task "milestone: m2" "depends: [milestone]"
  put "$work" backlog 0005 waits-for-split "depends: [0006]"
  put "$work" backlog 0006 split-task
  before=$(git -C "$work" rev-parse origin/main)

  check_fails "cycle: revise" 1 "revise: refused: depends cycle 0002 → 0001 → 0002" \
    peal revise 0002 --reason x < <(ID=0002 text "depends: [0001]")
  check_fails "cycle: revise, longer" 1 "revise: refused: depends cycle 0002 → 0003 → 0001 → 0002" \
    peal revise 0002 --reason x < <(ID=0002 text "depends: [0003]")
  check_fails "cycle: file, through a milestone" 1 "create: refused: depends cycle NNNN → 0004 → NNNN" \
    peal create late-review < <(text "milestone: m2" "depends: [milestone]")
  check_fails "cycle: split, a piece through its origin" 1 "create: refused: depends cycle PART2 → 0005 → PART2" \
    peal create --part-of 0006 piece-one piece-two < <(texts "$(text "part-of: ORIGIN")" "$(text "part-of: ORIGIN" "depends: [0005]")")
  check "cycle: nothing pushed" "$before" "$(git -C "$work" fetch -q origin; git -C "$work" rev-parse origin/main)"

  # What closes no cycle goes through: a piece waiting for its origin, a task waiting for
  # its own milestone alone, a revise of a task on a cycle made by hand that keeps it.
  out=$(texts "$(text "part-of: ORIGIN" "depends: [ORIGIN]")" | peal create --part-of 0006 piece-waits 2>&1)
  check "cycle: none, a piece waits for its origin" "0" "$?"
  out=$(text "milestone: m1" "depends: [milestone]" | peal create own-review 2>&1)
  check "cycle: none, its own milestone" "0" "$?"
  put "$work" backlog 0002 second-task "depends: [0001]"
  out=$(peal revise 0002 --reason "a title" < <(ID=0002 TITLE="New title" text "depends: [0001]") 2>&1)
  check "cycle: a revise keeping a cycle there already" "0:revised 0002 tasks/backlog/0002-second-task.md" "$?:$out"
}

cases() {
  create
  cycles
  refusals
  race
  ideas
  revise
  retire
  edits
  read_finish
}

for_each_awk cases
finish
