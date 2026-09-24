#!/usr/bin/env bash
# Harness for Peal's git gates (lib/githooks.sh, templates/githook), installed with
# `peal hooks install` into throwaway repositories with a bare remote:
#
#   bash plugin/lib/githooks.test.sh
#
# pre-push: every write the storage makes onto main passes, through the real commands;
# every other shape is refused. commit-msg: every subject form, the wip and task-file fast
# paths, checks.commit (run by path, failing a commit). Both chain to the project's own
# hook of the same name.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }

# fresh -> the work tree back on the remote's main, clean.
fresh() {
  git -C "$work" fetch -q origin
  git -C "$work" checkout -q main
  git -C "$work" reset -q --hard origin/main
  git -C "$work" clean -qfd
}

# commit_ungated SUBJECT -> what is staged in the work tree committed, the gate skipped.
commit_ungated() {
  git -C "$work" commit -q --no-verify --allow-empty -m "$1"
}

push_main() { git -C "$work" push -q origin HEAD:main; }

install() {
  local work out dir
  work=$(repo)
  out=$(peal hooks install)
  dir=$(cd "$work/.git" && pwd)/peal/hooks
  check "install: the message" "installed Peal's git hooks in $dir (core.hooksPath); they chain to the hooks in $(cd "$work/.git" && pwd)/hooks" "$out"
  check "install: core.hooksPath" "$dir" "$(git -C "$work" config core.hooksPath)"
  check "install: the root recorded" "$PEAL_ROOT" "$(cat "$work/.git/peal-root")"
  check "install: every stub" "$(printf '%s\n' "$PEAL_GITHOOKS_LIST" | sort)" "$(cd "$dir" && find . -type f | sed 's|^\./||' | sort)"
  check "install: no project hooks kept" "" "$(git -C "$work" config peal.projectHooks)"

  # Run again, it stays: the hooks path it replaced is not its own.
  git -C "$work" config core.hooksPath .githooks
  peal hooks install >/dev/null
  peal hooks install >/dev/null
  check "install over a hooks path: kept for the chain" ".githooks" "$(git -C "$work" config peal.projectHooks)"
  check "install over a hooks path: ours" "$dir" "$(git -C "$work" config core.hooksPath)"

  # From a linked worktree: the same git directory.
  git -C "$work" worktree add -q -b task/0001-linked "$work-linked" 2>/dev/null
  (cd "$work-linked" && "$PEAL" hooks install >/dev/null)
  check "install from a worktree: the shared directory" "$dir" "$(git -C "$work-linked" config core.hooksPath)"
}

pre_push() {
  local work
  work=$(repo)
  put "$work" backlog 0001 first-task "milestone: m1"
  put "$work" backlog 0002 second-task
  put "$work" backlog 0003 third-task
  peal hooks install >/dev/null
  fresh

  # The storage's own writes, each through the gate.
  check "allowed: file" "0" "$(text | peal create new-task >/dev/null 2>&1; echo $?)"
  check "allowed: file a split" "0" "$(printf '%s\n-----NEXT TASK-----\n%s\n' "$(text "part-of: ORIGIN")" "$(TITLE=Two text "part-of: ORIGIN")" \
    | peal create --part-of 0001 piece-one piece-two >/dev/null 2>&1; echo $?)"
  check "allowed: revise" "0" "$(ID=0002 RAW="the human said so" TITLE="Better" text | peal revise 0002 --reason "clearer" >/dev/null 2>&1; echo $?)"
  check "allowed: set-milestone" "0" "$(peal set-milestone 0002 m2 >/dev/null 2>&1; echo $?)"
  check "allowed: comment" "0" "$(peal comment 0002 "a note" >/dev/null 2>&1; echo $?)"
  check "allowed: retire" "0" "$(peal retire 0003 --reason "not needed" >/dev/null 2>&1; echo $?)"
  check "allowed: the subjects" "docs(tasks): retire 0003 third-task [0003]
docs(tasks): note on 0002 [0002]
docs(tasks): set milestone of 0002 to m2 [0002]
docs(tasks): revise 0002 second-task [0002]
docs(tasks): file 0005-0006, split of 0001 [0001]
docs(tasks): file 0004 new-task [0004]" "$(git -C "$work" log --format=%s -6 origin/main)"

  # A defer's shape: one backlog file modified.
  fresh
  printf '\nnotes back\n' >>"$work/tasks/backlog/0002-second-task.md"
  git -C "$work" add -A
  commit_ungated "docs(tasks): defer 0002 second-task [0002]"
  check "allowed: defer" "0" "$(push_main 2>/dev/null; echo $?)"

  # Anything else to main is refused.
  fresh
  echo x >"$work/README"
  git -C "$work" add -A
  commit_ungated "feat: a change [0001]"
  check_fails "refused: a plain commit" 1 "reaches main directly and is no merge" push_main
  check_fails "refused: says what does reach main" 1 "a merged pull request and Peal's own writes" push_main

  fresh
  commit_ungated "docs(tasks): file 0009 empty [0009]"
  check_fails "refused: file, empty" 1 "the diff is empty" push_main

  fresh
  printf 'x\n' >"$work/tasks/backlog/0009-sneaky-task.md"
  echo x >"$work/README"
  git -C "$work" add -A
  commit_ungated "docs(tasks): file 0009 sneaky-task [0009]"
  check_fails "refused: file, with more" 1 "not an added backlog task file: A 100644 README" push_main

  fresh
  printf 'more\n' >>"$work/tasks/backlog/0001-first-task.md"
  git -C "$work" add -A
  commit_ungated "docs(tasks): file 0001 first-task [0001]"
  check_fails "refused: file, a modification" 1 "not an added backlog task file: M" push_main

  fresh
  ln -s ../../README "$work/tasks/backlog/0009-a-link.md"
  git -C "$work" add -A
  commit_ungated "docs(tasks): file 0009 a-link [0009]"
  check_fails "refused: file, a symlink" 1 "not an added backlog task file: A 120000" push_main

  fresh
  mkdir -p "$work/tasks/doing"
  printf 'x\n' >"$work/tasks/doing/0009-in-doing.md"
  git -C "$work" add -A
  commit_ungated "docs(tasks): file 0009 in-doing [0009]"
  check_fails "refused: file, not the backlog" 1 "not an added backlog task file" push_main

  fresh
  printf 'more\n' >>"$work/tasks/backlog/0001-first-task.md"
  printf 'more\n' >>"$work/tasks/backlog/0002-second-task.md"
  git -C "$work" add -A
  commit_ungated "docs(tasks): revise 0001 first-task [0001]"
  check_fails "refused: revise, two files" 1 "not the file of task 0001: tasks/backlog/0002" push_main

  fresh
  printf 'more\n' >>"$work/tasks/backlog/0002-second-task.md"
  git -C "$work" add -A
  commit_ungated "docs(tasks): revise 0001 first-task [0001]"
  check_fails "refused: revise, another task" 1 "not the file of task 0001" push_main

  fresh
  printf 'more\n' >>"$work/docs/milestones/m1.md"
  git -C "$work" add -A
  commit_ungated "docs(tasks): note on 0001 [0001]"
  check_fails "refused: note, not a task file" 1 "not a modified backlog task file" push_main

  fresh
  git -C "$work" rm -q tasks/backlog/0001-first-task.md
  git -C "$work" commit -q --no-verify -m "docs(tasks): revise 0001 first-task [0001]"
  check_fails "refused: revise, a deletion" 1 "not a modified backlog task file: D" push_main

  fresh
  git -C "$work" mv tasks/backlog/0001-first-task.md tasks/done/0001-other-name.md 2>/dev/null \
    || { mkdir -p "$work/tasks/done"; git -C "$work" mv tasks/backlog/0001-first-task.md tasks/done/0001-other-name.md; }
  commit_ungated "docs(tasks): retire 0001 first-task [0001]"
  check_fails "refused: retire, renamed" 1 "not one backlog task file moved to done/ as it is named" push_main

  fresh
  mkdir -p "$work/tasks/done"
  git -C "$work" mv tasks/backlog/0001-first-task.md tasks/done/0001-first-task.md
  echo x >"$work/README"
  git -C "$work" add -A
  commit_ungated "docs(tasks): retire 0001 first-task [0001]"
  check_fails "refused: retire, with more" 1 "neither a deleted backlog nor an added done task file: A 100644 README" push_main

  fresh
  git -C "$work" mv tasks/backlog/0001-first-task.md tasks/done/0001-first-task.md
  commit_ungated "docs(tasks): retire 0002 second-task [0002]"
  check_fails "refused: retire, another task" 1 "not the file of task 0002" push_main

  # One good write does not carry a bad one along.
  fresh
  echo x >"$work/README"
  git -C "$work" add -A
  commit_ungated "feat: smuggled [0001]"
  printf 'x\n' >"$work/tasks/backlog/0009-good-one.md"
  git -C "$work" add -A
  commit_ungated "docs(tasks): file 0009 good-one [0009]"
  check_fails "refused: a bad commit under a good one" 1 "reaches main directly and is no merge: \"feat: smuggled" push_main

  # Merges: of a branch pushed before, allowed; of one never pushed, refused.
  fresh
  git -C "$work" checkout -q -b task/0001-first-task
  echo work >"$work/README"
  git -C "$work" add -A
  commit_ungated "feat: work [0001]"
  git -C "$work" checkout -q main
  git -C "$work" merge -q --no-ff --no-verify -m "Merge task/0001-first-task" task/0001-first-task
  check_fails "refused: a merge of an unpushed branch" 1 "which no pushed branch holds" push_main
  git -C "$work" push -q origin task/0001-first-task
  check "allowed: a merge of a pushed branch" "0" "$(push_main 2>/dev/null; echo $?)"

  # A fast-forward to a branch's commits is no merge.
  fresh
  git -C "$work" checkout -q -b task/0002-second-task
  echo more >"$work/README"
  git -C "$work" add -A
  commit_ungated "feat: more [0002]"
  git -C "$work" push -q origin task/0002-second-task
  check_fails "refused: a fast-forward to a branch" 1 "is no merge" git -C "$work" push -q origin HEAD:main
  check "allowed: pushing the branch itself" "0" "$(git -C "$work" push -q origin HEAD 2>/dev/null; echo $?)"

  # Rewriting main, deleting it.
  fresh
  git -C "$work" reset -q --hard HEAD~1
  check_fails "refused: not a fast-forward" 1 "not a fast-forward" git -C "$work" push -q -f origin HEAD:main
  check_fails "refused: deleting main" 1 "deletes main" git -C "$work" push -q origin :main

  # The main branch is the setting's.
  fresh
  mkdir -p "$work/.peal"
  printf 'main: trunk\n' >"$work/.peal/config.yml"
  echo x >"$work/README"
  git -C "$work" add README
  commit_ungated "feat: to main, not the main branch here [0001]"
  check_fails "the setting: trunk is guarded" 1 "reaches trunk directly" git -C "$work" push -q origin HEAD:trunk
  check "the setting: main is then an ordinary branch" "0" "$(push_main 2>/dev/null; echo $?)"
}

commit_msg() {
  local work mark
  work=$(repo)
  peal hooks install >/dev/null
  git -C "$work" checkout -q -b task/0001-some-task
  commit() { git -C "$work" commit -q --allow-empty -m "$1"; }

  check "subject: type, area, id" "0" "$(commit "feat(sim): a thing [0001]" 2>/dev/null; echo $?)"
  check "subject: no area" "0" "$(commit "fix: a thing [0001]" 2>/dev/null; echo $?)"
  for t in test refactor docs chore; do
    check "subject: type $t" "0" "$(commit "$t: a thing [0001]" 2>/dev/null; echo $?)"
  done
  check_fails "subject: unknown type" 1 "the subject is not <type>(<area>): <what>" commit "feature: a thing [0001]"
  check_fails "subject: capital area" 1 "the subject is not" commit "feat(Sim): a thing [0001]"
  check_fails "subject: no space" 1 "the subject is not" commit "feat:a thing [0001]"
  check_fails "subject: nothing said" 1 "does not end with its task id" commit "feat: [0001]"
  check_fails "subject: no id" 1 "does not end with its task id" commit "feat: a thing"
  check_fails "subject: a short id" 1 "does not end with its task id" commit "feat: a thing [001]"
  check_fails "subject: the id not last" 1 "does not end with its task id" commit "feat: [0001] a thing"
  check "subject: wip" "0" "$(commit "wip: half a thing" 2>/dev/null; echo $?)"
  check "subject: wip with an area" "0" "$(commit "wip(sim): half a thing" 2>/dev/null; echo $?)"
  check "subject: wip says so" "commit-msg: a wip commit; the checks are skipped. Say what is in flight in the task's Outcome." \
    "$(commit "wip: half" 2>&1)"
  check_fails "subject: wip, bare" 1 "the subject is not" commit "wip"
  for s in "Revert \"feat: x [0001]\"" "fixup! feat: x [0001]" "squash! feat: x [0001]" "amend! feat: x [0001]"; do
    check "subject: git's own: $s" "0" "$(commit "$s" 2>/dev/null; echo $?)"
  done
  check "subject: comments before it skipped" "0" \
    "$(printf '# a comment\n\nfeat: a thing [0001]\n' | git -C "$work" commit -q --allow-empty -F - 2>/dev/null; echo $?)"

  # commit.areas: then an area is required and one of them, or tasks.
  mkdir -p "$work/.peal"
  printf 'commit:\n  areas: [sim, ui]\n' >"$work/.peal/config.yml"
  check "areas: one of them" "0" "$(commit "feat(ui): a thing [0001]" 2>/dev/null; echo $?)"
  check "areas: tasks always" "0" "$(commit "chore(tasks): a move [0001]" 2>/dev/null; echo $?)"
  check_fails "areas: another" 1 "the area art is not one of commit.areas" commit "feat(art): a thing [0001]"
  check_fails "areas: none named" 1 "the subject names no area" commit "feat: a thing [0001]"
  check "areas: wip needs none" "0" "$(commit "wip: a thing" 2>/dev/null; echo $?)"

  # The task-file fast path: (tasks) commits touch only the tasks directory, and skip the checks.
  mark=$(scratch_dir)/ran
  printf 'checks:\n  commit: ["echo always >>%s"]\n' "$mark" >"$work/.peal/config.yml"
  mkdir -p "$work/tasks/doing"
  printf 'x\n' >"$work/tasks/doing/0001-some-task.md"
  git -C "$work" add tasks
  check "tasks fast path" "commit-msg: only task files; the checks are skipped." "$(commit "chore(tasks): claim 0001 [0001]" 2>&1)"
  check "tasks fast path: no check ran" "" "$(cat "$mark" 2>/dev/null)"
  printf 'y\n' >"$work/tasks/doing/0001-some-task.md"
  echo x >"$work/README"
  git -C "$work" add tasks README
  check_fails "tasks fast path: more than tasks" 1 "a (tasks) commit touches only tasks/; this one also:" commit "chore(tasks): close 0001 [0001]"
  git -C "$work" reset -q --hard
  echo notes >"$work/notes.txt"
  git -C "$work" add notes.txt
  commit "docs: notes [0001]" >/dev/null 2>&1
  git -C "$work" mv notes.txt tasks/doing/notes.txt
  check_fails "tasks fast path: both sides of a rename" 1 "this one also:
  notes.txt" commit "chore(tasks): close 0001 [0001]"
  git -C "$work" reset -q --hard

  # checks.commit: by path, from the top of the work tree, a failing one refusing the commit.
  # shellcheck disable=SC2016 # $PWD is the check's, expanded when it runs
  printf 'checks:\n  commit:\n    - "echo always >>%s"\n    - "src/ *.sh: echo code $PWD >>%s"\n    - "docs/guide.md: echo guide >>%s"\n    - "failing/: echo failing; exit 3"\n' \
    "$mark" "$mark" "$mark" >"$work/.peal/config.yml"
  : >"$mark"
  check "checks: no path touched" "0" "$(commit "feat: nothing [0001]" >/dev/null 2>&1; echo $?)"
  check "checks: only the one without paths ran" "always" "$(cat "$mark")"
  : >"$mark"
  mkdir -p "$work/src/deep" "$work/docs"
  echo x >"$work/src/deep/a.c"
  git -C "$work" add src
  check "checks: under a directory" "0" "$(commit "feat: code [0001]" >/dev/null 2>&1; echo $?)"
  check "checks: ran from the top" "always
code $work" "$(cat "$mark")"
  : >"$mark"
  echo x >"$work/tool.sh"
  git -C "$work" add tool.sh
  commit "feat: a script [0001]" >/dev/null 2>&1
  check "checks: a glob" "always
code $work" "$(cat "$mark")"
  : >"$mark"
  echo x >"$work/docs/guide.md"
  echo x >"$work/docs/guide.md.bak"
  git -C "$work" add docs
  commit "docs: guide [0001]" >/dev/null 2>&1
  check "checks: a file" "always
guide" "$(cat "$mark")"
  : >"$mark"
  echo y >"$work/src/deep/a.c"
  check "checks: a commit of paths sees them (its own index)" "0" "$(git -C "$work" commit -q -m "feat: more [0001]" src/deep/a.c >/dev/null 2>&1; echo $?)"
  check "checks: ...and ran" "always
code $work" "$(cat "$mark")"

  mkdir -p "$work/failing"
  echo x >"$work/failing/f"
  git -C "$work" add failing
  check_fails "checks: a failing check refuses" 1 "echo failing; exit 3 failed; the commit is refused. Fix it, or commit as 'wip: ...'." \
    commit "feat: broken [0001]"
  check "checks: nothing committed" "failing/f" "$(git -C "$work" diff --cached --name-only)"
  check "checks: wip commits it anyway" "0" "$(commit "wip: broken" >/dev/null 2>&1; echo $?)"

  # A merge: its subject is git's, its diff pays the checks.
  git -C "$work" checkout -q main
  git -C "$work" checkout -q -b task/0002-other
  mkdir -p "$work/failing"
  echo z >"$work/failing/g"
  git -C "$work" add failing
  git -C "$work" commit -q --no-verify -m "feat: other [0002]"
  git -C "$work" checkout -q task/0001-some-task
  check_fails "merge: its diff pays the checks" 1 "git merge --abort" git -C "$work" merge -q --no-ff -m "Merge branch 'task/0002-other'" task/0002-other
  git -C "$work" merge --abort
  printf 'checks:\n  commit: []\n' >"$work/.peal/config.yml"
  check "merge: its subject passes" "0" "$(git -C "$work" merge -q --no-ff -m "Merge branch 'task/0002-other'" task/0002-other >/dev/null 2>&1; echo $?)"

  # Settings that do not load refuse, rather than wave commits through.
  printf 'nonsense: 1\n' >"$work/.peal/config.yml"
  check_fails "broken settings refuse" 1 "Peal's settings do not load" commit "feat: a thing [0001]"
}

chain() {
  local work log
  work=$(repo)
  log=$(scratch_dir)/log
  mkdir -p "$work/.githooks"
  for h in commit-msg pre-push post-commit; do
    printf '#!/bin/sh\necho "%s $*" >>%s\n[ "%s" != pre-push ] || sed "s/^/  stdin: /" >>%s\n[ ! -f %s.fail ] || exit 7\n' \
      "$h" "$log" "$h" "$log" "$log" >"$work/.githooks/$h"
    chmod +x "$work/.githooks/$h"
  done
  git -C "$work" config core.hooksPath .githooks
  peal hooks install >/dev/null
  git -C "$work" checkout -q -b task/0001-chained

  git -C "$work" commit -q --allow-empty -m "feat: chained [0001]"
  check "chain: commit-msg and post-commit ran" "commit-msg .git/COMMIT_EDITMSG
post-commit " "$(cat "$log")"
  : >"$log"
  git -C "$work" commit -q --allow-empty -m "not a subject" 2>/dev/null
  check "chain: nothing after a refusal" "" "$(cat "$log")"
  touch "$log.fail"
  check_fails "chain: the project's hook refuses" 1 "" git -C "$work" commit -q --allow-empty -m "feat: its hook fails [0001]"
  rm "$log.fail"
  : >"$log"
  git -C "$work" push -q origin task/0001-chained 2>/dev/null
  check "chain: pre-push, with its arguments and stdin" "pre-push origin $(git -C "$work" remote get-url origin)
  stdin: refs/heads/task/0001-chained $(git -C "$work" rev-parse HEAD) refs/heads/task/0001-chained 0000000000000000000000000000000000000000" "$(cat "$log")"
  : >"$log"
  git -C "$work" push -q origin HEAD:main 2>/dev/null
  check "chain: not after the gate refused a push" "" "$(cat "$log")"

  # Without a hooks path before, the chain is the git directory's hooks/.
  work=$(repo)
  printf '#!/bin/sh\necho "default $*" >>%s\n' "$log" >"$work/.git/hooks/post-commit"
  chmod +x "$work/.git/hooks/post-commit"
  peal hooks install >/dev/null
  git -C "$work" checkout -q -b task/0001-default
  : >"$log"
  git -C "$work" commit -q --allow-empty -m "feat: chained [0001]"
  check "chain: the default hooks directory" "default " "$(cat "$log")"

  # Without Peal to find, the gates refuse.
  mv "$work/.git/peal-root" "$work/.git/peal-root.away"
  check_fails "no Peal found: refused" 1 "the Peal plugin is not found" \
    env HOME="$(scratch_dir)" CLAUDE_CONFIG_DIR="" git -C "$work" commit -q --allow-empty -m "feat: x [0001]"
}

PEAL_GITHOOKS_LIST=$(bash -c ". '$PEAL_ROOT/lib/githooks.sh'; printf '%s\n' \$PEAL_GITHOOKS")
cases() {
  install
  pre_push
  commit_msg
  chain
}
for_each_awk cases
finish
