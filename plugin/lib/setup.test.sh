#!/usr/bin/env bash
# Harness for /peal:setup's scripted path (plugin/commands/setup.md): a scratch project
# with a bare remote set up stage by stage as the command does it (the survey, a setup
# branch, peal init, the chore(peal) commit through Peal's commit gate once it is there,
# the first task filed), the setup merged as a pull request would merge it, and the first
# task then claimed by `peal work`; on task files, and on issues (lib/fake-gh, so only
# when jq is here).
#
#   bash plugin/lib/setup.test.sh
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }

# project -> work, a clone of a new bare remote holding a README on main. Not in a
# subshell: it sets the caller's work.
project() {
  local dir
  dir=$(cd "$(scratch_dir)" && pwd -P)
  git init -q --bare "$dir/remote.git"
  git -C "$dir/remote.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$dir/remote.git" "$dir/work" 2>/dev/null
  work=$dir/work
  git -C "$work" checkout -q -b main 2>/dev/null
  printf '# Widgets\n\nTODO: say how to install it.\n' >"$work/README.md"
  git -C "$work" add -A
  git -C "$work" commit -q -m root
  git -C "$work" push -q -u origin main 2>/dev/null
}

# stage STAGE [ARGS...] -> the command's steps 2 to 4: a setup branch off main, the stage
# written, exactly the paths it printed and the config (which records the stage)
# committed as chore(peal); the stage's output.
stage() {
  local name=$1 out verb path
  shift
  git -C "$work" switch -q -c "peal/setup-$name"
  out=$(peal init --stage "$name" "$@") || return 1
  while read -r verb path _; do
    case $verb in
      created | updated | removed) [ -e "$work/$path" ] || [ "$verb" = removed ] && git -C "$work" add -A -- "$path" ;;
    esac
  done <<<"$out"
  git -C "$work" add -- .peal/config.yml
  git -C "$work" commit -q -m "chore(peal): set up the $name stage" -m "$out" >/dev/null 2>&1 || return 1
  printf '%s\n' "$out"
}

# merge -> the setup branch pushed and merged into main as its pull request would be.
merge() {
  local branch
  branch=$(git -C "$work" symbolic-ref --short HEAD)
  git -C "$work" push -q -u origin "$branch" 2>/dev/null
  git -C "$work" switch -q main
  git -C "$work" pull -q --no-rebase origin main 2>/dev/null
  git -C "$work" merge -q --no-ff --no-edit "$branch" >/dev/null
  git -C "$work" push -q origin main
}

# first_task SLUG TITLE [FRONTMATTER-LINE...] -> step 5's text filed with peal create.
first_task() {
  local slug=$1 title=$2
  shift 2
  {
    printf -- '---\nplan: skipped\n'
    [ $# -eq 0 ] || printf '%s\n' "$@"
    printf -- '---\n\n# NNNN — %s\n\n## Intent\n\nThe README says how to install.\n\n## Scope\n\n## Done when\n\n' "$title"
    printf '## Raw\n\n> TODO: say how to install it.\n\n## Notes\n\nProposed by /peal:setup.\n\n---\n\n## Outcome\n\n'
    printf '<!-- Written at close, replacing this comment. -->\n'
  } | peal create "$slug"
}

files() {
  local work out
  project
  check "files: recommended" "recommend files" "$(peal init --survey | grep '^recommend')"

  stage tasks --storage files >/dev/null
  check "files: one commit on the setup branch" "peal/setup-tasks|chore(peal): set up the tasks stage" \
    "$(git -C "$work" symbolic-ref --short HEAD)|$(git -C "$work" log -1 --format=%s)"
  check "files: the commit holds the setup" ".claude/settings.json
.peal/config.yml
.peal/peal
tasks/TEMPLATE.md
tasks/backlog/.gitkeep
tasks/doing/.gitkeep
tasks/done/.gitkeep" "$(git -C "$work" show --format= --name-only HEAD)"
  check "files: nothing left over" "" "$(git -C "$work" status --porcelain)"
  out=$(first_task install-in-readme "Say how to install in the README")
  check "files: the first task filed" "filed 0001 tasks/backlog/0001-install-in-readme.md" "$(printf '%s\n' "$out" | cut -d' ' -f1-3)"

  merge
  out=$(peal work 0001)
  check "files: /peal:work claims the first task" "CLAIMED 0001" "$(printf '%s\n' "$out" | grep '^CLAIMED' | cut -d' ' -f1-2)"

  # Later stages, each on its own branch; from guardrails on, through the commit gate.
  out=$(stage guardrails)
  check "files: guardrails committed through the gate" "chore(peal): set up the guardrails stage|.peal/config.yml" \
    "$(git -C "$work" log -1 --format=%s)|$(git -C "$work" show --format= --name-only HEAD)"
  merge
  stage milestones --title "Installable" >/dev/null
  check "files: the review task waits for the milestone on main" "2" \
    "$(first_task review-installable "Review milestone Installable" "milestone: m1" "depends: [milestone]" >/dev/null 2>&1; echo $?)"
  merge
  out=$(first_task review-installable "Review milestone Installable" "milestone: m1" "depends: [milestone]")
  check "files: then it is filed" "filed 0002" "$(printf '%s\n' "$out" | cut -d' ' -f1-2)"
  check "files: in its milestone, depending on it" "0002 free review-installable m1|milestone" \
    "$(peal list --no-pr 0002)|$(peal read 0002 | sed -n 's/^depends: \[\(.*\)\]$/\1/p')"
  stage belfry >/dev/null
  check "files: belfry committed" ".belfry.yml
.peal/config.yml" "$(git -C "$work" show --format= --name-only HEAD)"
  merge
  check "files: every stage" "stages tasks,guardrails,milestones,belfry" "$(peal init --survey | grep '^stages')"
  check_fails "files: the gate keeps setup commits to the setup" 1 "a (peal) commit is Peal's setup" \
    sh -c "cd '$work' && git switch -q -c peal/other && echo x >>README.md && git commit -q -am 'chore(peal): sneak'"
}

issues() {
  local work out
  project
  fake_github "$work"
  issue 1 "Say how to install"
  stage tasks --storage issues >/dev/null
  check "issues: the commit holds the setup" ".claude/settings.json
.peal/config.yml
.peal/peal" "$(git -C "$work" show --format= --name-only HEAD)"
  # The remote here is a path, not GitHub: the repository set by hand, as a project may.
  printf '  issues:\n    repo: acme/widgets\n' >>"$work/.peal/config.yml"
  git -C "$work" commit -q -am "chore(peal): the repository"
  check "issues: the open issue is a task" "1 free" "$(peal list --no-pr 1 | cut -d' ' -f1-2)"
  merge
  out=$(peal work 1)
  check "issues: /peal:work claims the first task" "CLAIMED 1" "$(printf '%s\n' "$out" | grep '^CLAIMED' | cut -d' ' -f1-2)"
  stage guardrails >/dev/null
  merge
  check "issues: milestones on GitHub" "unchanged the milestones (the repository's milestones on GitHub)" \
    "$(stage milestones)"
  merge
  stage belfry >/dev/null
  check "issues: the github-issues backend" "  backend: github-issues" "$(sed -n 3p "$work/.belfry.yml")"
}

cases() {
  files
  if command -v jq >/dev/null; then
    issues
  elif [ -n "${PEAL_REQUIRE_JQ-}" ]; then
    check "jq, which the fake gh needs" "jq" ""
  fi
}

for_each_awk cases
finish
