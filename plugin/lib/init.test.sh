#!/usr/bin/env bash
# Harness for peal init (lib/init.sh, lib/config-block.awk, lib/settings-json.awk): each
# stage added to a throwaway project and removed again, for task files and for issues,
# leaving the project as it was apart from its tasks; and peal init --survey, on GitHub
# through lib/fake-gh when jq is here.
#
#   bash plugin/lib/init.test.sh
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }

# project -> a new git repository with a README committed; prints its path.
project() {
  local dir
  dir=$(cd "$(scratch_dir)" && pwd -P)
  git -C "$dir" init -q -b main
  echo "# A project" >"$dir/README.md"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m root
  printf '%s\n' "$dir"
}

# snapshot -> every path of the work tree (directories too) with its content's hash,
# every path under .git that is neither git's own nor a session's state (the heartbeat,
# the turn budget: task state, which removal keeps), and the repository's git config.
snapshot() {
  (cd "$work" && find . -path ./.git -prune -o -print | sort | while IFS= read -r path; do
    if [ -f "$path" ]; then printf '%s %s\n' "$path" "$(git hash-object "$path")"; else printf '%s/\n' "$path"; fi
  done)
  (cd "$work/.git" && find . \( -path ./objects -o -path ./refs -o -path ./logs -o -path ./hooks \
    -o -path ./info -o -path ./branches \) -prune -o -print | sort \
    | grep -v -x -e . -e ./HEAD -e ./config -e ./description -e ./index -e ./COMMIT_EDITMSG \
      -e ./ORIG_HEAD -e ./FETCH_HEAD -e ./packed-refs -e ./peal-heartbeat -e ./peal-turns \
      -e ./peal-nudged | sed 's|^\.|.git|')
  git -C "$work" config --local --list
}

settings_created='{
  "extraKnownMarketplaces": {"peal": {"source": {"source": "github", "repo": "Maximilian-Walz/peal"}}},
  "enabledPlugins": {"peal@peal": true}
}'

files_round_trip() {
  local work before out hooks
  work=$(project)
  before=$(snapshot)

  out=$(peal init --stage tasks)
  check "tasks: what it wrote" "created .peal/config.yml
created .peal/peal
created tasks/backlog/.gitkeep
created tasks/doing/.gitkeep
created tasks/done/.gitkeep
created tasks/TEMPLATE.md
created .claude/settings.json (the peal plugin enabled for the project)" "$out"
  check "tasks: the template is Peal's" "" "$(cmp "$PEAL_ROOT/templates/task.md" "$work/tasks/TEMPLATE.md")"
  check "tasks: the launcher is executable" "yes" "$([ -x "$work/.peal/peal" ] && echo yes)"
  check "tasks: the settings" "$settings_created" "$(cat "$work/.claude/settings.json")"
  check "tasks: recorded" "tasks" "$(peal config stages)"
  check "tasks: the defaults are comments" "files" "$(peal config storage.kind)"
  check "tasks: every default shown but stages" "$(grep -v '^stages:' "$PEAL_ROOT/lib/config-defaults.yml" | grep -c '^[a-z-]*:')" \
    "$(grep -c '^# [a-z-]*:' "$work/.peal/config.yml")"

  local again
  again=$(snapshot)
  out=$(peal init --stage tasks)
  check "tasks again: nothing new" "unchanged .peal/peal
unchanged tasks/TEMPLATE.md (the project's own is kept)
unchanged .claude/settings.json (the peal plugin enabled for the project)" "$out"
  check "tasks again: the same files" "$again" "$(snapshot)"

  out=$(peal hook session-start </dev/null 2>&1)
  check "session-start: the root recorded" "$PEAL_ROOT" "$(cat "$work/.git/peal-root")"
  out=$(peal init --stage guardrails)
  hooks=$(cd "$work/.git" && pwd)/peal/hooks
  check "guardrails: the hooks" "installed Peal's git hooks in $hooks (core.hooksPath); they chain to the hooks in $(cd "$work/.git" && pwd)/hooks" "$out"
  check "guardrails: core.hooksPath" "$hooks" "$(git -C "$work" config core.hooksPath)"

  out=$(peal init --stage milestones --title "The first steps")
  check "milestones: the file" "created docs/milestones/m1.md" "$out"
  check "milestones: current" "m1 current 1 - The first steps" "$(peal milestones)"
  out=$(peal init --stage milestones)
  check "milestones again: kept" "unchanged docs/milestones/ (it holds milestones)" "$out"

  out=$(peal init --stage belfry)
  check "belfry: the file and the check" "created .belfry.yml
skipped the check: belfry check is not available yet" "$out"
  check "belfry: the commands backend" "  backend: commands
    list: .peal/peal list
    start: /peal:work {task}
    milestone: .peal/peal milestone-state {id} {state} --reason {reason}" \
    "$(grep -E '^  backend|list:|start:|milestone:' "$work/.belfry.yml")"
  check "belfry: the actions are suggestions" "# actions:" "$(grep 'actions:' "$work/.belfry.yml")"
  check "all stages recorded, in order" "tasks
guardrails
milestones
belfry" "$(peal config stages)"
  check "a stage again: nothing new" "unchanged .belfry.yml
skipped the check: belfry check is not available yet" "$(peal init --stage belfry)"

  # A task filed meanwhile: it stays through every removal.
  printf -- '---\n---\n\n# 0001 — A task\n' >"$work/tasks/backlog/0001-a-task.md"
  check_refused "remove tasks before the others" "remove the guardrails stage first" peal init --remove tasks

  out=$(peal init --remove belfry)
  check "remove belfry" "removed .belfry.yml" "$out"
  out=$(peal init --remove milestones)
  check "remove milestones" "removed docs/milestones/m1.md
removed docs/milestones/
removed docs/" "$out"
  out=$(peal init --remove guardrails)
  check "remove guardrails" "removed Peal's git hooks from $hooks; core.hooksPath is unset" "$out"
  out=$(peal init --remove tasks)
  check "remove tasks" "removed tasks/TEMPLATE.md
removed tasks/backlog/.gitkeep
removed tasks/doing/.gitkeep
removed tasks/doing/
removed tasks/done/.gitkeep
removed tasks/done/
kept tasks/ (it holds tasks)
removed .claude/settings.json
removed .claude/
removed .peal/config.yml
removed .peal/peal
removed .peal/" "$out"
  rm "$work/tasks/backlog/0001-a-task.md"
  rmdir "$work/tasks/backlog" "$work/tasks"
  check "removed: as it was, apart from the task" "$before" "$(snapshot)"
  check "removed again: nothing to do" "" "$(peal init --remove tasks)"
}

# A project with settings, hooks and a config of its own: each is kept.
files_existing() {
  local work before out
  work=$(project)
  mkdir -p "$work/.claude" "$work/.peal"
  printf '{\n  "permissions": {\n    "allow": ["Bash(make)"]\n  },\n  "enabledPlugins": {\n    "other@market": true\n  }\n}\n' \
    >"$work/.claude/settings.json"
  printf 'main: trunk\n' >"$work/.peal/config.yml"
  git -C "$work" config core.hooksPath .githooks
  before=$(snapshot)

  out=$(peal init --stage tasks)
  check "existing: the settings updated" "updated .claude/settings.json (the peal plugin enabled for the project)" \
    "$(printf '%s\n' "$out" | grep settings)"
  check "existing: the keys inserted" '{
  "permissions": {
    "allow": ["Bash(make)"]
  },
  "enabledPlugins": {
    "other@market": true,
    "peal@peal": true
  },
  "extraKnownMarketplaces": {"peal": {"source": {"source": "github", "repo": "Maximilian-Walz/peal"}}}
}' "$(cat "$work/.claude/settings.json")"
  check "existing: the config kept, stages added" "main: trunk
stages: [tasks]" "$(cat "$work/.peal/config.yml")"
  peal init --stage guardrails >/dev/null
  check "existing: the hooks path kept for the chain" ".githooks" "$(git -C "$work" config peal.projectHooks)"

  printf 'tasks:\n  backend: commands\n' >"$work/.belfry.yml"
  check_fails "existing .belfry.yml: not overwritten" 1 "" peal init --stage belfry
  check "existing .belfry.yml: Peal's contract shown" ".belfry.yml exists and is not Peal's; the contract Peal would write:" \
    "$(peal init --stage belfry | head -n1)"
  check "existing .belfry.yml: kept" "tasks:
  backend: commands" "$(cat "$work/.belfry.yml")"
  check "existing .belfry.yml: not recorded" "tasks
guardrails" "$(peal config stages)"
  rm "$work/.belfry.yml"

  peal init --stage milestones >/dev/null
  echo "More goals." >>"$work/docs/milestones/m1.md"
  check "an edited milestone: kept" "kept docs/milestones/m1.md (it was written since)" "$(peal init --remove milestones)"
  rm -r "$work/docs"

  peal init --remove guardrails >/dev/null
  check "existing: core.hooksPath back" ".githooks" "$(git -C "$work" config core.hooksPath)"
  out=$(peal init --remove tasks)
  check "existing: the config kept" "kept .peal/config.yml (it holds the project's settings)" \
    "$(printf '%s\n' "$out" | grep config)"
  check "existing: as it was" "$before" "$(snapshot)"
}

issues_round_trip() {
  local work before out
  work=$(project)
  before=$(snapshot)

  out=$(peal init --stage tasks --storage issues --label "it's peal")
  check "issues: no task directories" "created .peal/config.yml
updated .peal/config.yml (storage: issues, label it's peal)
created .peal/peal
created .claude/settings.json (the peal plugin enabled for the project)" "$out"
  check "issues: the storage" "issues
it's peal" "$(peal config storage.kind; peal config storage.issues.label)"
  check "issues: the config's lines" "stages: [tasks]
storage:
  kind: issues
  issues:
    label: 'it''s peal'" "$(grep -v -e '^#' -e '^$' "$work/.peal/config.yml")"

  # Again, the repository set by hand meanwhile: kept; a new label replaces the old.
  awk '{ print } /^  issues:$/ { print "    repo: acme/widgets" }' "$work/.peal/config.yml" >"$work/config.tmp" \
    && mv "$work/config.tmp" "$work/.peal/config.yml"
  peal init --stage tasks --label tasks >/dev/null
  check "issues again: repo kept, label changed" "acme/widgets
tasks" "$(peal config storage.issues.repo; peal config storage.issues.label)"
  check_refused "a label for files" "--label is for the issues storage" peal init --stage tasks --storage files --label x

  check "issues: milestones on GitHub" "unchanged the milestones (the repository's milestones on GitHub)" \
    "$(peal init --stage milestones)"
  peal init --stage belfry >/dev/null
  check "issues: the github-issues backend" "tasks:
  backend: github-issues
  github-issues:
    label: 'tasks'
    start: /peal:work {task}
    idea: /peal:idea {idea}" "$(sed -n '2,7p' "$work/.belfry.yml")"

  peal hook session-start </dev/null >/dev/null 2>&1
  check "issues, session-start: the root recorded" "$PEAL_ROOT" "$(cat "$work/.git/peal-root")"
  peal init --remove belfry >/dev/null
  peal init --remove milestones >/dev/null
  out=$(peal init --remove tasks)
  check "issues: removed" "updated .peal/config.yml (storage removed)
removed .peal/config.yml
removed .peal/peal
removed .peal/" "$(printf '%s\n' "$out" | grep -v settings | grep -v claude)"
  check "issues: as it was" "$before" "$(snapshot)"
}

# Switching storage: files back to issues and to files again.
switch_storage() {
  local work
  work=$(project)
  peal init --stage tasks --storage issues >/dev/null
  check "switch: issues without a label" "stages: [tasks]
storage:
  kind: issues" "$(grep -v -e '^#' -e '^$' "$work/.peal/config.yml")"
  check "switch: to files" "updated .peal/config.yml (storage: files)" "$(peal init --stage tasks --storage files | head -n1)"
  check "switch: the storage block gone" "stages: [tasks]" "$(grep -v -e '^#' -e '^$' "$work/.peal/config.yml")"
}

refusals() {
  local work
  work=$(project)
  check_refused "no stage" "--stage STAGE or --remove STAGE" peal init
  check_refused "an unknown stage" "'bells' is not a stage" peal init --stage bells
  check_refused "a stage before tasks" "set up the tasks stage first" peal init --stage guardrails
  check_refused "storage for another stage" "--storage and --label are for --stage tasks" peal init --stage belfry --storage issues
  check_refused "a title for another stage" "--title is for --stage milestones" peal init --stage tasks --title x
  check_refused "an unknown storage" "--storage files|issues" peal init --stage tasks --storage cards
  check "nothing written" "" "$(cd "$work" && git status --porcelain)"

  # Settings that do not parse: the lines to add, status 1, the rest written.
  mkdir -p "$work/.claude"
  printf '{"permissions": {,}}\n' >"$work/.claude/settings.json"
  local out status
  out=$(peal init --stage tasks 2>&1)
  status=$?
  check "bad settings: status 1" "1" "$status"
  check "bad settings: the lines to add" 'add these lines to .claude/settings.json by hand:
{
  "extraKnownMarketplaces": {
    "peal": {"source": {"source": "github", "repo": "Maximilian-Walz/peal"}}
  },
  "enabledPlugins": {"peal@peal": true}
}' "$(printf '%s\n' "$out" | sed -n '/^add these/,$p')"
  check "bad settings: left alone" '{"permissions": {,}}' "$(cat "$work/.claude/settings.json")"
  check "bad settings: the rest there" "tasks" "$(peal config stages)"
}

# settings-json.awk on its own: the edits keep everything else as written.
settings_json() {
  local dir
  dir=$(scratch_dir)
  printf '{"a": 1, "b": {"c": [1, {"d": "x\\"y"}]}, "e": {}}\n' >"$dir/s.json"
  sj() { awk "$@" -f "$PEAL_ROOT/lib/settings-json.awk" "$dir/s.json"; }
  check "json: has" "0 1" "$(sj -v op=has -v path=b.c; echo -n "$? "; sj -v op=has -v path=b.x; echo $?)"
  check "json: kind" "object 1|object 0|array|other" \
    "$(sj -v op=kind -v path=b)|$(sj -v op=kind -v path=e)|$(sj -v op=kind -v path=b.c)|$(sj -v op=kind -v path=a)"
  check "json: insert inline" '{"a": 1, "b": {"c": [1, {"d": "x\"y"}], "k": true}, "e": {}}' "$(sj -v op=insert -v path=b -v key=k -v json=true)"
  check "json: insert into empty" '{"a": 1, "b": {"c": [1, {"d": "x\"y"}]}, "e": {
  "k": 2
}}' "$(sj -v op=insert -v path=e -v key=k -v json=2)"
  check "json: delete first" '{"b": {"c": [1, {"d": "x\"y"}]}, "e": {}}' "$(sj -v op=delete -v path=a)"
  check "json: delete last" '{"a": 1, "b": {"c": [1, {"d": "x\"y"}]}}' "$(sj -v op=delete -v path=e)"
  check "json: delete only" '{"a": 1, "b": {}, "e": {}}' "$(sj -v op=delete -v path=b.c)"
  for bad in '[1]' '{"a": }' '{"a": 1' '{"a": 1} x' '{a: 1}' '{"a": tru}'; do
    printf '%s\n' "$bad" >"$dir/s.json"
    check "json: refused $bad" "2" "$(sj -v op=has -v path= 2>/dev/null; echo $?)"
  done
}

# survey KEY... -> the survey's lines of those keys.
survey() {
  local keys=$*
  peal init --survey | awk -v keys=" $keys " 'index(keys, " " $1 " ")'
}

# The survey: what /peal:setup decides from, and the storage it recommends.
surveys() {
  local work
  work=$(project)
  check "survey: a bare project" "stages -
next tasks
storage -
branch main main main
github -
closes 0
readme README.md
todo -
todo-marks 0
ci -
taskdir -
belfry -
recommend files" "$(peal init --survey)"
  check "survey: writes nothing" "" "$(git -C "$work" status --porcelain)"

  mkdir -p "$work/docs" "$work/.github/workflows" "$work/tasks"
  printf 'x\n' >"$work/TODO.md"
  printf 'x\n' >"$work/docs/todo.txt"
  printf 'a: 1 # TODO later\nb: 2 # FIXME\n' >"$work/.github/workflows/ci.yml"
  printf 'x\n' >"$work/tasks/0001-a.md"
  git -C "$work" add -A
  git -C "$work" commit -q -m "feat: things" -m "Fixes #4"
  git -C "$work" commit -q --allow-empty -m "fix: closes acme/widgets#5"
  git -C "$work" commit -q --allow-empty -m "docs: see #6"
  git -C "$work" checkout -q -b topic
  check "survey: what is there" "branch topic main main
closes 2
todo TODO.md,docs/todo.txt
todo-marks 2
ci .github/workflows/ci.yml
taskdir tasks/ 1" "$(survey branch closes todo todo-marks ci taskdir)"

  if command -v jq >/dev/null; then
    fake_github "$work"
    git -C "$work" remote add origin https://github.com/acme/widgets.git
    check "survey: on GitHub, closing issues" "github acme/widgets
issues 0
milestones 0
recommend issues" "$(survey github issues milestones recommend)"
    git -C "$work" checkout -q main
    git -C "$work" reset -q --hard HEAD~3
    check "survey: on GitHub, nothing to keep there" "recommend files" "$(survey recommend)"
    gh_save issues '. + [{number: 1, state: "open", title: "a"}, {number: 2, state: "open", title: "b", pull_request: {}}]'
    gh_save milestones '. + [{number: 1, state: "open", title: "m1"}, {number: 2, state: "closed", title: "m0"}]'
    check "survey: open issues" "issues 1
milestones 1
recommend issues" "$(survey issues milestones recommend)"
    printf 'GET *\n' >"$FAKE_GH/fail"
    check "survey: gh cannot tell" "issues unknown: gh api repos/acme/widgets/issues?state=open&per_page=100 failed: gh: HTTP 502: failing on purpose (GET repos/acme/widgets/issues?state=open&per_page=100)
recommend files" "$(survey issues recommend)"
    rm -f "$FAKE_GH/fail"
  fi

  peal init --stage tasks >/dev/null
  printf 'tasks: {}\n' >"$work/.belfry.yml"
  check "survey: set up" "stages tasks
next guardrails
storage files
taskdir -
belfry other
recommend files" "$(survey stages next storage taskdir belfry recommend)"
  rm "$work/.belfry.yml"
  peal init --stage guardrails >/dev/null
  peal init --stage milestones >/dev/null
  peal init --stage belfry >/dev/null
  check "survey: every stage" "stages tasks,guardrails,milestones,belfry
next -
belfry peal" "$(survey stages next belfry)"
  check_refused "survey: no arguments" "--survey takes no arguments" peal init --survey x
}

cases() {
  surveys
  files_round_trip
  files_existing
  issues_round_trip
  switch_storage
  refusals
  settings_json
}

for_each_awk cases
finish
