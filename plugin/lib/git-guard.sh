# shellcheck shell=bash
# The git guard, Claude Code's PreToolUse hook on Bash: refuses, before it runs, a git
# invocation that works around Peal's git gates, in a repository that uses Peal (has
# .peal/):
#   - a commit (or cherry-pick, revert, am) on the main branch;
#   - a gate bypass: --no-verify (or commit -n), core.hooksPath changed or unset, set
#     inline (-c, --config-env) or through GIT_CONFIG_* variables;
#   - a push to the main branch (or of every branch): main changes through a merged pull
#     request, and through Peal's own commands, which push from inside their scripts and
#     are never a git invocation this hook sees;
#   - git lfs install|update --force, which would overwrite Peal's hooks with LFS's.
# It judges the git invocations the command runs (lib/shell-words.awk), not its text: a
# message, a heredoc or a grep that mentions --no-verify passes. It is a signpost; the
# git hooks are the gates. Exit 2 refuses, the reason on stderr for the session.

PEAL_GUARD_SEP=$(printf '\036')
PEAL_GUARD_US=$(printf '\037')

# peal_git_guard -> the hook: its JSON input on stdin; status 2 and the reason to refuse.
peal_git_guard() {
  local input cmd cwd
  input=$(cat)
  cmd=$(printf '%s' "$input" | awk -v key=tool_input.command -f "$PEAL_ROOT/lib/json-get.awk")
  case $cmd in *git*) ;; *) return 0 ;; esac
  cwd=$(printf '%s' "$input" | awk -v key=cwd -f "$PEAL_ROOT/lib/json-get.awk")
  [ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
  _peal_guard_scan "$cmd" "$cwd" 0
}

_peal_guard_deny() {
  printf 'peal git guard: %s\n' "$1" >&2
  shift
  [ $# -eq 0 ] || printf '  %s\n' "$@" >&2
  exit 2
}

# _peal_guard_dir CWD DIR -> DIR taken from CWD.
_peal_guard_dir() {
  case $2 in
    /*) printf '%s\n' "$2" ;;
    \~ | \~/*) printf '%s\n' "$HOME${2#\~}" ;;
    *) printf '%s\n' "$1/$2" ;;
  esac
}

# _peal_guard_scan COMMAND CWD DEPTH -> every simple command of COMMAND judged in turn, a
# cd moving CWD for the ones after it; bash -c and eval scanned in their turn.
_peal_guard_scan() {
  local cmd=$1 cwd=$2 depth=$3 seg i n w
  local -a words
  [ "$depth" -lt 5 ] || return 0
  while IFS= read -r -d "$PEAL_GUARD_SEP" seg; do
    words=()
    IFS=$PEAL_GUARD_US read -r -d '' -a words < <(printf '%s' "$seg")
    n=${#words[@]}
    i=0
    while [ $i -lt "$n" ]; do
      w=${words[i]}
      case $w in
        GIT_CONFIG_COUNT=* | GIT_CONFIG_PARAMETERS=* | GIT_CONFIG_KEY_*=* | GIT_CONFIG_VALUE_*=*)
          _peal_guard_bypass "${w%%=*} sets git configuration around the command, core.hooksPath included" ;;
        [A-Za-z_]*=*) ;;
        sudo | env | time | nice | nohup | command | builtin | exec | xargs | export | then | do | else | elif | if | while | until | '!' | '{' | '}') ;;
        timeout) i=$((i + 1)) ;;
        -*) [ $i -gt 0 ] || break ;;
        *) break ;;
      esac
      i=$((i + 1))
    done
    [ $i -lt "$n" ] || continue
    w=${words[i]}
    case $w in
      cd | pushd)
        if [ $((i + 1)) -lt "$n" ]; then cwd=$(_peal_guard_dir "$cwd" "${words[i + 1]}"); else cwd=$HOME; fi
        ;;
      bash | sh | zsh | dash | ksh | */bash | */sh | */zsh | */dash | */ksh)
        for ((i = i + 1; i < n; i++)); do
          case ${words[i]} in
            -*c*) [ $((i + 1)) -lt "$n" ] && _peal_guard_scan "${words[i + 1]}" "$cwd" $((depth + 1)); break ;;
            -*) ;;
            *) break ;;
          esac
        done
        ;;
      eval) _peal_guard_scan "${words[*]:i+1}" "$cwd" $((depth + 1)) ;;
      git | */git) _peal_guard_git "$cwd" "${words[@]:i+1}" ;;
      git-lfs | */git-lfs) _peal_guard_git "$cwd" lfs "${words[@]:i+1}" ;;
    esac
  done < <(printf '%s' "$cmd" | awk -f "$PEAL_ROOT/lib/shell-words.awk")
}

_peal_guard_bypass() {
  _peal_guard_deny "$1: that turns Peal's git gates off." \
    "Fix what the gate refuses; to save work that is not green, commit it as 'wip: <what>'."
}

# _peal_guard_hookspath KEY=VALUE -> refused if KEY is core.hooksPath.
_peal_guard_hookspath() {
  local key
  key=$(printf '%s' "${1%%=*}" | tr '[:upper:]' '[:lower:]')
  [ "$key" != core.hookspath ] || _peal_guard_bypass "setting core.hooksPath for one git call"
}

# _peal_guard_git CWD ARGS... -> one git invocation judged.
_peal_guard_git() {
  local dir=$1 sub top main branch
  shift
  while [ $# -gt 0 ]; do
    case $1 in
      -C) dir=$(_peal_guard_dir "$dir" "${2-}"); shift ;;
      -c) _peal_guard_hookspath "${2-}"; shift ;;
      -c*) _peal_guard_hookspath "${1#-c}" ;;
      --config-env) _peal_guard_hookspath "${2-}"; shift ;;
      --config-env=*) _peal_guard_hookspath "${1#--config-env=}" ;;
      --git-dir | --work-tree | --namespace | --super-prefix | --exec-path) shift ;;
      -*) ;;
      *) break ;;
    esac
    shift
  done
  [ $# -gt 0 ] || return 0
  sub=$1
  shift
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 0
  [ -d "$top/.peal" ] || return 0
  main=$(cd "$top" && peal_config_load 2>/dev/null && peal_config_get main) || main=main
  branch=$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null) || branch=""
  case $sub in
    commit | cherry-pick | revert | am)
      [ "$branch" != "$main" ] || _peal_guard_deny "no $sub on $main: work on the task's branch." \
        "/peal:work claims a task and gives it its branch and worktree."
      case $sub in
        commit) _peal_guard_commit "$@" ;;
        am) _peal_guard_no_verify "$@" ;;
      esac
      ;;
    merge) _peal_guard_no_verify "$@" ;;
    push) _peal_guard_push "$main" "$branch" "$@" ;;
    config) _peal_guard_config "$@" ;;
    lfs)
      case ${1-} in
        install | update)
          local a
          for a in "$@"; do
            case $a in
              -f | --force) _peal_guard_deny "git lfs $1 --force writes LFS's hooks over Peal's." \
                "Peal's hooks run the project's own hook of the same name: put LFS's in the project's hooks directory." ;;
            esac
          done
          ;;
      esac
      ;;
  esac
  return 0
}

_peal_guard_no_verify() {
  local a
  for a in "$@"; do
    case $a in
      --) return 0 ;;
      --no-verify) _peal_guard_bypass "--no-verify" ;;
    esac
  done
}

# _peal_guard_commit ARGS... -> refused for --no-verify or -n, never mistaking an
# option's value (a message, say) for one.
_peal_guard_commit() {
  local a j c
  while [ $# -gt 0 ]; do
    a=$1
    case $a in
      --) return 0 ;;
      --no-verify) _peal_guard_bypass "--no-verify" ;;
      --message | --file | --author | --date | --template | --reuse-message | --reedit-message | --fixup | --squash | --cleanup | --trailer | --pathspec-from-file) shift ;;
      --*) ;;
      -?*)
        for ((j = 1; j < ${#a}; j++)); do
          c=${a:j:1}
          case $c in
            n) _peal_guard_bypass "commit -n (--no-verify)" ;;
            m | F | c | C | t)
              [ $((j + 1)) -lt ${#a} ] || shift
              break
              ;;
          esac
        done
        ;;
    esac
    shift
  done
}

# _peal_guard_push MAIN BRANCH ARGS... -> refused for --no-verify, --all or --mirror, and
# any refspec whose destination is MAIN, a bare push from MAIN included.
_peal_guard_push() {
  local main=$1 branch=$2 a opts=1 dst
  local -a words=()
  shift 2
  while [ $# -gt 0 ]; do
    a=$1
    if [ $opts = 1 ]; then
      case $a in
        --) opts=0; shift; continue ;;
        --no-verify) _peal_guard_bypass "--no-verify" ;;
        --all | --mirror | --branches)
          _peal_guard_deny "git push $a pushes $main too: push the task's branch alone." ;;
        --repo | -o | --push-option | --receive-pack | --exec) shift ;;
        -*) ;;
        *) words+=("$a") ;;
      esac
    else
      words+=("$a")
    fi
    shift
  done
  if [ ${#words[@]} -le 1 ]; then
    [ "$branch" != "$main" ] || _peal_guard_push_main "$main"
    return 0
  fi
  for a in "${words[@]:1}"; do
    a=${a#+}
    dst=${a#*:}
    case $dst in HEAD | @ | "") dst=$branch ;; esac
    [ "${dst#refs/heads/}" != "$main" ] || _peal_guard_push_main "$main"
  done
}

_peal_guard_push_main() {
  _peal_guard_deny "nothing is pushed to $1 by hand." \
    "$1 changes through a merged pull request, and through Peal's commands, which write" \
    "there themselves: peal create, revise, retire, set-milestone, comment."
}

# _peal_guard_config ARGS... -> refused when it writes core.hooksPath, or removes or
# renames the section holding it; reads pass.
_peal_guard_config() {
  local a lower key=0 write=0 values=0 section=0
  for a in "$@"; do
    lower=$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')
    case $lower in
      core.hookspath) key=1 ;;
      --unset | --unset-all | --replace-all | --add | unset | set | --edit | -e | edit) write=1 ;;
      --remove-section | --rename-section | remove-section | rename-section) section=1 ;;
      core) [ $section = 0 ] || _peal_guard_bypass "removing git's core section, core.hooksPath with it" ;;
      -*) ;;
      *) [ $key = 0 ] || values=$((values + 1)) ;;
    esac
  done
  [ $key = 1 ] || return 0
  if [ $write = 1 ] || [ $values -gt 0 ]; then
    _peal_guard_deny "changing core.hooksPath turns Peal's git gates off." \
      "Peal's hooks are installed with: peal hooks install"
  fi
}
