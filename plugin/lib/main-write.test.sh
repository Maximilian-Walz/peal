#!/usr/bin/env bash
# Harness for the writes onto a main branch that refuses direct pushes (lib/main-write.sh),
# against throwaway repositories whose bare remote's pre-receive refuses main, as a
# ruleset or branch protection does, and the fake gh (lib/fake-gh) as their GitHub:
#
#   bash plugin/lib/main-write.test.sh
#
# A filing through a pull request, main-writes: push failing as before, a merge waiting
# for checks, two filings racing for a number (Peal's, a hand's, a split's, one landing
# while the checks run, a fork's that is no rival), and an edit whose pull request
# conflicts.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

if ! command -v jq >/dev/null; then
  echo "main-write.test.sh: no jq here, which the fake gh needs; skipped" >&2
  [ -z "${PEAL_REQUIRE_JQ-}" ] || exit 1
  exit 0
fi
unset PEAL_MAIN_WRITE_WAIT PEAL_MAIN_WRITE_BUDGET PEAL_MAIN_WRITE_INTERVAL PEAL_PUSH_ATTEMPTS

peal() { at "$work" "$PEAL" "$@"; }
remote() { git -C "$(dirname "$work")/remote.git" "$@"; }
pulls() { jq -r "$1" "$FAKE_GH/pulls.json"; }
line() { printf 'filed %s tasks/backlog/%s-%s.md — milestone: -, plan: -, size: - — "Title of %s"' "$1" "$1" "$2" "$1"; }

# protected [CONFIG-LINE...] -> work, a new repository whose remote refuses pushes to main
# (but with ALLOW_MAIN set, for a rival), with task 0001 in the backlog, a fake GitHub
# acme/widgets merging into that remote, and those lines in its .peal/config.yml.
protected() {
  work=$(repo)
  fake_github "$work"
  ln -s "$(dirname "$work")/remote.git" "$FAKE_GH/remote"
  mkdir -p "$work/.peal"
  printf '%s\n' "storage:" "  issues:" "    repo: acme/widgets" "$@" >"$work/.peal/config.yml"
  put "$work" backlog 0001 existing-task
  cat >"$(dirname "$work")/remote.git/hooks/pre-receive" <<'EOF'
#!/bin/sh
[ -n "${ALLOW_MAIN-}" ] && exit 0
while read -r old new ref; do
  if [ "$ref" = refs/heads/main ]; then
    echo "GH013: Repository rule violations found for refs/heads/main: changes must be made through a pull request" >&2
    exit 1
  fi
done
exit 0
EOF
  chmod +x "$(dirname "$work")/remote.git/hooks/pre-receive"
}

through_pr() {
  local out st head branch main
  protected
  head=$(git -C "$work" rev-parse HEAD)
  main=$(remote rev-parse main)

  out=$(text | peal create first-task 2>&1)
  st=$?
  check "pr: filed" "0:peal: origin refuses direct pushes to main; through a pull request instead (main-writes: auto)
peal: opened pull request #1 https://github.com/acme/widgets/pull/1
$(line 0002 first-task)
pull request #1 https://github.com/acme/widgets/pull/1, merging once its checks pass; the number is final once it merges" "$st:$out"
  branch=$(pulls '.[0].head.ref')
  check "pr: the branch" "peal/main-write-$(remote rev-parse --short "$branch")" "$branch"
  check "pr: exactly the new file" "A	tasks/backlog/0002-first-task.md" "$(remote diff-tree -r --name-status main "$branch")"
  check "pr: title" "docs(tasks): file 0002 first-task [0002]" "$(pulls '.[0].title')"
  check "pr: body" "1" "$(pulls '.[0].body' | grep -c "^Made by \`peal create\` for task 0002\\. Peal merges it")"
  check "pr: base" "main" "$(pulls '.[0].base.ref')"
  check "pr: auto-merge asked" "squash" "$(pulls '.[0].auto_merge.merge_method')"
  check "pr: remembered" "pr" "$(git -C "$work" config peal.mainWrites)"
  check "pr: main as it was" "$main" "$(remote rev-parse main)"
  check "pr: the worktree untouched" "$head:" "$(git -C "$work" rev-parse HEAD):$(git -C "$work" status --porcelain)"

  # Remembered: no direct push first; the number counts the open pull request's.
  out=$(text | peal create second-task 2>&1)
  st=$?
  check "pr: second" "0:peal: opened pull request #2 https://github.com/acme/widgets/pull/2
$(line 0003 second-task)
pull request #2 https://github.com/acme/widgets/pull/2, merging once its checks pass; the number is final once it merges" "$st:$out"

  # An edit returns once auto-merge is on.
  out=$(peal set-milestone 0001 m2 2>&1)
  st=$?
  check "pr: an edit" "0:peal: opened pull request #3 https://github.com/acme/widgets/pull/3
task 0001: milestone m2
pull request #3 https://github.com/acme/widgets/pull/3, merging once its checks pass" "$st:$out"
  check "pr: an edit's body" "Made by \`peal set-milestone\` for task 0001. Peal merges it once the required checks pass (GitHub's auto-merge, or Peal itself); nothing to review by hand." "$(pulls '.[2].body')"

  # A read before the merge finds nothing, and says why that may be.
  check_refused "pr: a read before the merge" "no task 0002
peal: writes onto main go through pull requests here: one from a peal/main-write-* branch may not have merged yet" peal read 0002

  # PEAL_MAIN_WRITE_WAIT=merged waits for the merge, here in vain.
  out=$(text | PEAL_MAIN_WRITE_WAIT=merged PEAL_MAIN_WRITE_INTERVAL=1 PEAL_MAIN_WRITE_BUDGET=0 peal create waited-task 2>&1)
  st=$?
  check "pr: waited for, still open" "3|pull request #4 https://github.com/acme/widgets/pull/4, open, not merged; the number is final once it merges" \
    "$st|$(printf '%s\n' "$out" | tail -n 1)"

  # A split's pieces go the same way, part-of and all.
  out=$(text "part-of: ORIGIN" | peal create --part-of 0001 a-piece 2>&1)
  st=$?
  check "pr: a split" "0:peal: opened pull request #5 https://github.com/acme/widgets/pull/5
$(line 0005 a-piece)
pull request #5 https://github.com/acme/widgets/pull/5, merging once its checks pass; the number is final once it merges" "$st:$out"
  check "pr: a split's body" "1" "$(pulls '.[4].body' | grep -c "^Made by \`peal create --part-of\` for task 0001\\.")"
  check "pr: a split's part-of" "part-of: 0001" \
    "$(git -C "$work" show "origin/$(pulls '.[4].head.ref'):tasks/backlog/0005-a-piece.md" | grep '^part-of')"

  # Forgotten: auto pushes first again.
  git -C "$work" config --unset peal.mainWrites
  out=$(text | peal create third-task 2>&1)
  st=$?
  check "pr: forgotten" "1" "$(grep -c 'refuses direct pushes' <<<"$out")"
}

push_only() {
  local out st
  protected "main-writes: push"
  out=$(text | peal create refused-task 2>&1)
  st=$?
  check "push: status 1" "1" "$(text | peal create refused-task >/dev/null 2>&1; echo $?)"
  check "push: said so" "1" "$(grep -c 'failed, and not from a race' <<<"$out")"
  check "push: git's reason" "1" "$(grep -c 'GH013' <<<"$out")"
  check "push: no pull request" "[]" "$(jq -c . "$FAKE_GH/pulls.json")"
  check "push: nothing remembered" "" "$(git -C "$work" config peal.mainWrites)"
}

merge_self() {
  local out st main
  protected "main-writes: pr"
  touch "$FAKE_GH/no-auto-merge"
  echo 2 >"$FAKE_GH/checks-pending"
  main=$(remote rev-parse main)

  out=$(text | PEAL_MAIN_WRITE_INTERVAL=0 peal create merged-task 2>&1)
  st=$?
  check "merge: filed" "0:peal: opened pull request #1 https://github.com/acme/widgets/pull/1
peal: auto-merge is not on for #1 (GraphQL: Auto merge is not allowed for this repository (enablePullRequestAutoMerge)); Peal merges it once its checks pass
$(line 0002 merged-task)
pull request #1 https://github.com/acme/widgets/pull/1, merged" "$st:$out"
  check "merge: one squash commit" "$main docs(tasks): file 0002 merged-task [0002] (#1)" "$(remote log -1 --format='%P %s' main)"
  check "merge: the file" "$(ID=0002 text)" "$(on_main "$work" tasks/backlog/0002-merged-task.md)"
  check "merge: waited for the checks" "3" "$(grep -c '^GET repos/acme/widgets/commits/.*/check-runs' "$FAKE_GH/log")"
  check "merge: the branch deleted" "" "$(remote for-each-ref refs/heads/peal/)"
  check "merge: merged" "closed true" "$(pulls '.[0] | "\(.state) \(.merged)"')"

  # A failing check leaves it open.
  echo 0 >"$FAKE_GH/checks-pending"
  touch "$FAKE_GH/checks-fail"
  out=$(text | PEAL_MAIN_WRITE_INTERVAL=0 peal create failing-task 2>&1)
  st=$?
  check "merge: a failing check" "1|peal: #2's checks fail: it stays open, unmerged, https://github.com/acme/widgets/pull/2
peal: nothing was filed" "$st|$(printf '%s\n' "$out" | tail -n 2)"
  check "merge: left open" "open" "$(pulls '.[1].state')"

  # The budget spent: open, status 3, the filing reported.
  rm "$FAKE_GH/checks-fail"
  echo 100 >"$FAKE_GH/checks-pending"
  out=$(text | PEAL_MAIN_WRITE_INTERVAL=1 PEAL_MAIN_WRITE_BUDGET=0 peal create slow-task 2>&1)
  st=$?
  check "merge: the budget spent" "3|peal: #3 is not merged after 0s (WAIT:checks-pending): it stays open, https://github.com/acme/widgets/pull/3
$(line 0004 slow-task)
pull request #3 https://github.com/acme/widgets/pull/3, open, not merged; the number is final once it merges" \
    "$st|$(printf '%s\n' "$out" | tail -n 3)"
}

race() {
  local out st rival
  protected "main-writes: pr"
  rival=$(dirname "$work")/rival
  git clone -q "$(dirname "$work")/remote.git" "$rival" 2>/dev/null

  # Between this filing's build and its pull request, a rival files 0002 through a pull
  # request of its own, numbered lower: this one is closed and filed again as 0003.
  cat >"$work/.git/hooks/pre-push" <<EOF
#!/bin/sh
[ -e "$rival.raced" ] && exit 0
touch "$rival.raced"
cd "$rival" && git checkout -q -b peal/main-write-rival origin/main && mkdir -p tasks/backlog \
  && echo rival >tasks/backlog/0002-rival-task.md && git add -A && git commit -q -m rival \
  && git push -q origin HEAD:refs/heads/peal/main-write-rival 2>/dev/null \
  && echo '{"title": "rival", "head": "peal/main-write-rival", "base": "main", "body": ""}' \
    | gh api --method POST repos/acme/widgets/pulls --input - >/dev/null
EOF
  chmod +x "$work/.git/hooks/pre-push"
  out=$(text | peal create my-task 2>&1)
  st=$?
  check "race: renumbered" "0:peal: opened pull request #2 https://github.com/acme/widgets/pull/2
peal: #2's number is taken meanwhile, on main or by an earlier pull request; closed, and built again
peal: opened pull request #3 https://github.com/acme/widgets/pull/3 (replaces #2)
$(line 0003 my-task)
pull request #3 https://github.com/acme/widgets/pull/3, merging once its checks pass; the number is final once it merges" "$st:$out"
  check "race: states" "1 open rival
2 closed docs(tasks): file 0002 my-task [0002]
3 open docs(tasks): file 0003 my-task [0003]" "$(pulls '.[] | "\(.number) \(.state) \(.title)"')"
  check "race: replaces" "1" "$(pulls '.[2].body' | grep -c '^Replaces #2\.$')"
  check "race: the closed branch gone" "refs/heads/$(pulls '.[2].head.ref')
refs/heads/peal/main-write-rival" "$(remote for-each-ref --format='%(refname)' refs/heads/peal/)"
  check "race: the replacement" "A	tasks/backlog/0003-my-task.md" "$(remote diff-tree -r --name-status main "$(pulls '.[2].head.ref')")"
}

# rival_hook BRANCH FILE... -> a pre-push hook in work that, once, has a rival clone push
# BRANCH (from main) adding each tasks/backlog/FILE and open a pull request from it.
rival_hook() {
  local branch=$1 rival
  shift
  rival=$(dirname "$work")/rival
  git clone -q "$(dirname "$work")/remote.git" "$rival" 2>/dev/null
  {
    printf '#!/bin/sh\n[ -e "%s.raced" ] && exit 0\ntouch "%s.raced"\n' "$rival" "$rival"
    printf 'cd "%s" && git checkout -q -b %s origin/main && mkdir -p tasks/backlog' "$rival" "$branch"
    printf ' && echo rival >tasks/backlog/%s' "$@"
    printf ' && git add -A && git commit -q -m rival && git push -q origin HEAD:refs/heads/%s 2>/dev/null' "$branch"
    printf ' && echo '"'"'{"title": "rival", "head": "%s", "base": "main", "body": ""}'"'"' | gh api --method POST repos/acme/widgets/pulls --input - >/dev/null\n' "$branch"
  } >"$work/.git/hooks/pre-push"
  chmod +x "$work/.git/hooks/pre-push"
}

# texts TEXT... -> the texts joined by the separator lines.
texts() {
  local first=1 t
  for t in "$@"; do
    [ $first = 1 ] || echo -----NEXT TASK-----
    printf '%s\n' "$t"
    first=0
  done
}

hand_race() {
  local out st
  protected "main-writes: pr"
  # A hand filing's pull request, not Peal's, takes 0002 first: this filing ends as 0003
  # in one replacement, well within two attempts.
  rival_hook chore/file-0002 0002-rival-task.md
  out=$(text | PEAL_PUSH_ATTEMPTS=2 peal create my-task 2>&1)
  st=$?
  check "hand race: renumbered" "0:peal: opened pull request #2 https://github.com/acme/widgets/pull/2
peal: #2's number is taken meanwhile, on main or by an earlier pull request; closed, and built again
peal: opened pull request #3 https://github.com/acme/widgets/pull/3 (replaces #2)
$(line 0003 my-task)
pull request #3 https://github.com/acme/widgets/pull/3, merging once its checks pass; the number is final once it merges" "$st:$out"
  check "hand race: states" "1 open rival
2 closed docs(tasks): file 0002 my-task [0002]
3 open docs(tasks): file 0003 my-task [0003]" "$(pulls '.[] | "\(.number) \(.state) \(.title)"')"
  check "hand race: replaces" "1" "$(pulls '.[2].body' | grep -c '^Replaces #2\.$')"
  check "hand race: the replacement" "A	tasks/backlog/0003-my-task.md" "$(remote diff-tree -r --name-status main "$(pulls '.[2].head.ref')")"

  # The next filing counts the hand pull request's number before its first build.
  out=$(text | peal create next-task 2>&1)
  st=$?
  check "hand race: the next one" "0:peal: opened pull request #4 https://github.com/acme/widgets/pull/4
$(line 0004 next-task)
pull request #4 https://github.com/acme/widgets/pull/4, merging once its checks pass; the number is final once it merges" "$st:$out"
}

split_race() {
  local out st head
  protected "main-writes: pr"
  # Two pieces, the second depending on the first: raced for 0002, both move up, and the
  # depends follows.
  rival_hook chore/file-0002 0002-rival-task.md
  out=$(texts "$(text "part-of: ORIGIN")" "$(TITLE=x text "part-of: ORIGIN" "depends: [PART1]")" \
    | peal create --part-of 0001 piece-one piece-two 2>&1)
  st=$?
  check "split race: status" "0" "$st"
  check "split race: filed" "filed 0003 tasks/backlog/0003-piece-one.md
filed 0004 tasks/backlog/0004-piece-two.md" "$(printf '%s\n' "$out" | grep '^filed' | cut -d' ' -f1-3)"
  head=$(pulls '.[2].head.ref')
  check "split race: the replacement" "A	tasks/backlog/0003-piece-one.md
A	tasks/backlog/0004-piece-two.md" "$(remote diff-tree -r --name-status main "$head")"
  check "split race: the depends" "part-of: 0001
depends: [0003]" "$(remote show "$head:tasks/backlog/0004-piece-two.md" | grep -E '^(depends|part-of):')"
  check "split race: the heading" "# 0004 — x" "$(remote show "$head:tasks/backlog/0004-piece-two.md" | grep '^# ')"
}

merge_race() {
  local out st rival
  protected "main-writes: pr"
  touch "$FAKE_GH/no-auto-merge"
  echo 2 >"$FAKE_GH/checks-pending"
  rival=$(dirname "$work")/rival
  git clone -q "$(dirname "$work")/remote.git" "$rival" 2>/dev/null
  # While Peal waits for the checks, 0002 lands on main: it closes before its merge and
  # files again as 0003.
  printf 'cd "%s" && mkdir -p tasks/backlog && echo rival >tasks/backlog/0002-rival-task.md && git add -A && git commit -q -m rival && ALLOW_MAIN=1 git push -q origin HEAD:main\n' \
    "$rival" >"$FAKE_GH/on-check-runs"
  out=$(text | PEAL_MAIN_WRITE_INTERVAL=0 peal create my-task 2>&1)
  st=$?
  check "merge race: renumbered" "0:peal: opened pull request #1 https://github.com/acme/widgets/pull/1
peal: auto-merge is not on for #1 (GraphQL: Auto merge is not allowed for this repository (enablePullRequestAutoMerge)); Peal merges it once its checks pass
peal: #1's number is taken meanwhile, on main or by an earlier pull request; closed, and built again
peal: opened pull request #2 https://github.com/acme/widgets/pull/2 (replaces #1)
peal: auto-merge is not on for #2 (GraphQL: Auto merge is not allowed for this repository (enablePullRequestAutoMerge)); Peal merges it once its checks pass
$(line 0003 my-task)
pull request #2 https://github.com/acme/widgets/pull/2, merged" "$st:$out"
  check "merge race: states" "1 closed false
2 closed true" "$(pulls '.[] | "\(.number) \(.state) \(.merged)"')"
  check "merge race: main" "tasks/backlog/0001-existing-task.md
tasks/backlog/0002-rival-task.md
tasks/backlog/0003-my-task.md" "$(remote ls-tree -r --name-only main tasks/)"
}

fork() {
  local out st rival
  protected "main-writes: pr"
  rival=$(dirname "$work")/rival
  git clone -q "$(dirname "$work")/remote.git" "$rival" 2>/dev/null
  # A fork's pull request holding 0002, numbered lower, is no rival: its branch is here
  # only so that counting it would show.
  (cd "$rival" && git checkout -q -b patch-1 && mkdir -p tasks/backlog && echo fork >tasks/backlog/0002-fork-task.md \
    && git add -A && git commit -q -m fork && git push -q origin HEAD:refs/heads/patch-1 2>/dev/null)
  jq '. + [{number: 1, node_id: "PR_1", title: "fork", body: "", state: "open", draft: false, merged: false,
      mergeable: true, author_association: "CONTRIBUTOR", html_url: "https://github.com/acme/widgets/pull/1",
      head: {ref: "patch-1", repo: {full_name: "someone/widgets"}}, base: {ref: "main", repo: {full_name: "acme/widgets"}}}]' \
    "$FAKE_GH/pulls.json" >"$FAKE_GH/pulls.new" && mv "$FAKE_GH/pulls.new" "$FAKE_GH/pulls.json"
  out=$(text | peal create my-task 2>&1)
  st=$?
  check "fork: not a rival" "0:peal: opened pull request #2 https://github.com/acme/widgets/pull/2
$(line 0002 my-task)
pull request #2 https://github.com/acme/widgets/pull/2, merging once its checks pass; the number is final once it merges" "$st:$out"
}

conflict() {
  local out st rival
  protected "main-writes: pr"
  touch "$FAKE_GH/unmergeable"
  rival=$(dirname "$work")/rival
  git clone -q "$(dirname "$work")/remote.git" "$rival" 2>/dev/null

  # While the revision is on its way, 0001 changes on main: the pull request conflicts,
  # and the revision, built again, is refused as today.
  cat >"$work/.git/hooks/pre-push" <<EOF
#!/bin/sh
[ -e "$rival.raced" ] && exit 0
touch "$rival.raced"
cd "$rival" && echo changed >>tasks/backlog/0001-existing-task.md && git commit -q -am changed \
  && ALLOW_MAIN=1 git push -q origin HEAD:main 2>/dev/null
EOF
  chmod +x "$work/.git/hooks/pre-push"
  out=$(ID=0001 TITLE="A better title" text | peal revise 0001 --reason "a better title" 2>&1)
  st=$?
  check "conflict: refused" "2:peal: opened pull request #1 https://github.com/acme/widgets/pull/1
peal: #1 conflicts with main; closed, and built again on the new main
peal: tasks/backlog/0001-existing-task.md changed on origin/main meanwhile; read it again and run again" "$st:$out"
  check "conflict: closed" "closed" "$(pulls '.[0].state')"
  check "conflict: the branch gone" "" "$(remote for-each-ref refs/heads/peal/)"
}

cases() {
  through_pr
  push_only
  merge_self
  race
  hand_race
  split_race
  merge_race
  fork
  conflict
}

for_each_awk cases
finish
