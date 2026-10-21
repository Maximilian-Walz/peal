# shellcheck shell=bash
# The session: where Peal is installed, and the Claude Code hooks around a task's session.
#
# Where Peal is installed, for callers outside Claude Code: the SessionStart hook records
# the running plugin's root in the repository's git directory, where the launcher
# (templates/launcher) looks before falling back to Claude Code's plugin cache.

PEAL_ROOT_RECORD=peal-root

# peal_repo_holds REPO PATH -> status 0 if PATH lies inside git repository REPO: in one of
# its worktrees or its git directory, compared as physical paths. The same test the
# launcher and the git hooks make before they run a Peal (templates/launcher).
peal_repo_holds() {
  local path dir line common
  path=$(cd "$2" 2>/dev/null && pwd -P) || path=$2
  common=$(cd "$1" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd -P) 2>/dev/null
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    dir=$(cd "$dir" 2>/dev/null && pwd -P) || continue
    case "${path%/}/" in "${dir%/}/"*) return 0 ;; esac
  done <<EOF
$(git -C "$1" worktree list --porcelain 2>/dev/null | while IFS= read -r line; do
    case $line in ("worktree "*) printf '%s\n' "${line#worktree }" ;; esac
  done)
$common
EOF
  return 1
}

# _peal_vcmp A B -> ">", "<" or "=" on stdout; "?" when either is not comparable. The same
# rule as the launcher's (templates/launcher): numeric dot fields, a -prerelease below its
# release, anything else incomparable.
_peal_vcmp() {
  awk -v a="$1" -v b="$2" '
    function parse(v, out,   i, core, pre, n, p) {
      pre = ""; core = v
      i = index(v, "-")
      if (i) { core = substr(v, 1, i - 1); pre = substr(v, i + 1); if (pre == "") return 0 }
      if (core !~ /^[0-9]+(\.[0-9]+)*$/) return 0
      if (pre != "" && pre !~ /^[0-9A-Za-z.-]+$/) return 0
      n = split(core, p, ".")
      for (i = 1; i <= n; i++) out[i] = p[i] + 0
      out["n"] = n; out["pre"] = pre
      return 1
    }
    BEGIN {
      if (!parse(a, x) || !parse(b, y)) { print "?"; exit }
      n = x["n"] > y["n"] ? x["n"] : y["n"]
      for (i = 1; i <= n; i++) {
        xi = (i in x) ? x[i] : 0; yi = (i in y) ? y[i] : 0
        if (xi > yi) { print ">"; exit }
        if (xi < yi) { print "<"; exit }
      }
      if (x["pre"] == y["pre"]) print "="
      else if (x["pre"] == "") print ">"
      else if (y["pre"] == "") print "<"
      else print "?"
    }'
}

# _peal_record_newer COMMON -> status 0 if COMMON's peal-root names a verified Peal of a
# higher version than the running plugin: a root that exists with an executable bin/peal,
# whose plugin.json names peal, lying in Claude Code's plugin cache and, when
# installed_plugins.json is there, listed by it. The launcher would run it, over this one.
_peal_record_newer() {
  local rec="" config cache real manifest version
  [ -r "$1/$PEAL_ROOT_RECORD" ] || return 1
  IFS= read -r rec <"$1/$PEAL_ROOT_RECORD"
  rec=${rec%/}
  case $rec in /*) ;; *) return 1 ;; esac
  [ -x "$rec/bin/peal" ] || return 1
  manifest=$rec/.claude-plugin/plugin.json
  [ "$(sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" 2>/dev/null | sed -n 1p)" = peal ] || return 1
  version=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" 2>/dev/null | sed -n 1p)
  [ -n "$version" ] || return 1
  config=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
  real=$(cd "$rec" && pwd -P) || return 1
  cache=$(cd "$config/plugins/cache" 2>/dev/null && pwd -P) || return 1
  case "$real/" in "$cache/"*) ;; *) return 1 ;; esac
  if [ -f "$config/plugins/installed_plugins.json" ]; then
    grep -F -e "\"$rec\"" -e "\"$rec/\"" -e "\"$real\"" "$config/plugins/installed_plugins.json" >/dev/null 2>&1 || return 1
  fi
  [ "$(_peal_vcmp "$version" "$(peal_version)")" = ">" ]
}

# peal_write_root COMMON -> PEAL_ROOT written to COMMON/peal-root, unless the record names
# a verified Peal of a higher version than this one (_peal_record_newer): a record never
# goes back to an older Peal. Status 1 if the write fails.
peal_write_root() {
  if _peal_record_newer "$1"; then
    return 0
  fi
  if printf '%s\n' "$PEAL_ROOT" >"$1/$PEAL_ROOT_RECORD.$$" 2>/dev/null; then
    mv -f "$1/$PEAL_ROOT_RECORD.$$" "$1/$PEAL_ROOT_RECORD" 2>/dev/null && return 0
  fi
  rm -f "$1/$PEAL_ROOT_RECORD.$$" 2>/dev/null
  return 1
}

# peal_gh_telemetry_env -> appends the line that keeps gh's telemetry off to Claude Code's
# CLAUDE_ENV_FILE (set for SessionStart hooks only), once, so every Bash command of the
# session, and so the gh calls an agent runs itself, inherit GH_TELEMETRY=0 unless the user
# set it. The line is literal, evaluated by the session's bash: this process already
# exported 0 (bin/peal), so it cannot see the user's value. (PowerShell skips the env
# file.) Never fails a session.
peal_gh_telemetry_env() {
  # shellcheck disable=SC2016 # the literal line, expanded in the session, not here
  local f=${CLAUDE_ENV_FILE-} line='export GH_TELEMETRY="${GH_TELEMETRY:-0}"'
  [ -n "$f" ] || return 0
  grep -qxF -- "$line" "$f" 2>/dev/null && return 0
  { printf '%s\n' "$line" >>"$f"; } 2>/dev/null || true
  return 0
}

# peal_record_root DIR -> writes PEAL_ROOT into the git directory shared by all of DIR's
# worktrees, if DIR is in a repository that uses Peal (has .peal/) and PEAL_ROOT lies
# outside it (the launcher would refuse it; said on stderr) and the record does not already
# name a verified Peal of a higher version (peal_write_root). Never fails a session: a
# missing record only makes the launcher search the cache.
peal_record_root() {
  local top common
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 0
  [ -d "$top/.peal" ] || return 0
  common=$(cd "$top" && cd "$(git rev-parse --git-common-dir)" && pwd) 2>/dev/null || return 0
  if peal_repo_holds "$top" "$PEAL_ROOT"; then
    peal_err "not recording $PEAL_ROOT as Peal's root: it lies inside this repository"
    return 0
  fi
  peal_write_root "$common"
  return 0
}

# The session hooks. Each reads the hook's JSON on stdin (peal_hook_read), acts only in a
# repository that uses Peal, and never fails a session: what goes wrong is left out.

# peal_hook_read -> PEAL_HOOK_INPUT, the hook's JSON from stdin.
peal_hook_read() {
  PEAL_HOOK_INPUT=$(cat 2>/dev/null)
}

# peal_hook_field KEY -> a top-level string of the hook's input, empty if absent.
peal_hook_field() {
  printf '%s' "$PEAL_HOOK_INPUT" | awk -v key="$1" -f "$PEAL_ROOT/lib/json-get.awk"
}

# peal_hook_project -> into the session's project (CLAUDE_PROJECT_DIR, else the working
# directory)'s top, if it uses Peal; status 1 otherwise.
peal_hook_project() {
  local top
  top=$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ -d "$top/.peal" ] || return 1
  cd "$top" || return 1
  peal_config_load 2>/dev/null
}

# peal_session_task -> the task this worktree holds, "id<TAB>file", file a copy of its
# text (the storage's peal_store_session_task; PEAL_TASK_REFRESH=1 asks for a fresh copy
# where the storage keeps one). The same check /peal:work makes; status 1 if there is
# none.
peal_session_task() {
  peal_store_session_task
}

# peal_heartbeat -> this worktree marked live (lib/claim.sh).
peal_heartbeat() {
  local gitdir
  gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null) && : >"$gitdir/peal-heartbeat"
}

# peal_turns_reset -> the turn budget of this worktree back at zero.
peal_turns_reset() {
  local gitdir
  gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null) || return 0
  printf '0\n' >"$gitdir/peal-turns"
  rm -f "$gitdir/peal-nudged"
}

# peal_session_start -> the SessionStart hook in a Peal project: a fresh clone whose
# config records the `guardrails` stage gets its git gates (peal_hooks_ensure), named in
# the orientation; the heartbeat; on a new session (source startup or clear) the turn
# budget reset, a fetch and the reaping of claims that are done with (peal_reap); then
# the orientation: the current milestone, this worktree's task, the other claims and the
# open splits.
peal_session_start() {
  local source records milestones task refresh="" hooks
  peal_hook_project || return 0
  peal_store_load 2>/dev/null || return 0
  hooks=$(peal_hooks_ensure 2>&1)
  peal_heartbeat
  source=$(peal_hook_field source)
  case $source in
    startup | clear)
      refresh=1
      peal_turns_reset
      if command -v timeout >/dev/null 2>&1; then
        timeout 15 git fetch -q "$(peal_config_get remote)" 2>/dev/null
      else
        git fetch -q "$(peal_config_get remote)" 2>/dev/null
      fi
      peal_reap 2>/dev/null
      ;;
  esac
  records=$(peal_store_list --no-pr 2>/dev/null)
  milestones=$(peal_store_milestones 2>/dev/null)
  task=$(PEAL_TASK_REFRESH=$refresh peal_session_task)
  echo "Peal:"
  [ -z "$hooks" ] || printf '%s\n' "$hooks"
  printf '%s\n' "$milestones" | awk -F '\t' '
    !found && $3 == "current" { printf "Current milestone: %s, %s (%s)\n", $1, $2, $6; found = 1 }
    END { if (!found) print "Current milestone: none" }'
  if [ -n "$task" ]; then
    printf 'Task: %s, %s: this worktree'\''s task and this session'\''s whole scope. Read it first.\n' \
      "$(_peal_field "$task" 1)" "$(_peal_field "$task" 2)"
  else
    echo "Task: none in this worktree. /peal:work claims one into a worktree of its own."
  fi
  if [ -n "$records" ]; then
    printf '%s\n' "$records" | awk -F '\t' -v own="$(_peal_field "$task" 1)" '
      $1 != own && ($2 == "claimed-live" || $2 == "parked" || $2 == "awaiting-merge") {
        if (!n++) print "Other claims:"
        print "  " $1, $2, $4 ($3 == "" ? "" : " " $3)
      }'
    printf '%s\n' "$records" | _peal_open_splits
  fi
  if [ -z "$task" ] && { [ "$source" = startup ] || [ "$source" = clear ]; }; then
    peal_next_hint "$records" "$milestones" 2>/dev/null
  fi
  return 0
}

# _peal_open_splits -> for the list records on stdin, each split with a piece not done:
# "  ORIGIN Title: D/T done, open: ID state, ..." under "Open splits:". A piece of a
# piece counts toward the first origin.
_peal_open_splits() {
  awk -F '\t' '
    { order[++n] = $1; state[$1] = $2; title[$1] = $5; parent[$1] = $8 }
    END {
      for (i = 1; i <= n; i++) {
        id = order[i]; root = id; steps = 0
        while (parent[root] != "" && (parent[root] in state) && steps++ < n) root = parent[root]
        if (root == id) continue
        members[root] = members[root] "," id
      }
      for (i = 1; i <= n; i++) {
        root = order[i]
        if (!(root in members)) continue
        m = split(root members[root], ids, ",")
        done = 0; open = ""
        for (j = 1; j <= m; j++) {
          if (state[ids[j]] == "done") done++
          else open = open (open == "" ? "" : ", ") ids[j] " " state[ids[j]]
        }
        if (open == "") continue
        if (!shown++) print "Open splits:"
        printf "  %s %s: %d/%d done, open: %s\n", root, title[root], done, m, open
      }
    }'
}

# peal_turn_budget -> the PostToolUse hook: the heartbeat, and for the main session (not a
# subagent) in a task's worktree one more tool call counted. Once the count reaches the
# task's size tier (the sizes setting; M for a task not sized yet), a nudge on stderr and
# status 2, which Claude Code shows the session.
peal_turn_budget() {
  local task gitdir count size tier
  peal_hook_project || return 0
  peal_heartbeat
  [ -z "$(peal_hook_field agent_id)" ] || return 0
  peal_store_load 2>/dev/null || return 0
  task=$(peal_session_task) || return 0
  gitdir=$(git rev-parse --absolute-git-dir) || return 0
  count=$(cat "$gitdir/peal-turns" 2>/dev/null)
  case $count in "" | *[!0-9]*) count=0 ;; esac
  count=$((count + 1))
  printf '%s\n' "$count" >"$gitdir/peal-turns.$$" && mv -f "$gitdir/peal-turns.$$" "$gitdir/peal-turns"
  [ ! -e "$gitdir/peal-nudged" ] || return 0
  size=$(peal_fm_get "$(_peal_field "$task" 2)" size 2>/dev/null)
  tier=$(peal_config_get "sizes.${size:-M}" 2>/dev/null)
  case $tier in "" | *[!0-9]*) return 0 ;; esac
  [ "$count" -ge "$tier" ] || return 0
  : >"$gitdir/peal-nudged"
  {
    echo "TURN BUDGET: $count tool calls on task $(_peal_field "$task" 1), size ${size:-unsized, taken as M}, whose tier is $tier."
    echo "If the task is not nearly done, it is bigger than it looked: close it with an honest"
    echo "Outcome and file what is left as ideas, or ask the human."
  } >&2
  return 2
}

# peal_session_end -> the SessionEnd hook: when the main session ends for real (reason
# logout, prompt_input_exit or other; not a clear, not a subagent) in a task's worktree,
# anything uncommitted is committed as "wip: session-end autosave [ID]" and the branch
# pushed, so no work stays on one machine only. What git says goes to the worktree's
# git directory, peal-session-end.log.
peal_session_end() {
  local reason task id gitdir branch remote log devices=() dev ref
  reason=$(peal_hook_field reason)
  [ -z "$(peal_hook_field agent_id)" ] || return 0
  case $reason in logout | prompt_input_exit | other) ;; *) return 0 ;; esac
  peal_hook_project || return 0
  peal_store_load 2>/dev/null || return 0
  task=$(peal_session_task) || return 0
  id=$(_peal_field "$task" 1)
  gitdir=$(git rev-parse --absolute-git-dir) || return 0
  log=$gitdir/peal-session-end.log
  branch=$(git symbolic-ref -q --short HEAD) || return 0
  remote=$(peal_config_get remote)
  {
    date -u +%Y-%m-%dT%H:%M:%SZ
    if [ -n "$(peal_status_porcelain)" ]; then
      # An untracked character device (a sandbox's /dev/null mount) is not work, but
      # git's add_to_index refuses to add one outright; left in a plain `git add -A` it
      # would stage nothing at all. Excluded explicitly, the real work still gets staged.
      while IFS= read -r dev; do
        [ -n "$dev" ] && devices+=(":(exclude,top,literal)$dev")
      done < <(peal_untracked_devices)
      git add -A -- . ${devices[@]+"${devices[@]}"} && git commit -q -m "wip: session-end autosave [$id]" \
        -m "Committed by Peal when the session ended ($reason), with whatever was in flight."
    fi
    if ref=$(peal_remote_ref "$branch" "$remote"); then
      [ "$(git rev-list --count "$ref..$branch")" = 0 ] || git push -q "$remote" "$branch"
    else
      git push -q "$remote" "$branch"
    fi
  } >>"$log" 2>&1
  return 0
}
