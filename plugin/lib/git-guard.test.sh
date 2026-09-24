#!/usr/bin/env bash
# Harness for the git guard (lib/git-guard.sh, lib/shell-words.awk, lib/json-get.awk),
# through `peal hook git-guard` fed the JSON Claude Code gives a PreToolUse hook:
#
#   bash plugin/lib/git-guard.test.sh
#
# Each refusal (a commit on main, the gate bypasses, a push to main), and the commands
# that only look like one: a message, a heredoc, a grep, a string.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

# json_str S -> S as a JSON string.
json_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  printf '"%s"' "$s"
}

# guard CWD COMMAND -> the hook run on a Bash call of COMMAND in CWD.
guard() {
  printf '{"session_id":"s","cwd":%s,"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":%s,"description":"a \\"command\\": git push origin main"}}' \
    "$(json_str "$1")" "$(json_str "$2")" | "$PEAL" hook git-guard
}

refused() { check_fails "refused: $2" 2 "$3" guard "$1" "$2"; }

# allowed CWD COMMAND -> the hook passes it, silently.
allowed() {
  local out status
  out=$(guard "$1" "$2" 2>&1)
  status=$?
  check "allowed: $2" "0" "$status${out:+ $out}"
}

cases() {
  local work task plain
  work=$(repo)
  mkdir -p "$work/.peal"
  task=$work-task
  git -C "$work" worktree add -q -b task/0001-some-task "$task" 2>/dev/null
  mkdir -p "$task/.peal"
  plain=$(scratch_dir)
  git -C "$plain" init -q -b main 2>/dev/null || { git -C "$plain" init -q; git -C "$plain" checkout -q -b main; }

  # Commits: never on main.
  refused "$work" 'git commit -m "feat: x [0001]"' "no commit on main: work on the task's branch."
  refused "$work" 'git -c user.name=x commit -qam "feat: x [0001]"' "no commit on main"
  refused "$task" "git -C $work commit -m x" "no commit on main"
  refused "$task" "cd $work && git commit -m x" "no commit on main"
  refused "$work" 'git cherry-pick abc' "no cherry-pick on main"
  refused "$work" 'git revert HEAD' "no revert on main"
  refused "$work" 'git am < p.patch' "no am on main"
  allowed "$task" 'git commit -m "feat: x [0001]"'
  allowed "$task" "cd $work; cd $task; git commit -m x"
  allowed "$work" 'git status && git log --oneline -3 | head'
  allowed "$work" 'git merge --ff-only origin/main'
  allowed "$plain" 'git commit -m "no Peal here"'

  # No gate bypass.
  refused "$task" 'git commit --no-verify -m x' "--no-verify: that turns Peal's git gates off."
  refused "$task" 'git commit -n -m x' "commit -n (--no-verify)"
  refused "$task" 'git commit -anm x' "commit -n"
  refused "$task" "git commit -q -m 'x' --no-verify" "--no-verify"
  refused "$task" 'git push --no-verify origin HEAD' "--no-verify"
  refused "$task" 'git merge --no-verify main' "--no-verify"
  refused "$task" 'git -c core.hooksPath=/dev/null commit -m x' "setting core.hooksPath for one git call"
  refused "$task" 'git -c CORE.HOOKSPATH=x push' "core.hooksPath for one git call"
  refused "$task" 'git -ccore.hooksPath=x status' "core.hooksPath for one git call"
  refused "$task" 'git --config-env=core.hooksPath=H commit -m x' "core.hooksPath for one git call"
  refused "$task" 'git "-c" "core.hooksPath=/x" commit -m x' "core.hooksPath for one git call"
  refused "$task" 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/x git commit -m x' "GIT_CONFIG_COUNT sets git configuration"
  refused "$task" 'git config core.hooksPath /elsewhere' "changing core.hooksPath turns Peal's git gates off."
  refused "$task" 'git config --local core.hooksPath "/else where"' "changing core.hooksPath"
  refused "$task" 'git config --unset core.hooksPath' "changing core.hooksPath"
  refused "$task" 'git config unset core.hookspath' "changing core.hooksPath"
  refused "$task" 'git config set core.hooksPath x' "changing core.hooksPath"
  refused "$task" 'git config --remove-section core' "removing git's core section"
  refused "$task" 'git lfs install --force' "writes LFS's hooks over Peal's"
  refused "$task" 'git-lfs update --force' "writes LFS's hooks over Peal's"
  allowed "$task" 'git config core.hooksPath'
  allowed "$task" 'git config --get core.hooksPath'
  allowed "$task" 'git config get core.hooksPath'
  allowed "$task" 'git config user.name x'
  allowed "$task" 'git lfs install --skip-repo'
  allowed "$task" 'git commit -m "explain why --no-verify is banned"'
  allowed "$task" 'git commit -m "-n is not the point" -F msg'
  allowed "$task" 'git commit -F-n'
  allowed "$task" 'git commit --author "n <n@x>" -m x'
  allowed "$task" 'git commit -m x -- -n'
  allowed "$task" 'grep -n core.hooksPath lib/git-guard.sh; rg -- --no-verify .'
  allowed "$task" "$(printf 'cat > f <<'"'"'EOF'"'"'\ngit commit --no-verify\ngit config core.hooksPath x\nEOF\ngit status')"
  allowed "$task" "$(printf 'cat <<-EOF >x\n\tgit push origin main\n\tEOF\necho ok')"
  allowed "$task" 'echo "git push origin main"  # git push origin main'
  allowed "$task" 'git log --grep="--no-verify"'

  # No push to main.
  refused "$task" 'git push origin HEAD:main' "nothing is pushed to main by hand."
  refused "$task" 'git push origin main' "nothing is pushed to main"
  refused "$task" 'git push -f origin +task/0001-some-task:refs/heads/main' "nothing is pushed to main"
  refused "$task" 'git push origin :main' "nothing is pushed to main"
  refused "$task" 'git push --delete origin main' "nothing is pushed to main"
  refused "$task" 'git push --all' "pushes main too"
  refused "$task" 'git push --mirror origin' "pushes main too"
  refused "$work" 'git push' "nothing is pushed to main"
  refused "$work" 'git push origin' "nothing is pushed to main"
  refused "$work" 'git push -u origin HEAD' "nothing is pushed to main"
  # shellcheck disable=SC2016 # the commands as the session types them
  refused "$task" 'echo $(git push origin HEAD:main)' "nothing is pushed to main"
  # shellcheck disable=SC2016
  refused "$task" 'x=`git push origin main`' "nothing is pushed to main"
  refused "$task" 'bash -c "git push origin HEAD:main"' "nothing is pushed to main"
  refused "$task" "sh -ec 'cd . && git push origin main'" "nothing is pushed to main"
  refused "$task" "eval 'git push origin main'" "nothing is pushed to main"
  refused "$task" 'git status; timeout 60 git push origin main 2>&1 | tail' "nothing is pushed to main"
  refused "$task" "$(printf 'git status \\\n  && git push origin main')" "nothing is pushed to main"
  refused "$task" 'if true; then git push origin main; fi' "nothing is pushed to main"
  refused "$task" '(git push origin main)' "nothing is pushed to main"
  allowed "$task" 'git push'
  allowed "$task" 'git push -u origin HEAD'
  allowed "$task" 'git push origin task/0001-some-task'
  allowed "$task" 'git push -o main origin HEAD'
  allowed "$task" 'git push origin HEAD:refs/heads/task/0001-main'
  allowed "$task" 'git fetch origin main && git rebase origin/main'
  allowed "$task" 'git log origin/main..HEAD'
  allowed "$plain" 'git push origin main'
  allowed "$task" "$PEAL create some-task < text.md"

  # The main branch is the setting's.
  printf 'main: trunk\n' >"$task/.peal/config.yml"
  refused "$task" 'git push origin HEAD:trunk' "nothing is pushed to trunk by hand."
  allowed "$task" 'git push origin HEAD:main'

  # Not a Bash call about git, or no command at all: nothing to judge.
  check "no command" "0" "$(printf '{"tool_input":{}}' | "$PEAL" hook git-guard; echo $?)"
  check "not JSON" "0" "$(printf 'nonsense' | "$PEAL" hook git-guard; echo $?)"
}

for_each_awk cases
finish
