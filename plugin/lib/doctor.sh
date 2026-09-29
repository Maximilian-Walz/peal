# shellcheck shell=bash
# peal doctor (docs/reference/cli.md, "peal doctor"): when Peal does not work in a project,
# nobody should have to guess why. One function per check, all reporting through
# _peal_doctor_ok/_peal_doctor_fail/_peal_doctor_skip: "ok/FAIL/skip <check>: <sentence>",
# a FAIL followed by "  fix: <what to run>", a last "doctor: N problem(s)" line.
#
# Order: config first (its own findings, then its value checks); its failure makes every
# check that needs it say "skip: the config does not load". Then version (also computes
# whether .peal/peal matches the launcher template, which belfry needs, even when version
# itself is not selected), hooks (only when guardrails is a stage), gh (only for the
# issues storage; its readiness is remembered for claims), claims (skipped when gh failed
# on the issues storage), belfry (only with a .belfry.yml of the commands backend).
#
# Reads local refs only: peal_store_list and peal_store_claim_worktrees are never called
# with --fetch, so a claim that landed here but was never fetched passes silently
# (accepted, 0036's A7). gh auth status and the Belfry commands run under a timeout.

PEAL_DOCTOR_CHECKS="config version hooks gh claims belfry"
PEAL_DOCTOR_TIMEOUT=30
PEAL_DOCTOR_SEP=$(printf '\036')
PEAL_DOCTOR_US=$(printf '\037')

_peal_doctor_ok() {
  printf 'ok %s: %s\n' "$1" "$2"
}

# _peal_doctor_fail CHECK SENTENCE FIX -> the FAIL line, its fix, and the count bumped.
_peal_doctor_fail() {
  printf 'FAIL %s: %s\n' "$1" "$2"
  printf '  fix: %s\n' "$3"
  _peal_doctor_n=$((_peal_doctor_n + 1))
}

_peal_doctor_skip() {
  printf 'skip %s: %s\n' "$1" "$2"
}

# _peal_doctor_wants CHECK -> status 0 if CHECK was asked for (peal_doctor's selection).
_peal_doctor_wants() {
  printf '%s\n' "$_peal_doctor_selected" | grep -qx "$1"
}

# _peal_doctor_stage_config -> peal_config_load's own refusal as the sentence ("edit
# .peal/config.yml line N" its fix), else, once it loads, the values peal_config_load and
# peal check do not check themselves (0036's A5): storage.kind, main-writes, sizes.S/M/L,
# each of stages, release.wait-ci, models.*. Sets _peal_doctor_config_ok.
_peal_doctor_stage_config() {
  local out status name line msg fix errfile
  # peal_config_load sets PEAL_CONFIG in this shell, so it must not run inside a
  # command substitution (a subshell): its stderr is captured through a temp file.
  errfile=$(mktemp) || return 2
  peal_config_load 2>"$errfile"
  status=$?
  out=$(cat "$errfile")
  rm -f "$errfile"
  if [ "$status" -ne 0 ]; then
    _peal_doctor_config_ok=0
    _peal_doctor_wants config || return 0
    if [[ "$out" =~ ^peal:\ ([^:]+):([0-9]+):\ (.*)$ ]]; then
      name=${BASH_REMATCH[1]}
      line=${BASH_REMATCH[2]}
      msg=${BASH_REMATCH[3]}
      if [ "$name" = "$PEAL_CONFIG_FILE" ]; then
        fix="edit $PEAL_CONFIG_FILE line $line"
      else
        fix="edit $PEAL_CONFIG_FILE"
      fi
    else
      msg=${out#peal: }
      fix="edit $PEAL_CONFIG_FILE"
    fi
    [ -n "$msg" ] || msg="$PEAL_CONFIG_FILE does not load"
    _peal_doctor_fail config "$msg" "$fix"
    return 0
  fi
  _peal_doctor_config_ok=1
  _peal_doctor_wants config || return 0
  local before=$_peal_doctor_n v k stage
  v=$(peal_config_get storage.kind 2>/dev/null)
  case $v in
    files | issues) ;;
    *) _peal_doctor_fail config "storage.kind is '$v', not files or issues" "edit $PEAL_CONFIG_FILE" ;;
  esac
  v=$(peal_config_get main-writes 2>/dev/null)
  case $v in
    push | pr | auto) ;;
    *) _peal_doctor_fail config "main-writes is '$v', not push, pr or auto" "edit $PEAL_CONFIG_FILE" ;;
  esac
  for k in S M L; do
    v=$(peal_config_get "sizes.$k" 2>/dev/null)
    [[ "$v" =~ ^[1-9][0-9]*$ ]] || _peal_doctor_fail config "sizes.$k is '$v', not a positive integer" "edit $PEAL_CONFIG_FILE"
  done
  while IFS= read -r stage; do
    [ -n "$stage" ] || continue
    case $stage in
      tasks | guardrails | milestones | belfry) ;;
      *) _peal_doctor_fail config "stages has '$stage', not tasks, guardrails, milestones or belfry" "edit $PEAL_CONFIG_FILE" ;;
    esac
  done < <(peal_config_get stages 2>/dev/null)
  v=$(peal_config_get release.wait-ci 2>/dev/null)
  case $v in
    true | false) ;;
    *) _peal_doctor_fail config "release.wait-ci is '$v', not true or false" "edit $PEAL_CONFIG_FILE" ;;
  esac
  for k in planner reviewer implementer; do
    v=$(peal_config_get "models.$k" 2>/dev/null)
    [ -n "$v" ] || _peal_doctor_fail config "models.$k is empty" "edit $PEAL_CONFIG_FILE"
  done
  [ "$_peal_doctor_n" -gt "$before" ] || _peal_doctor_ok config "the effective settings load and are valid"
}

# _peal_doctor_stage_version -> always sets _peal_doctor_launcher_ok (byte-identical to
# templates/launcher), which belfry needs even when version is not selected; once
# selected, (a) that comparison itself, (b) once (a) holds, the resolved version
# (env -u PEAL_ROOT .peal/peal --version) against this session's.
_peal_doctor_stage_version() {
  _peal_doctor_launcher_exists=0
  _peal_doctor_launcher_ok=0
  if [ -f .peal/peal ]; then
    _peal_doctor_launcher_exists=1
    cmp -s .peal/peal "$PEAL_ROOT/templates/launcher" && _peal_doctor_launcher_ok=1
  fi
  _peal_doctor_wants version || return 0
  if [ "$_peal_doctor_launcher_exists" = 0 ]; then
    if [ "$_peal_doctor_config_ok" = 1 ] && printf '%s\n' "$(peal_config_get stages 2>/dev/null)" | grep -qx tasks; then
      _peal_doctor_fail version "no .peal/peal here, though tasks is a stage" ".peal/peal init --stage tasks, then commit .peal/peal"
    else
      _peal_doctor_skip version "no .peal/peal here to check"
    fi
    return 0
  fi
  if [ "$_peal_doctor_launcher_ok" = 1 ]; then
    _peal_doctor_ok version ".peal/peal matches the plugin's launcher template"
  else
    _peal_doctor_fail version ".peal/peal does not match the plugin's launcher template" ".peal/peal init --stage tasks, then commit .peal/peal"
    return 0
  fi
  local out status running
  running=$(peal_version)
  out=$(env -u PEAL_ROOT .peal/peal --version 2>&1)
  status=$?
  if [ "$status" -ne 0 ]; then
    _peal_doctor_fail version "env -u PEAL_ROOT .peal/peal --version found no installed Peal: $(printf '%s' "$out" | tr '\n' ' ')" \
      "install the plugin: claude plugin marketplace add Maximilian-Walz/peal; claude plugin install peal@peal"
  elif [ "$out" != "$running" ]; then
    _peal_doctor_fail version "the installed Peal ($out) is not the one running this session ($running)" \
      "start a fresh Claude Code session, or .peal/peal hooks install"
  else
    _peal_doctor_ok version "the installed Peal ($out) matches the running session"
  fi
}

# _peal_doctor_stage_hooks -> only when guardrails is a stage: core.hooksPath set to
# Peal's stubs, each of PEAL_GITHOOKS present, executable and matching templates/githook.
_peal_doctor_stage_hooks() {
  _peal_doctor_wants hooks || return 0
  if [ "$_peal_doctor_config_ok" != 1 ]; then
    _peal_doctor_skip hooks "the config does not load"
    return 0
  fi
  if ! printf '%s\n' "$(peal_config_get stages 2>/dev/null)" | grep -qx guardrails; then
    _peal_doctor_skip hooks "guardrails is not a stage here"
    return 0
  fi
  local dir prev
  dir=$(_peal_hooks_dir 2>/dev/null) || { _peal_doctor_fail hooks "not inside a git repository" ".peal/peal hooks install"; return 0; }
  prev=$(git config core.hooksPath 2>/dev/null) || prev=""
  if [ -z "$prev" ]; then
    _peal_doctor_fail hooks "core.hooksPath is not set; Peal's git gates do not run" ".peal/peal hooks install"
    return 0
  fi
  if [ "$prev" != "$dir" ]; then
    _peal_doctor_fail hooks "core.hooksPath is $prev, not Peal's stubs" ".peal/peal hooks install, which chains to it"
    return 0
  fi
  local name missing="" stale=""
  for name in $PEAL_GITHOOKS; do
    if [ ! -x "$dir/$name" ]; then
      missing="$missing $name"
    elif ! cmp -s "$dir/$name" "$PEAL_ROOT/templates/githook"; then
      stale="$stale $name"
    fi
  done
  if [ -n "$missing" ]; then
    _peal_doctor_fail hooks "missing or not executable:$missing" ".peal/peal hooks install"
    return 0
  fi
  if [ -n "$stale" ]; then
    _peal_doctor_fail hooks "stale, not the plugin's current stub:$stale" ".peal/peal hooks install"
    return 0
  fi
  _peal_doctor_ok hooks "Peal's git gates are installed"
}

# _peal_doctor_stage_gh -> only for storage.kind issues: gh installed and gh auth status.
# Always sets _peal_doctor_gh_ok (1 when gh does not apply or is fine), which claims uses
# even when gh itself is not selected.
_peal_doctor_stage_gh() {
  _peal_doctor_gh_ok=1
  if [ "$_peal_doctor_config_ok" != 1 ]; then
    _peal_doctor_wants gh && _peal_doctor_skip gh "the config does not load"
    return 0
  fi
  local kind
  kind=$(peal_config_get storage.kind 2>/dev/null)
  if [ "$kind" != issues ]; then
    _peal_doctor_wants gh && _peal_doctor_skip gh "storage.kind is $kind, not issues"
    return 0
  fi
  if ! command -v gh >/dev/null 2>&1; then
    _peal_doctor_gh_ok=0
    _peal_doctor_wants gh && _peal_doctor_fail gh "gh is not installed" "install the GitHub CLI (https://cli.github.com)"
    return 0
  fi
  local out status
  if command -v timeout >/dev/null 2>&1; then
    out=$(timeout "$PEAL_DOCTOR_TIMEOUT" gh auth status 2>&1)
  else
    out=$(gh auth status 2>&1)
  fi
  status=$?
  if [ "$status" -ne 0 ]; then
    _peal_doctor_gh_ok=0
    _peal_doctor_wants gh && _peal_doctor_fail gh "gh is not logged in: $(printf '%s' "$out" | tr '\n' ' ' | sed 's/ *$//')" "gh auth login"
    return 0
  fi
  _peal_doctor_wants gh && _peal_doctor_ok gh "gh is installed and logged in"
}

# _peal_doctor_stage_claims -> every claim worktree here that could be released (verdict
# ok or deferred), landed with a dirty or unpushed worktree, or that git lists as
# prunable (0036's A2: not a live claim, a close sentinel, or refs/reaped/*).
_peal_doctor_stage_claims() {
  _peal_doctor_wants claims || return 0
  if [ "$_peal_doctor_config_ok" != 1 ]; then
    _peal_doctor_skip claims "the config does not load"
    return 0
  fi
  local kind
  kind=$(peal_config_get storage.kind 2>/dev/null)
  if [ "$kind" = issues ] && [ "$_peal_doctor_gh_ok" != 1 ]; then
    _peal_doctor_skip claims "gh is not ready for the issues storage"
    return 0
  fi
  if ! peal_store_load 2>/dev/null; then
    _peal_doctor_fail claims "the task storage does not load" "check storage.kind in $PEAL_CONFIG_FILE"
    return 0
  fi
  local before=$_peal_doctor_n records id branch path state verdict
  records=$(peal_store_list --no-pr 2>/dev/null)
  while IFS="$(printf '\t')" read -r id branch path; do
    [ -n "$id" ] || continue
    state=$(printf '%s\n' "$records" | awk -F '\t' -v id="$id" '!f && $1 == id { print $2; f = 1 }')
    verdict=$(peal_release_verdict "$id" "$branch" "$path" "$state")
    case $verdict in
      ok | deferred)
        _peal_doctor_fail claims "task $id's claim could be released ($verdict)" ".peal/peal release $id" ;;
      dirty | unpushed)
        _peal_doctor_fail claims "task $id landed, but $(_peal_verdict_words "$verdict" "$id")" \
          "commit and push, or discard, in $path, then .peal/peal release $id" ;;
    esac
  done < <(peal_store_claim_worktrees 2>/dev/null)
  local prunable p
  prunable=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / { p = substr($0, 10) } /^prunable/ { print p }')
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    _peal_doctor_fail claims "the worktree at $p is prunable" "git worktree prune"
  done <<<"$prunable"
  [ "$_peal_doctor_n" -gt "$before" ] || _peal_doctor_ok claims "no claim to release and no prunable worktree"
}

# _peal_doctor_words CMD -> PEAL_DOCTOR_WORDS, the words of CMD's first simple command
# (lib/shell-words.awk; the same split the git guard uses), never bash -c or eval.
_peal_doctor_words() {
  local seg
  PEAL_DOCTOR_WORDS=()
  while IFS= read -r -d "$PEAL_DOCTOR_SEP" seg; do
    IFS=$PEAL_DOCTOR_US read -r -d '' -a PEAL_DOCTOR_WORDS < <(printf '%s' "$seg")
    break
  done < <(printf '%s' "$1" | awk -f "$PEAL_ROOT/lib/shell-words.awk")
}

# _peal_doctor_shape_list/_board/_offer OUTPUT -> status 0 if every non-empty line of
# OUTPUT is the shape Belfry's contract promises (docs/design.md, "Peal and Belfry").
_peal_doctor_shape_list() {
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # shellcheck disable=SC2086 # splitting the line into its fields on purpose
    set -- $line
    [ $# -ge 3 ] || return 1
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
  done <<<"$1"
  return 0
}

_peal_doctor_shape_board() {
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case $line in '{'*) ;; *) return 1 ;; esac
  done <<<"$1"
  return 0
}

_peal_doctor_shape_offer() {
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case $line in 'CANDIDATE '* | 'MORE '*) ;; *) return 1 ;; esac
  done <<<"$1"
  return 0
}

# _peal_doctor_belfry_run NAME CMD SHAPEFN -> CMD, once its words are exactly
# ".peal/peal NAME ...", run through the launcher (PEAL_ROOT unset) when it matched the
# template, else through $PEAL_ROOT/bin/peal with the same arguments, under a timeout;
# its exit status and SHAPEFN judge it. Anything else (no command set, or not literally
# Peal's) is skip, never run.
_peal_doctor_belfry_run() {
  local name=$1 cmd=$2 shapefn=$3
  if [ -z "$cmd" ]; then
    _peal_doctor_skip "belfry.$name" "tasks.commands.$name is not set in .belfry.yml"
    return 0
  fi
  _peal_doctor_words "$cmd"
  if [ "${PEAL_DOCTOR_WORDS[0]-}" != ".peal/peal" ] || [ "${PEAL_DOCTOR_WORDS[1]-}" != "$name" ]; then
    _peal_doctor_skip "belfry.$name" "not Peal's command, not run"
    return 0
  fi
  local args=("${PEAL_DOCTOR_WORDS[@]:2}") out status
  if [ "$_peal_doctor_launcher_ok" = 1 ]; then
    if command -v timeout >/dev/null 2>&1; then
      out=$(env -u PEAL_ROOT timeout "$PEAL_DOCTOR_TIMEOUT" .peal/peal "$name" "${args[@]}" 2>&1)
    else
      out=$(env -u PEAL_ROOT .peal/peal "$name" "${args[@]}" 2>&1)
    fi
  else
    if command -v timeout >/dev/null 2>&1; then
      out=$(timeout "$PEAL_DOCTOR_TIMEOUT" "$PEAL_ROOT/bin/peal" "$name" "${args[@]}" 2>&1)
    else
      out=$("$PEAL_ROOT/bin/peal" "$name" "${args[@]}" 2>&1)
    fi
  fi
  status=$?
  if [ "$status" -ne 0 ]; then
    _peal_doctor_fail "belfry.$name" "$cmd failed (status $status): $(printf '%s' "$out" | tr '\n' ' ' | head -c 200)" \
      ".peal/peal init --stage belfry, or run $cmd by hand"
    return 0
  fi
  if ! "$shapefn" "$out"; then
    _peal_doctor_fail "belfry.$name" "$cmd did not print the shape Belfry expects" \
      ".peal/peal init --stage belfry, or run $cmd by hand"
    return 0
  fi
  _peal_doctor_ok "belfry.$name" "$cmd answers correctly"
}

# _peal_doctor_stage_belfry -> only with a .belfry.yml whose tasks.backend is commands:
# list, board and offer (0036's A6), never the write commands.
_peal_doctor_stage_belfry() {
  _peal_doctor_wants belfry || return 0
  if [ ! -f .belfry.yml ]; then
    _peal_doctor_skip belfry "no .belfry.yml here"
    return 0
  fi
  local section records backend
  # Only tasks: is Peal's; a project may add sections of its own (docs:, policy:, ...)
  # in constructs outside Peal's YAML subset (lists of maps, say), which must not make
  # this check refuse a working .belfry.yml over ground it does not read.
  section=$(awk '
    /^tasks:/ { on = 1; print; next }
    on && /^[^ \t#]/ { exit }
    on { print }
  ' .belfry.yml)
  if [ -z "$section" ]; then
    _peal_doctor_fail belfry ".belfry.yml has no tasks: section" ".peal/peal init --stage belfry, or edit .belfry.yml by hand"
    return 0
  fi
  records=$(printf '%s\n' "$section" | awk -v mode=config -v name=.belfry.yml -f "$PEAL_ROOT/lib/yaml-lib.awk" -f "$PEAL_ROOT/lib/yaml-parse.awk")
  if [ -z "$records" ]; then
    _peal_doctor_fail belfry ".belfry.yml's tasks: section does not parse" ".peal/peal init --stage belfry, or edit .belfry.yml by hand"
    return 0
  fi
  backend=$(printf '%s\n' "$records" | awk -F '\t' '$1 == "tasks.backend" { print $4; exit }')
  if [ "$backend" != commands ]; then
    _peal_doctor_skip belfry "tasks.backend is '$backend', not commands"
    return 0
  fi
  local before=$_peal_doctor_n pool cmd_list cmd_board cmd_offer
  pool=$(printf '%s\n' "$records" | awk -F '\t' '$1 == "tasks.commands.pool" { print $4; exit }')
  cmd_list=$(printf '%s\n' "$records" | awk -F '\t' '$1 == "tasks.commands.list" { print $4; exit }')
  cmd_board=$(printf '%s\n' "$records" | awk -F '\t' '$1 == "tasks.commands.board" { print $4; exit }')
  cmd_offer=$(printf '%s\n' "$records" | awk -F '\t' '$1 == "tasks.commands.offer" { print $4; exit }')
  cmd_offer=${cmd_offer//\{pool\}/$pool}

  _peal_doctor_belfry_run list "$cmd_list" _peal_doctor_shape_list
  _peal_doctor_belfry_run board "$cmd_board" _peal_doctor_shape_board
  _peal_doctor_belfry_run offer "$cmd_offer" _peal_doctor_shape_offer

  [ "$_peal_doctor_n" -gt "$before" ] || _peal_doctor_ok belfry "list, board and offer answer correctly"
}

# peal_doctor [CHECK...] -> ok/FAIL/skip lines, a fix under each FAIL, then
# "doctor: N problem(s)"; status 0 healthy, 1 with any problem, 2 for an unknown CHECK,
# outside a git repository, or a project without .peal/.
peal_doctor() {
  local c top
  _peal_doctor_selected=""
  for c in "$@"; do
    # shellcheck disable=SC2086 # PEAL_DOCTOR_CHECKS is several words, one per line wanted
    if ! printf '%s\n' $PEAL_DOCTOR_CHECKS | grep -qx "$c"; then
      peal_err "doctor: no check '$c' ($PEAL_DOCTOR_CHECKS)"
      return 2
    fi
    _peal_doctor_selected="$_peal_doctor_selected$c
"
  done
  # shellcheck disable=SC2086 # PEAL_DOCTOR_CHECKS is several words, one per line wanted
  [ -n "$_peal_doctor_selected" ] || _peal_doctor_selected=$(printf '%s\n' $PEAL_DOCTOR_CHECKS)

  top=$(peal_project_root) || return 2
  cd "$top" || return 2
  [ -d .peal ] || { peal_err "doctor: no .peal/ here; this is not a Peal project"; return 2; }

  _peal_doctor_n=0
  _peal_doctor_config_ok=0
  _peal_doctor_gh_ok=1

  _peal_doctor_stage_config
  _peal_doctor_stage_version
  _peal_doctor_stage_hooks
  _peal_doctor_stage_gh
  _peal_doctor_stage_claims
  _peal_doctor_stage_belfry

  echo "doctor: $_peal_doctor_n problem(s)"
  [ "$_peal_doctor_n" -eq 0 ]
}
