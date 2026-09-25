# shellcheck shell=bash
# GitHub, through `gh api`: the issues storage's tasks, the pull request a close opens
# and waits on, and those a write onto a protected main goes through (lib/main-write.sh). Every call goes through peal_gh, so the harnesses' fake gh (lib/fake-gh)
# sees them all.

# peal_github_repo -> owner/name of the project's repository: the setting
# storage.issues.repo, else the remote's GitHub repository, else gh's own guess from the
# working directory ({owner}/{repo}, which gh fills in).
peal_github_repo() {
  local repo
  repo=$(peal_config_get storage.issues.repo) || return 2
  [ -n "$repo" ] || repo=$(peal_github_repo_of "$(git remote get-url "$(peal_config_get remote)" 2>/dev/null)") \
    || repo='{owner}/{repo}'
  printf '%s\n' "$repo"
}

# peal_github_repo_of URL -> owner/name of a github.com remote URL; status 1 for another.
peal_github_repo_of() {
  local url=$1
  case $url in
    https://github.com/* | http://github.com/*) url=${url#*://github.com/} ;;
    https://*@github.com/*) url=${url#*@github.com/} ;;
    ssh://*github.com/*) url=${url#*github.com/} ;;
    *@github.com:*) url=${url#*@github.com:} ;;
    *) return 1 ;;
  esac
  url=${url%/}
  url=${url%.git}
  [[ "$url" =~ ^[^/]+/[^/]+$ ]] || return 1
  printf '%s\n' "$url"
}

# peal_urlencode TEXT -> TEXT %-encoded for a URL's path or query.
peal_urlencode() {
  local LC_ALL=C s=$1 i c out=""
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case $c in
      [A-Za-z0-9._~-]) out=$out$c ;;
      *) out=$out$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s\n' "$out"
}

# peal_gh ARGS... -> `gh api ARGS` (within a minute, where timeout exists); status 2 and
# gh's message when it fails.
peal_gh() {
  local err status=0
  if ! command -v gh >/dev/null 2>&1; then
    peal_err "this needs gh (https://cli.github.com), logged in"
    return 2
  fi
  err=$(mktemp) || return 2
  if command -v timeout >/dev/null 2>&1; then
    timeout 60 gh api "$@" 2>"$err" || status=2
  else
    gh api "$@" 2>"$err" || status=2
  fi
  if [ $status != 0 ]; then
    while [ $# -gt 0 ]; do
      case $1 in
        --jq | --input | --method | -X | -f | -F | --field | --raw-field) shift ;;
        -*) ;;
        *) set -- "$1" && break ;;
      esac
      shift
    done
    peal_err "gh api ${1-} failed: $(tr '\n' ' ' <"$err" | sed 's/ $//')"
  fi
  rm -f "$err"
  return $status
}

# peal_json [KIND:KEY VALUE]... -> a request's JSON object (lib/json-request.awk).
peal_json() {
  awk -f "$PEAL_ROOT/lib/json.awk" -f "$PEAL_ROOT/lib/json-request.awk" "$@"
}

# peal_pr_checks REPO SHA -> the checks on commit SHA, one line, status:
#   READY                   0  every check run and status passed
#   READY:no-checks         0  none, and the repository runs no GitHub Actions workflow
#   WAIT:checks-pending     3  a check is still running
#   WAIT:no-checks-yet      3  no check has registered yet
#   BLOCKED:checks-failing  1  a check failed
#   BLOCKED:gh-failed       1  gh could not tell
peal_pr_checks() {
  local repo=$1 sha=$2 runs statuses counts pending failing total
  runs=$(peal_gh "repos/$repo/commits/$sha/check-runs?per_page=100" \
    --jq '.check_runs[] | [.status, (.conclusion // "")] | @tsv') || { echo "BLOCKED:gh-failed"; return 1; }
  statuses=$(peal_gh "repos/$repo/commits/$sha/status" --jq '.statuses[] | .state') || { echo "BLOCKED:gh-failed"; return 1; }
  counts=$( { printf '%s\n' "$runs" | sed '/^$/d; s/^/run\t/'; printf '%s\n' "$statuses" | sed '/^$/d; s/^/status\t/'; } | awk -F '\t' '
    $1 == "run" && $2 != "completed" { p++ }
    $1 == "run" && $2 == "completed" && $3 != "success" && $3 != "neutral" && $3 != "skipped" { f++ }
    $1 == "status" && $2 == "pending" { p++ }
    $1 == "status" && ($2 == "failure" || $2 == "error") { f++ }
    { t++ }
    END { print p + 0, f + 0, t + 0 }')
  read -r pending failing total <<<"$counts"
  [ "$failing" = 0 ] || { echo "BLOCKED:checks-failing"; return 1; }
  [ "$pending" = 0 ] || { echo "WAIT:checks-pending"; return 3; }
  if [ "$total" = 0 ]; then
    total=$(peal_gh "repos/$repo/actions/workflows" --jq '.total_count') || { echo "BLOCKED:gh-failed"; return 1; }
    if [ "$total" = 0 ]; then
      echo "READY:no-checks"
      return 0
    fi
    echo "WAIT:no-checks-yet"
    return 3
  fi
  echo "READY"
}
