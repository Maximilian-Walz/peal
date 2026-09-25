# shellcheck shell=bash
# peal init: a project's setup, in stages, written deterministically; /peal:setup is the
# conversation on top. Each stage is safe to run again and taken back by --remove, which
# leaves the tasks themselves alone. The stages set up are recorded as `stages:` in
# .peal/config.yml, so other commands know what is there.
#
#   tasks       .peal/config.yml (Peal's defaults as comments), the launcher .peal/peal,
#               tasks/ with backlog/, doing/, done/ and TEMPLATE.md (files), or
#               storage.kind issues with its label (issues); the .claude/settings.json
#               lines that enable the plugin for everyone on the project
#   guardrails  peal hooks install (core.hooksPath); the session hooks come from the
#               plugin's hooks.json
#   milestones  a first milestone file (files); for issues, the repository's milestones
#   belfry      .belfry.yml: the commands backend (files) or github-issues (issues), the
#               actions Peal provides as suggestions
#
# peal init --survey writes nothing: it prints the facts about the repository the
# conversation decides from.
#
# Nothing is committed: the stage prints what it wrote, for the caller to commit.

PEAL_INIT_STAGES="tasks guardrails milestones belfry"
PEAL_INIT_MARKETPLACE=Maximilian-Walz/peal
PEAL_INIT_SETTINGS=.claude/settings.json

# _peal_init_say VERB PATH [NOTE] -> one line of what a stage did.
_peal_init_say() {
  printf '%s %s%s\n' "$1" "$2" "${3:+ ($3)}"
}

# _peal_init_put PATH FILE -> PATH made FILE's copy: created, updated or unchanged.
_peal_init_put() {
  local path=$1 src=$2
  if [ -f "$path" ] && cmp -s "$src" "$path"; then
    _peal_init_say unchanged "$path"
    return 0
  fi
  local verb=created
  [ ! -e "$path" ] || verb=updated
  if ! { mkdir -p "$(dirname "$path")" && cp "$src" "$path"; }; then
    peal_err "init: could not write $path"
    return 2
  fi
  _peal_init_say "$verb" "$path"
}

# _peal_init_rm PATH -> PATH removed, if it is there.
_peal_init_rm() {
  [ -e "$1" ] || return 0
  rm -f "$1" && _peal_init_say removed "$1"
}

# _peal_init_rmdir DIR -> DIR and its parents removed while they are empty.
_peal_init_rmdir() {
  local dir=${1%/}
  while [ -n "$dir" ] && [ "$dir" != . ] && [ -d "$dir" ] && rmdir "$dir" 2>/dev/null; do
    _peal_init_say removed "$dir/"
    dir=$(dirname "$dir")
  done
}

# _peal_init_quote TEXT -> TEXT as a single-quoted YAML scalar.
_peal_init_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

# --- .peal/config.yml ------------------------------------------------------------------

# _peal_init_config_text -> a new .peal/config.yml: a header, stages: [tasks], and every
# default commented out.
_peal_init_config_text() {
  cat <<'EOF'
# Peal's settings for this project. The lines commented out below are Peal's defaults:
# uncomment one and change it to set it here; a key Peal does not know is refused.
# `stages` (the setup stages done) and `storage` belong to `peal init`.

stages: [tasks]

# Peal's defaults:
EOF
  awk 'body || !/^#/ { body = 1 } body && !/^stages:/ { print "# " $0 }' "$PEAL_ROOT/lib/config-defaults.yml" \
    | sed 's/ *$//'
}

# _peal_init_block KEY [FILE] -> KEY's block in .peal/config.yml set to FILE's lines, or
# removed without FILE; the settings must still load.
_peal_init_block() {
  local tmp
  tmp=$(mktemp) || return 2
  if ! awk -v key="$1" -v block="${2-}" -f "$PEAL_ROOT/lib/config-block.awk" "$PEAL_CONFIG_FILE" >"$tmp"; then
    rm -f "$tmp"
    return 2
  fi
  if cmp -s "$tmp" "$PEAL_CONFIG_FILE"; then
    rm -f "$tmp"
    return 0
  fi
  cat "$tmp" >"$PEAL_CONFIG_FILE" && rm -f "$tmp" || return 2
  peal_config_load
}

# _peal_init_stages -> the stages recorded, one per line.
_peal_init_stages() {
  [ -f "$PEAL_CONFIG_FILE" ] || return 0
  peal_config_load || return 2
  peal_config_get stages
}

# _peal_init_has STAGE -> status 0 if STAGE is recorded.
_peal_init_has() {
  local stages
  stages=$(_peal_init_stages) || return 2
  printf '%s\n' "$stages" | grep -qx -- "$1"
}

# _peal_init_record add|remove STAGE -> stages: rewritten, in the stages' order; the key
# removed when none is left.
_peal_init_record() {
  local stages s list="" tmp
  stages=$(_peal_init_stages) || return 2
  for s in $PEAL_INIT_STAGES; do
    if [ "$s" = "$2" ]; then
      [ "$1" = add ] || continue
    else
      printf '%s\n' "$stages" | grep -qx -- "$s" || continue
    fi
    list="$list${list:+, }$s"
  done
  [ -f "$PEAL_CONFIG_FILE" ] || return 0
  if [ -z "$list" ]; then
    _peal_init_block stages
    return
  fi
  tmp=$(mktemp) || return 2
  printf 'stages: [%s]\n' "$list" >"$tmp"
  _peal_init_block stages "$tmp"
  local status=$?
  rm -f "$tmp"
  return $status
}

# --- .claude/settings.json -------------------------------------------------------------

_peal_init_json() {
  awk -v name="$PEAL_INIT_SETTINGS" "$@" -f "$PEAL_ROOT/lib/settings-json.awk" "$PEAL_INIT_SETTINGS"
}

# _peal_init_settings_hint VERB -> the lines to add or remove by hand.
_peal_init_settings_hint() {
  printf '%s these lines %s %s by hand:\n' "$1" "$([ "$1" = add ] && echo to || echo from)" "$PEAL_INIT_SETTINGS"
  cat <<EOF
{
  "extraKnownMarketplaces": {
    "peal": {"source": {"source": "github", "repo": "$PEAL_INIT_MARKETPLACE"}}
  },
  "enabledPlugins": {"peal@peal": true}
}
EOF
}

# _peal_init_json_edit ARGS... -> the settings rewritten by settings-json.awk with ARGS.
_peal_init_json_edit() {
  local tmp
  tmp=$(mktemp) || return 2
  _peal_init_json "$@" >"$tmp" && cat "$tmp" >"$PEAL_INIT_SETTINGS"
  local status=$?
  rm -f "$tmp"
  return $status
}

# _peal_init_settings_add -> the plugin enabled for everyone on the project; status 1 with
# the lines to add when the file cannot take them.
_peal_init_settings_add() {
  local verb=unchanged parent key json kind
  if [ ! -e "$PEAL_INIT_SETTINGS" ]; then
    mkdir -p "$(dirname "$PEAL_INIT_SETTINGS")" && printf '{}\n' >"$PEAL_INIT_SETTINGS" || return 2
    verb=created
  elif ! _peal_init_json -v op=has -v path= >/dev/null; then
    _peal_init_settings_hint add
    return 1
  fi
  for parent in extraKnownMarketplaces enabledPlugins; do
    if [ $parent = extraKnownMarketplaces ]; then
      key=peal json="{\"source\": {\"source\": \"github\", \"repo\": \"$PEAL_INIT_MARKETPLACE\"}}"
    else
      key=peal@peal json=true
    fi
    kind=$(_peal_init_json -v op=kind -v path=$parent) || return 2
    case $kind in
      "") _peal_init_json_edit -v op=insert -v path= -v key=$parent -v json="{\"$key\": $json}" || return 2 ;;
      object*)
        _peal_init_json -v op=has -v path="$parent.$key" && continue
        _peal_init_json_edit -v op=insert -v path=$parent -v key=$key -v json="$json" || return 2
        ;;
      *)
        peal_err "init: $parent in $PEAL_INIT_SETTINGS is not an object"
        _peal_init_settings_hint add
        return 1
        ;;
    esac
    [ $verb = created ] || verb=updated
  done
  _peal_init_say $verb "$PEAL_INIT_SETTINGS" "the peal plugin enabled for the project"
}

# _peal_init_settings_remove -> Peal's lines taken out; the file removed once it holds
# nothing else.
_peal_init_settings_remove() {
  local changed="" path parent
  [ -e "$PEAL_INIT_SETTINGS" ] || return 0
  if ! _peal_init_json -v op=has -v path= >/dev/null; then
    _peal_init_settings_hint remove
    return 1
  fi
  for path in extraKnownMarketplaces.peal enabledPlugins.peal@peal; do
    parent=${path%%.*}
    if _peal_init_json -v op=has -v path="$path"; then
      _peal_init_json_edit -v op=delete -v path="$path" || return 2
      changed=1
    fi
    if [ "$(_peal_init_json -v op=kind -v path="$parent")" = "object 0" ]; then
      _peal_init_json_edit -v op=delete -v path="$parent" || return 2
    fi
  done
  if [ "$(_peal_init_json -v op=kind -v path=)" = "object 0" ]; then
    _peal_init_rm "$PEAL_INIT_SETTINGS"
    _peal_init_rmdir "$(dirname "$PEAL_INIT_SETTINGS")"
  elif [ -n "$changed" ]; then
    _peal_init_say updated "$PEAL_INIT_SETTINGS" "the peal plugin's lines removed"
  fi
}

# --- the stages ------------------------------------------------------------------------

# _peal_init_tasks STORAGE LABEL LABEL-GIVEN -> the tasks stage; STORAGE files, issues or
# empty (keep what the config says).
_peal_init_tasks() {
  local storage=$1 label=$2 label_given=$3 tmp repo kind dir d status=0
  mkdir -p .peal || return 2
  if [ ! -e "$PEAL_CONFIG_FILE" ]; then
    _peal_init_config_text >"$PEAL_CONFIG_FILE" || return 2
    _peal_init_say created "$PEAL_CONFIG_FILE"
  fi
  peal_config_load || return 2
  kind=$(peal_config_get storage.kind) || return 2
  [ -n "$storage" ] || storage=$kind
  if [ -n "$label_given" ] && [ "$storage" != issues ]; then
    peal_err "init: --label is for the issues storage (--storage issues)"
    return 2
  fi
  if [ "$storage" = issues ] && { [ "$kind" != issues ] || [ -n "$label_given" ]; }; then
    repo=$(peal_config_get storage.issues.repo) || return 2
    [ -n "$label_given" ] || label=$(peal_config_get storage.issues.label) || return 2
    tmp=$(mktemp) || return 2
    {
      printf 'storage:\n  kind: issues\n'
      if [ -n "$repo" ] || [ -n "$label" ]; then printf '  issues:\n'; fi
      [ -z "$repo" ] || printf '    repo: %s\n' "$(_peal_init_quote "$repo")"
      [ -z "$label" ] || printf '    label: %s\n' "$(_peal_init_quote "$label")"
    } >"$tmp"
    _peal_init_block storage "$tmp" || status=2
    rm -f "$tmp"
    [ $status -eq 0 ] || return 2
    _peal_init_say updated "$PEAL_CONFIG_FILE" "storage: issues${label:+, label $label}"
  elif [ "$storage" = files ] && [ "$kind" != files ]; then
    _peal_init_block storage || return 2
    _peal_init_say updated "$PEAL_CONFIG_FILE" "storage: files"
  fi
  _peal_init_put .peal/peal "$PEAL_ROOT/templates/launcher" || return 2
  chmod +x .peal/peal || return 2
  if [ "$storage" = files ]; then
    dir=$(peal_config_get tasks) || return 2
    dir=${dir%/}
    for d in backlog doing "done"; do
      mkdir -p "$dir/$d" || return 2
      if [ -z "$(ls -A "$dir/$d")" ]; then
        : >"$dir/$d/.gitkeep" || return 2
        _peal_init_say created "$dir/$d/.gitkeep"
      fi
    done
    if [ -e "$dir/TEMPLATE.md" ]; then
      _peal_init_say unchanged "$dir/TEMPLATE.md" "the project's own is kept"
    else
      _peal_init_put "$dir/TEMPLATE.md" "$PEAL_ROOT/templates/task.md" || return 2
    fi
  fi
  _peal_init_settings_add || status=$?
  _peal_init_record add tasks || return 2
  return $status
}

_peal_init_tasks_remove() {
  local other dir d status=0
  for other in guardrails milestones belfry; do
    if _peal_init_has "$other"; then
      peal_err "init: remove the $other stage first (peal init --remove $other)"
      return 2
    fi
  done
  if [ -f "$PEAL_CONFIG_FILE" ]; then
    peal_config_load || return 2
    dir=$(peal_config_get tasks) || return 2
    dir=${dir%/}
    _peal_init_rm "$dir/TEMPLATE.md"
    for d in backlog doing "done"; do
      _peal_init_rm "$dir/$d/.gitkeep"
      _peal_init_rmdir "$dir/$d"
    done
    _peal_init_rmdir "$dir"
    [ ! -d "$dir" ] || _peal_init_say kept "$dir/" "it holds tasks"
  fi
  _peal_init_settings_remove || status=$?
  if [ -f "$PEAL_CONFIG_FILE" ]; then
    if awk -v key=storage -v op=has -f "$PEAL_ROOT/lib/config-block.awk" "$PEAL_CONFIG_FILE"; then
      _peal_init_block storage || return 2
      _peal_init_say updated "$PEAL_CONFIG_FILE" "storage removed"
    fi
    _peal_init_record remove tasks || return 2
    if awk -v op=active -f "$PEAL_ROOT/lib/config-block.awk" "$PEAL_CONFIG_FILE"; then
      _peal_init_say kept "$PEAL_CONFIG_FILE" "it holds the project's settings"
    else
      _peal_init_rm "$PEAL_CONFIG_FILE"
    fi
  fi
  _peal_init_rm .peal/peal
  _peal_init_rmdir .peal
  rm -f "$(git rev-parse --git-common-dir)/$PEAL_ROOT_RECORD"
  return $status
}

_peal_init_guardrails() {
  peal_hooks_install || return 2
  _peal_init_record add guardrails
}

_peal_init_guardrails_remove() {
  peal_hooks_uninstall || return 2
  _peal_init_record remove guardrails
}

# _peal_init_milestone_text TITLE -> the first milestone's file.
_peal_init_milestone_text() {
  cat <<EOF
---
state: current
order: 1
---

# $1

## Goal

What this milestone delivers, in a paragraph.

## Acceptance criteria

- A checkable statement the milestone review walks through.
EOF
}

_peal_init_milestones() {
  local title=$1 dir tmp status=0
  if [ "$(peal_config_get storage.kind)" = issues ]; then
    _peal_init_say unchanged "the milestones" "the repository's milestones on GitHub"
  else
    peal_ms_load || return 2
    dir=$(peal_config_get milestones) || return 2
    dir=${dir%/}
    if [ -n "$PEAL_MILESTONES" ]; then
      _peal_init_say unchanged "$dir/" "it holds milestones"
    else
      tmp=$(mktemp) || return 2
      _peal_init_milestone_text "${title:-First milestone}" >"$tmp"
      _peal_init_put "$dir/m1.md" "$tmp" || status=2
      rm -f "$tmp"
      [ $status -eq 0 ] || return 2
    fi
  fi
  _peal_init_record add milestones
}

# The first milestone's file goes only while it is still as the stage wrote it.
_peal_init_milestones_remove() {
  local dir file title
  if [ "$(peal_config_get storage.kind)" != issues ]; then
    dir=$(peal_config_get milestones) || return 2
    dir=${dir%/}
    file=$dir/m1.md
    if [ -f "$file" ]; then
      title=$(sed -n 's/^# //p' "$file" | head -n1)
      if [ "$(_peal_init_milestone_text "$title")" = "$(cat "$file")" ]; then
        _peal_init_rm "$file"
        _peal_init_rmdir "$dir"
      else
        _peal_init_say kept "$file" "it was written since"
      fi
    fi
  fi
  _peal_init_record remove milestones
}

# _peal_init_belfry_text -> the .belfry.yml for the storage configured.
_peal_init_belfry_text() {
  local label
  echo "# Belfry's contract for this project, written by peal init --stage belfry."
  if [ "$(peal_config_get storage.kind)" = issues ]; then
    label=$(peal_config_get storage.issues.label) || return 2
    cat <<'EOF'
tasks:
  backend: github-issues
  github-issues:
EOF
    [ -z "$label" ] || printf '    label: %s\n' "$(_peal_init_quote "$label")"
    cat <<'EOF'
    start: /peal:work {task}
    idea: /peal:idea {idea}
EOF
  else
    cat <<'EOF'
tasks:
  backend: commands
  commands:
    list: .peal/peal list
    offer: .peal/peal offer "{pool}" --top 10
    pool: current,unassigned
    claim: .peal/peal claim {task} --print-path
    start: /peal:work {task}
    idea: /peal:idea {idea}
    board: .peal/peal board
    milestone: .peal/peal milestone-state {id} {state} --reason {reason}
    retire: .peal/peal retire {task} --reason {reason}
EOF
  fi
  cat <<'EOF'
# The actions Peal provides, as suggestions: uncomment those Belfry should offer.
# actions:
#   milestone-review:
#     title: Milestone review
#     prompt: /peal:milestone-review {milestone}
#     triggers: [milestone]
#   release:
#     title: Release
#     prompt: /peal:release
#     triggers: [button]
#     single: true
#     release: true
EOF
}

_peal_init_belfry() {
  local tmp status=0
  tmp=$(mktemp) || return 2
  _peal_init_belfry_text >"$tmp" || { rm -f "$tmp"; return 2; }
  if [ -e .belfry.yml ] && ! cmp -s "$tmp" .belfry.yml; then
    echo ".belfry.yml exists and is not Peal's; the contract Peal would write:"
    cat "$tmp"
    rm -f "$tmp"
    return 1
  fi
  _peal_init_put .belfry.yml "$tmp" || status=2
  rm -f "$tmp"
  [ $status -eq 0 ] || return 2
  echo "skipped the check: belfry check is not available yet"
  _peal_init_record add belfry
}

_peal_init_belfry_remove() {
  local tmp status=0
  if [ -e .belfry.yml ]; then
    tmp=$(mktemp) || return 2
    _peal_init_belfry_text >"$tmp" || status=2
    if [ $status -eq 0 ] && ! cmp -s "$tmp" .belfry.yml; then
      echo ".belfry.yml was changed since peal init wrote it; remove it yourself, then run this again"
      status=1
    fi
    rm -f "$tmp"
    [ $status -eq 0 ] || return $status
    _peal_init_rm .belfry.yml
  fi
  _peal_init_record remove belfry
}

# --- the survey ------------------------------------------------------------------------

# _peal_init_survey_gh WHAT ARGS... -> `WHAT N` from `gh api ARGS` printing N, else
# `WHAT unknown: why`.
_peal_init_survey_gh() {
  local what=$1 n err
  shift
  err=$(mktemp) || return 2
  if n=$(peal_gh "$@" 2>"$err") && [[ "$n" =~ ^[0-9]+$ ]]; then
    printf '%s %s\n' "$what" "$n"
  else
    printf '%s unknown: %s\n' "$what" "$(sed 's/^peal: //' "$err" | tr '\n' ' ' | sed 's/ $//')"
  fi
  rm -f "$err"
}

# _peal_init_list WORDS... -> WORDS joined by commas, or - for none.
_peal_init_list() {
  local IFS=,
  if [ $# -eq 0 ]; then echo -; else printf '%s\n' "$*"; fi
}

# peal_init_survey -> what /peal:setup decides from, one "key value" line each, writing
# nothing:
#   stages      the stages set up (comma list, - for none)
#   next        the first stage not set up, - when all are
#   storage     the storage set up, - before the tasks stage
#   branch      the branch checked out (- when detached), then "main" and the main branch
#   github      owner/name of the project's GitHub repository, - for none
#   issues      its open issues (not pull requests), 100 meaning 100 or more
#   milestones  its open milestones
#   closes      of the last 200 commits, those whose message closes an issue (fixes #N)
#   readme      the README, - for none
#   todo        TODO lists (files named todo, at the top or in docs/), - for none
#   todo-marks  TODO and FIXME marks in the tracked files
#   ci          the CI configuration files, - for none
#   taskdir     the tasks directory before the tasks stage and how many files it holds
#   belfry      .belfry.yml: peal (the one peal init writes), other, or -
#   recommend   the storage to recommend: the one set up; else issues when the project
#               is on GitHub and already has open issues or commits closing some; else files
# issues and milestones are "unknown: why" when gh cannot tell (not installed, logged
# out); both are left out without a GitHub repository.
peal_init_survey() {
  local stages s next=- storage=- branch main repo issues=0 closes readme f dir tasks n
  local -a found
  stages=$(_peal_init_stages) || return 2
  for s in $PEAL_INIT_STAGES; do
    if ! printf '%s\n' "$stages" | grep -qx -- "$s"; then
      next=$s
      break
    fi
  done
  # shellcheck disable=SC2086 # one stage per word
  echo "stages $(_peal_init_list $stages)"
  echo "next $next"
  if printf '%s\n' "$stages" | grep -qx tasks; then
    storage=$(peal_config_get storage.kind) || return 2
  fi
  echo "storage $storage"
  main=$(peal_config_get main) || return 2
  branch=$(git symbolic-ref -q --short HEAD) || branch=-
  echo "branch $branch main $main"

  repo=$(peal_config_get storage.issues.repo) || return 2
  [ -n "$repo" ] || repo=$(peal_github_repo_of "$(git remote get-url "$(peal_config_get remote)" 2>/dev/null)") || repo=""
  echo "github ${repo:--}"
  if [ -n "$repo" ]; then
    issues=$(_peal_init_survey_gh issues "repos/$repo/issues?state=open&per_page=100" \
      --jq '[.[] | select(.pull_request == null)] | length') || return 2
    echo "$issues"
    _peal_init_survey_gh milestones "repos/$repo/milestones?state=open&per_page=100" \
      --jq '[.[] | select(.state == "open")] | length' || return 2
  fi
  closes=$(git log -n 200 --format='%B%x00' 2>/dev/null | tr '\n' ' ' | tr '\0' '\n' \
    | grep -c -i -E '(close[sd]?|fix(e[sd])?|resolve[sd]?):? +([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+')
  echo "closes $closes"

  readme=-
  for f in README.md README README.rst README.txt README.adoc readme.md Readme.md; do
    if [ -f "$f" ]; then readme=$f; break; fi
  done
  echo "readme $readme"
  found=()
  for dir in . docs; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*; do
      [ -f "$f" ] || continue
      case $(basename "$f" | tr '[:upper:]' '[:lower:]') in
        todo | todo.* | todos | todos.*) found+=("${f#./}") ;;
      esac
    done
  done
  echo "todo $(_peal_init_list ${found[@]+"${found[@]}"})"
  n=$(git grep -I -E -w 'TODO|FIXME' -- . 2>/dev/null | wc -l | tr -d ' ')
  echo "todo-marks $n"
  found=()
  for f in .github/workflows/*.yml .github/workflows/*.yaml .gitlab-ci.yml .circleci/config.yml \
      .travis.yml Jenkinsfile azure-pipelines.yml .woodpecker.yml bitbucket-pipelines.yml; do
    [ -f "$f" ] && found+=("$f")
  done
  echo "ci $(_peal_init_list ${found[@]+"${found[@]}"})"

  tasks=$(peal_config_get tasks) || return 2
  tasks=${tasks%/}
  if [ "$storage" = - ] && [ -d "$tasks" ]; then
    echo "taskdir $tasks/ $(find "$tasks" -type f | wc -l | tr -d ' ')"
  else
    echo "taskdir -"
  fi
  if [ ! -e .belfry.yml ]; then
    echo "belfry -"
  elif head -n 1 .belfry.yml | grep -q 'written by peal init'; then
    echo "belfry peal"
  else
    echo "belfry other"
  fi

  if [ "$storage" != - ]; then
    echo "recommend $storage"
  elif [ -n "$repo" ] && { [[ "$issues" =~ ^issues\ [1-9] ]] || [ "$closes" -gt 0 ]; }; then
    echo "recommend issues"
  else
    echo "recommend files"
  fi
}

# peal_init --survey
# peal_init --stage STAGE [--storage files|issues] [--label L] [--title T]
# peal_init --remove STAGE
peal_init() {
  local action="" stage="" storage="" label="" label_given="" title="" top
  if [ "${1-}" = --survey ]; then
    [ $# -eq 1 ] || { peal_err "init: --survey takes no arguments"; return 2; }
    top=$(peal_project_root) || return 2
    cd "$top" || return 2
    peal_config_load || return 2
    peal_init_survey
    return
  fi
  while [ $# -gt 0 ]; do
    case $1 in
      --stage | --remove)
        if [ $# -lt 2 ] || [ -n "$action" ]; then
          peal_err "init: one --stage STAGE or --remove STAGE"
          return 2
        fi
        action=${1#--} stage=$2
        shift
        ;;
      --storage)
        [ $# -ge 2 ] || { peal_err "init: --storage files|issues"; return 2; }
        case $2 in files | issues) storage=$2 ;; *) peal_err "init: --storage files|issues"; return 2 ;; esac
        shift
        ;;
      --label)
        [ $# -ge 2 ] || { peal_err "init: --label needs a label"; return 2; }
        label=$2 label_given=1
        shift
        ;;
      --title)
        [ $# -ge 2 ] || { peal_err "init: --title needs a title"; return 2; }
        title=$2
        shift
        ;;
      *) peal_err "init: unknown argument $1"; return 2 ;;
    esac
    shift
  done
  if [ -z "$action" ]; then
    peal_err "init: --stage STAGE or --remove STAGE, STAGE one of: $PEAL_INIT_STAGES"
    return 2
  fi
  if [[ " $PEAL_INIT_STAGES " != *" $stage "* ]]; then
    peal_err "init: '$stage' is not a stage; one of: $PEAL_INIT_STAGES"
    return 2
  fi
  if { [ -n "$storage" ] || [ -n "$label_given" ]; } && [ "$action$stage" != stagetasks ]; then
    peal_err "init: --storage and --label are for --stage tasks"
    return 2
  fi
  if [ -n "$title" ] && [ "$action$stage" != stagemilestones ]; then
    peal_err "init: --title is for --stage milestones"
    return 2
  fi
  if [[ "$label$title" == *$'\n'* ]]; then
    peal_err "init: a label or title is one line"
    return 2
  fi
  top=$(peal_project_root) || return 2
  cd "$top" || return 2
  peal_config_load || return 2
  if [ "$action" = stage ] && [ "$stage" != tasks ] && ! _peal_init_has tasks; then
    peal_err "init: set up the tasks stage first (peal init --stage tasks)"
    return 2
  fi
  case $action$stage in
    stagetasks) _peal_init_tasks "$storage" "$label" "$label_given" ;;
    stagemilestones) _peal_init_milestones "$title" ;;
    stage*) "_peal_init_$stage" ;;
    remove*) "_peal_init_${stage}_remove" ;;
  esac
}
