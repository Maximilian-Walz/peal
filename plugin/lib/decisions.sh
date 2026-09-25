# shellcheck shell=bash
# The decisions module (docs/design.md, "Decision records"): architectural decisions as
# numbered, append-only entries, DIR/NNNN-slug.md, DIR the setting `decisions` (false: the
# module is off). An entry is
#
#   # NNNN — Title
#   Date: YYYY-MM-DD
#   Status: accepted | superseded by NNNN
#
#   **Decision.** ...
#   **Why.** ...
#   **Rules out.** ...
#
# and one that supersedes another says so in a paragraph "**Supersedes** decision NNNN."
# Numbers are reserved by push-as-lock on refs/decisions/NNNN; the index, DIR/index.md,
# is generated on the main branch after a merge and never changed by a branch.

# peal_decisions_dir -> the entries' directory, relative to the top, when the module is
# on; status 1 when it is off, 2 for a setting that is neither false nor a directory.
peal_decisions_dir() {
  local dir
  dir=$(peal_config_get decisions) || return 2
  case $dir in
    "" | false) return 1 ;;
    true | /* | .. | ../*)
      peal_err "decisions: false, or the entries' directory inside the repository (docs/decisions), not '$dir'"
      return 2
      ;;
  esac
  printf '%s\n' "${dir%/}"
}

# _peal_dec_on VERB -> PEAL_DEC_DIR, and the caller at the top of the work tree; status 2
# with a message when the module is off.
_peal_dec_on() {
  local top status
  PEAL_DEC_DIR=$(peal_decisions_dir)
  status=$?
  if [ $status = 1 ]; then
    peal_err "decision $1: the decisions module is off; turn it on with decisions: DIR in .peal/config.yml"
    return 2
  fi
  [ $status = 0 ] || return 2
  top=$(peal_project_root) || return 2
  cd "$top" || return 2
}

# peal_decision SUBCOMMAND ARGS...
peal_decision() {
  local sub=${1-}
  [ $# -eq 0 ] || shift
  case $sub in
    reserve) peal_decision_reserve "$@" ;;
    check) [ $# -eq 0 ] || { peal_err "decision check takes no arguments"; return 2; }; peal_decision_check ;;
    index) [ $# -eq 0 ] || { peal_err "decision index takes no arguments"; return 2; }; peal_decision_index ;;
    publish) [ $# -eq 0 ] || { peal_err "decision publish takes no arguments"; return 2; }; peal_decision_publish ;;
    brief) peal_decision_brief "$@" ;;
    *) peal_err "decision: reserve, check, index, publish or brief"; return 2 ;;
  esac
}

# _peal_dec_scan DIR -> decisions-scan.awk's lines for the entries in DIR (an absolute
# path): every file there whose name starts with a digit and ends in .md.
_peal_dec_scan() {
  local files=() f
  for f in "$1"/[0-9]*.md; do
    [ -f "$f" ] && files+=("$f")
  done
  [ ${#files[@]} -gt 0 ] || return 0
  awk -f "$PEAL_ROOT/lib/decisions-lib.awk" -f "$PEAL_ROOT/lib/decisions-scan.awk" "${files[@]}"
}

# _peal_dec_problems SCAN -> the E lines of a scan, one "peal: decisions: DIR/name: what" line each
# on stderr; status 1 if there were any.
_peal_dec_problems() {
  local problems
  problems=$(printf '%s\n' "$1" | awk -F '\t' -v dir="$PEAL_DEC_DIR" '$1 == "E" { print "peal: decisions: " dir "/" $2 ": " $3 }')
  [ -n "$problems" ] || return 0
  printf '%s\n' "$problems" >&2
  return 1
}

# --- reserve -----------------------------------------------------------------------------

# peal_decision_reserve SLUG -> the next decision number reserved for this branch, by a
# marker commit pushed to refs/decisions/NNNN ("reserve decision NNNN: SLUG (branch B,
# DATE)"): a push that loses the race to another reservation is retried under the next
# number (PEAL_PUSH_ATTEMPTS, 5). Then DIR/NNNN-SLUG.md is scaffolded in the work tree,
# for the session to fill in; nothing is committed. The number is one past every entry
# on the remote's main branch, every reservation on the remote and every entry here.
peal_decision_reserve() {
  local hint=${1-} slug branch today empty attempt=1 max=${PEAL_PUSH_ATTEMPTS:-5} held num ref sha err now file title
  if [ $# -ne 1 ] || [ "${hint#-}" != "$hint" ]; then
    peal_err "decision reserve: SLUG, 2 to 5 words naming the decision"
    return 2
  fi
  slug=$(peal_slugify "$hint") || return 2
  _peal_dec_on reserve || return 2
  PEAL_REMOTE=$(peal_config_get remote) || return 2
  PEAL_MAIN=$(peal_config_get main) || return 2
  branch=$(git symbolic-ref -q --short HEAD) || {
    peal_err "decision reserve: HEAD is detached; reserve on the branch that adds the entry"
    return 2
  }
  if [ "$branch" = "$PEAL_MAIN" ]; then
    peal_err "decision reserve: this is $PEAL_MAIN; reserve on the branch that adds the entry, which its pull request brings in"
    return 2
  fi
  if ! git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null \
      || ! git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" >/dev/null; then
    peal_err "decision reserve: could not fetch $PEAL_REMOTE/$PEAL_MAIN; nothing reserved"
    return 2
  fi
  today=$(date -u +%Y-%m-%d)
  empty=$(git hash-object -w -t tree /dev/null) || return 2
  err=$(mktemp) || return 2
  while :; do
    if ! held=$(git ls-remote "$PEAL_REMOTE" 'refs/decisions/*' 2>"$err"); then
      peal_err "decision reserve: could not read the reservations on $PEAL_REMOTE; nothing reserved:"
      cat "$err" >&2
      rm -f "$err"
      return 2
    fi
    num=$({
      git ls-tree --name-only "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" -- "$PEAL_DEC_DIR/" | sed 's|.*/||'
      printf '%s\n' "$held" | sed -n 's|.*refs/decisions/||p'
      ls "$PEAL_DEC_DIR" 2>/dev/null
    } | awk '/^[0-9][0-9][0-9][0-9]/ { n = substr($0, 1, 4) + 0; if (n > max) max = n }
             END { printf "%04d\n", max + 1 }')
    ref=refs/decisions/$num
    sha=$(git commit-tree "$empty" -m "reserve decision $num: $slug (branch $branch, $today)") || { rm -f "$err"; return 2; }
    if git push -q "$PEAL_REMOTE" "$sha:$ref" 2>"$err"; then
      break
    fi
    # A remote with several push URLs fails the push when one of them refuses, though the
    # reservation may have landed: whose marker the ref holds says.
    now=$(git ls-remote "$PEAL_REMOTE" "$ref" 2>/dev/null | cut -f1)
    [ "$now" != "$sha" ] || break
    if [ -z "$now" ]; then
      peal_err "decision reserve: the push of $ref failed, and not from a race; nothing reserved:"
      cat "$err" >&2
      rm -f "$err"
      return 1
    fi
    if [ $attempt -ge "$max" ]; then
      peal_err "decision reserve: gave up after $max pushes, each losing a race; nothing reserved"
      rm -f "$err"
      return 1
    fi
    peal_err "decision reserve: $num was reserved meanwhile ($attempt of $max); again with the next number"
    attempt=$((attempt + 1))
  done
  rm -f "$err"
  echo "reserved decision $num for $branch ($ref on $PEAL_REMOTE)"
  file=$PEAL_DEC_DIR/$num-$slug.md
  mkdir -p "$PEAL_DEC_DIR" || return 2
  title=$(printf '%s' "$slug" | tr '-' ' ')
  title=$(printf '%s' "${title:0:1}" | tr '[:lower:]' '[:upper:]')${title:1}
  cat >"$file" <<EOF || return 2
# $num — $title
Date: $today
Status: accepted

**Decision.** <!-- what is decided, in a sentence or two -->

**Why.** <!-- the reasons, and what was weighed against it -->

**Rules out.** <!-- what this excludes, so it is not argued again -->
EOF
  echo "wrote $file: give it its title and fill in its paragraphs. To supersede an entry,"
  echo "add \"**Supersedes** decision NNNN.\" here and make that one's \"Status: superseded by $num\"."
}

# --- checks ------------------------------------------------------------------------------

# _peal_dec_changes BASE -> the branch's changes to the entries since BASE, commits, the
# work tree and new files alike: "A name", "M name<TAB>its Status at BASE", "D name"; and
# "I" when it changes the index.
_peal_dec_changes() {
  local base=$1 st path name
  {
    git diff --name-status --no-renames "$base" -- "$PEAL_DEC_DIR/"
    git ls-files --others --exclude-standard -- "$PEAL_DEC_DIR/" | sed 's/^/A	/'
  } | while IFS="$(printf '\t')" read -r st path; do
    [ "${path%/*}" = "$PEAL_DEC_DIR" ] || continue
    name=${path##*/}
    case $name in
      index.md) echo I ;;
      [0-9]*.md)
        case $st in
          A) printf 'A\t%s\n' "$name" ;;
          D) printf 'D\t%s\n' "$name" ;;
          *) printf 'M\t%s\t%s\n' "$name" "$(git show "$base:$path" 2>/dev/null | awk '
               /^Status: / { s = substr($0, 9); sub(/\r$/, "", s); sub(/[ \t]+$/, "", s); print s; exit }')" ;;
        esac
        ;;
    esac
  done
}

# _peal_dec_branch -> the branch whose reservations count: GITHUB_HEAD_REF in a pull
# request's workflow, whose checkout is a merge commit; else the branch checked out.
_peal_dec_branch() {
  if [ -n "${GITHUB_HEAD_REF-}" ]; then
    printf '%s\n' "$GITHUB_HEAD_REF"
  else
    git symbolic-ref -q --short HEAD
  fi
}

# _peal_dec_reserved NAME BRANCH -> status 0 if the entry NAME's number is reserved on the
# remote by BRANCH; 1 with why on stderr if not; 3 if the remote could not be asked.
_peal_dec_reserved() {
  local name=$1 branch=$2 num ref held subject marker
  num=${name:0:4}
  ref=refs/decisions/$num
  held=$(git ls-remote "$PEAL_REMOTE" "$ref" 2>/dev/null) || {
    peal_err "decisions: $PEAL_DEC_DIR/$name: could not ask $PEAL_REMOTE for $ref"
    return 3
  }
  held=$(printf '%s\n' "$held" | cut -f1)
  if [ -z "$held" ]; then
    peal_err "decisions: $PEAL_DEC_DIR/$name: $num is reserved by no one ($ref is not on $PEAL_REMOTE). Numbers come from peal decision reserve SLUG: reserve one and rename the entry."
    return 1
  fi
  if ! git cat-file -e "$held^{commit}" 2>/dev/null && ! git fetch -q "$PEAL_REMOTE" "$ref" 2>/dev/null; then
    peal_err "decisions: $PEAL_DEC_DIR/$name: could not fetch $ref from $PEAL_REMOTE"
    return 3
  fi
  subject=$(git show -s --format=%s "$held" 2>/dev/null)
  marker=$(printf '%s\n' "$subject" | sed -n 's/^reserve decision [0-9][0-9][0-9][0-9]: .* (branch \(.*\), [0-9-]*)$/\1/p')
  if [ -z "$marker" ]; then
    peal_err "decisions: $PEAL_DEC_DIR/$name: $ref holds no reservation Peal made (\"$subject\")"
    return 1
  fi
  if [ "$marker" != "$branch" ]; then
    peal_err "decisions: $PEAL_DEC_DIR/$name: $num is reserved by the branch $marker, not by ${branch:-this detached HEAD}. Reserve a number of this branch's own (peal decision reserve SLUG) and rename the entry."
    return 1
  fi
}

# _peal_dec_check BASE -> the module's checks of the work tree, whose branch left the
# main branch at BASE; each problem on stderr. The entries well-formed; the branch leaves
# the index alone and deletes no entry; every Status it turns to "superseded by NNNN"
# pairs with an entry NNNN it adds that says so, and the other way round; every entry it
# adds holds a reservation of this branch. Status 0 for none, 1 for a problem, 3 when
# nothing is wrong but a reservation could not be verified (the remote unreachable).
_peal_dec_check() {
  local base=$1 scan changes pairs name branch status=0 unverified=0 rc
  scan=$(_peal_dec_scan "$PWD/$PEAL_DEC_DIR")
  _peal_dec_problems "$scan" || status=1
  changes=$(_peal_dec_changes "$base")
  if printf '%s\n' "$changes" | grep -qx I; then
    peal_err "decisions: $PEAL_DEC_DIR/index.md is changed on this branch; it is generated on $PEAL_MAIN after the merge (peal decision publish). Take the change out: git checkout $base -- $PEAL_DEC_DIR/index.md (or git rm it, if $PEAL_MAIN has none)"
    status=1
  fi
  pairs=$(awk -F '\t' -f "$PEAL_ROOT/lib/decisions-lib.awk" -f "$PEAL_ROOT/lib/decisions-pairs.awk" \
    <(printf '%s\n' "$scan") <(printf '%s\n' "$changes" | grep -v '^I$'))
  if [ -n "$pairs" ]; then
    printf '%s\n' "$pairs" | awk -F '\t' -v dir="$PEAL_DEC_DIR" '{ print "peal: decisions: " dir "/" $1 ": " $2 }' >&2
    status=1
  fi
  branch=$(_peal_dec_branch)
  for name in $(printf '%s\n' "$changes" | awk -F '\t' '$1 == "A" { print $2 }'); do
    printf '%s\n' "$scan" | awk -F '\t' -v n="$name" '$1 == "R" && $2 == n { f = 1 } END { exit !f }' || continue
    _peal_dec_reserved "$name" "$branch"
    rc=$?
    case $rc in 0) ;; 3) unverified=1 ;; *) status=1 ;; esac
  done
  [ $status = 0 ] && [ $unverified = 1 ] && return 3
  return $status
}

# _peal_dec_check_here VERB -> _peal_dec_check against where this branch left the main
# branch, fetched first (a warning if that fails).
_peal_dec_check_here() {
  PEAL_REMOTE=$(peal_config_get remote) || return 2
  PEAL_MAIN=$(peal_config_get main) || return 2
  git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null \
    || peal_err "warning: could not fetch $PEAL_REMOTE/$PEAL_MAIN; comparing with what is known here"
  peal_branch_base "$1" || return 2
  _peal_dec_check "$PEAL_BASE"
}

# peal_decision_check -> the module's checks (_peal_dec_check), for this branch; status 2
# for any problem, and for a reservation that could not be verified.
peal_decision_check() {
  _peal_dec_on check || return 2
  if _peal_dec_check_here "decision check"; then
    echo "decisions: in order"
    return 0
  fi
  return 2
}

# peal_decisions_check -> peal check's part: peal_decision_check when the module is on.
peal_decisions_check() {
  local status
  peal_decisions_dir >/dev/null
  status=$?
  [ $status != 1 ] || return 0
  [ $status = 0 ] || return 2
  (peal_decision_check >/dev/null)
}

# peal_decisions_guard -> the PostToolUse hook on Edit and Write: after an entry or the
# index of a Peal project is written, its checks; a problem on stderr and status 2, which
# Claude Code shows the session. A reservation that could not be verified only warns.
peal_decisions_guard() {
  local file here dir top err rc
  file=$(peal_hook_field tool_input.file_path)
  case $file in */[0-9]*.md | */index.md) ;; *) return 0 ;; esac
  here=$(cd "$(dirname "$file")" 2>/dev/null && pwd -P) || return 0
  top=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null) || return 0
  [ -d "$top/.peal" ] || return 0
  cd "$top" || return 0
  peal_config_load 2>/dev/null || return 0
  dir=$(peal_decisions_dir 2>/dev/null) || return 0
  [ "$here" = "$(cd "$dir" 2>/dev/null && pwd -P)" ] || return 0
  PEAL_DEC_DIR=$dir
  peal_branch_base "decisions" 2>/dev/null || return 0
  err=$(_peal_dec_check "$PEAL_BASE" 2>&1 >/dev/null)
  rc=$?
  case $rc in
    0) return 0 ;;
    3) printf 'Peal: warning, a decision reservation could not be verified:\n%s\n' "$err" >&2; return 0 ;;
  esac
  {
    echo "Peal: the decision entries are not in order:"
    printf '%s\n' "$err" | sed 's/^peal: decisions: /  - /'
  } >&2
  return 2
}

# --- the index ---------------------------------------------------------------------------

# _peal_dec_render DIR -> the index of the entries in DIR (an absolute path); status 2
# with the problems when an entry is not well-formed.
_peal_dec_render() {
  local scan
  scan=$(_peal_dec_scan "$1")
  _peal_dec_problems "$scan" || return 2
  printf '%s\n' "$scan" | awk -F '\t' -f "$PEAL_ROOT/lib/decisions-lib.awk" -f "$PEAL_ROOT/lib/decisions-index.awk"
}

# peal_decision_index -> the index of the entries in the work tree, printed.
peal_decision_index() {
  _peal_dec_on index || return 2
  _peal_dec_render "$PWD/$PEAL_DEC_DIR"
}

# peal_decision_publish -> the index regenerated from the entries on the remote's main
# branch and, when it differs, committed there ("docs(decisions): regenerate the index")
# and pushed, again on a new main when the push loses a race. No worktree is touched, so it
# runs anywhere; a project's workflow runs it after every merge (templates/decisions.yml).
peal_decision_publish() {
  local status
  _peal_dec_on publish || return 2
  PEAL_REMOTE=$(peal_config_get remote) || return 2
  PEAL_MAIN=$(peal_config_get main) || return 2
  if ! git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null \
      || ! git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" >/dev/null; then
    peal_err "decision publish: could not fetch $PEAL_REMOTE/$PEAL_MAIN"
    return 2
  fi
  peal_push_main _peal_dec_build_index
  status=$?
  case $status in
    0) echo "published $PEAL_DEC_DIR/index.md to $PEAL_REMOTE/$PEAL_MAIN" ;;
    3) echo "$PEAL_DEC_DIR/index.md on $PEAL_REMOTE/$PEAL_MAIN is up to date"; return 0 ;;
  esac
  return $status
}

# _peal_dec_build_index BASE -> PEAL_TREE and PEAL_SUBJECT: BASE with the index of its
# entries; status 3 when BASE's index is that already, 2 for a malformed entry.
_peal_dec_build_index() {
  local base=$1 tmp status=0
  tmp=$(mktemp -d) || return 2
  mkdir -p "$tmp/tree/$PEAL_DEC_DIR"
  if git cat-file -e "$base:$PEAL_DEC_DIR" 2>/dev/null; then
    git archive "$base" -- "$PEAL_DEC_DIR" | tar -x -C "$tmp/tree" || status=2
  fi
  if [ $status = 0 ] && ! _peal_dec_render "$tmp/tree/$PEAL_DEC_DIR" >"$tmp/index.md"; then
    peal_err "decision publish: an entry on $PEAL_MAIN is malformed (above); nothing published"
    status=2
  fi
  if [ $status = 0 ] && cmp -s "$tmp/index.md" "$tmp/tree/$PEAL_DEC_DIR/index.md"; then
    status=3
  fi
  if [ $status = 0 ]; then
    peal_write_tree "$base" add "$PEAL_DEC_DIR/index.md" "$tmp/index.md" || status=2
    # shellcheck disable=SC2034 # read by peal_push_main
    PEAL_SUBJECT="docs(decisions): regenerate the index"
  fi
  rm -rf "$tmp"
  return $status
}

# --- the brief ---------------------------------------------------------------------------

# peal_decision_brief --task FILE | --diff [BASE] -> the entries that name a path the task
# or the diff touches (decisions-brief.awk), for the planner's and the reviewer's prompts
# in place of the whole index. A task's paths come from its ## Scope, or while that is
# empty from its ## Intent and ## Notes; a diff's are the files it changes since BASE
# (where this branch left the main branch), uncommitted changes included.
peal_decision_brief() {
  local mode=${1-} file from tmp status=0 names=() name
  case $mode in
    --task)
      [ $# -eq 2 ] || { peal_err "decision brief: --task FILE | --diff [BASE]"; return 2; }
      file=$2
      case $file in /*) ;; *) file=$PWD/$file ;; esac
      [ -f "$file" ] || { peal_err "decision brief: no task file $2"; return 2; }
      ;;
    --diff) [ $# -le 2 ] || { peal_err "decision brief: --task FILE | --diff [BASE]"; return 2; } ;;
    *) peal_err "decision brief: --task FILE | --diff [BASE]"; return 2 ;;
  esac
  _peal_dec_on brief || return 2
  tmp=$(mktemp -d) || return 2
  if [ "$mode" = --task ]; then
    if peal_text_section_filled Scope <"$file"; then
      from="its ## Scope"
      peal_text_section Scope <"$file" >"$tmp/text"
    else
      from="its ## Intent and ## Notes, the Scope being empty"
      { peal_text_section Intent <"$file"; peal_text_section Notes <"$file"; } >"$tmp/text"
    fi
    from="the task ($from)"
  else
    if [ -n "${2-}" ]; then
      # A commit, never an option: git diff would take "--output=FILE" as one and write it.
      if [ "${2#-}" != "$2" ] || ! PEAL_BASE=$(git rev-parse -q --verify "$2^{commit}"); then
        rm -rf "$tmp"
        peal_refuse "decision brief: no commit" "$2"
        return
      fi
    else
      peal_branch_base "decision brief" || { rm -rf "$tmp"; return 2; }
    fi
    if ! git diff --name-only "$PEAL_BASE" -- >"$tmp/text" 2>"$tmp/err"; then
      peal_err "decision brief: no diff against $PEAL_BASE:"
      cat "$tmp/err" >&2
      rm -rf "$tmp"
      return 2
    fi
    from="the diff since $(git rev-parse --short "$PEAL_BASE")"
  fi
  _peal_dec_scan "$PWD/$PEAL_DEC_DIR" >"$tmp/scan"
  while IFS= read -r name; do
    names+=("$PEAL_DEC_DIR/$name")
  done < <(awk -F '\t' '$1 == "R" { print $2 }' "$tmp/scan")
  echo "Decisions in $PEAL_DEC_DIR/ that name a path of $from; read each that bears on the work:"
  awk -F '\t' -f "$PEAL_ROOT/lib/decisions-lib.awk" -f "$PEAL_ROOT/lib/decisions-brief.awk" \
    "$tmp/scan" "$tmp/text" ${names[@]+"${names[@]}"} || status=2
  rm -rf "$tmp"
  return $status
}

# --- the close ---------------------------------------------------------------------------

# peal_decisions_commit ID -> the entries uncommitted here committed on their own, as
# "docs(decisions): record NNNN[, MMMM] [ID]"; nothing when there are none or the module
# is off. Status 1 when the commit is refused.
peal_decisions_commit() {
  local id=$1 dir paths=() path nums
  dir=$(peal_decisions_dir 2>/dev/null) || return 0
  while IFS= read -r path; do
    [ -n "$path" ] && paths+=("$path")
  done < <(git status --porcelain --untracked-files=all -- "$dir/[0-9]*.md" | cut -c4-)
  [ ${#paths[@]} -gt 0 ] || return 0
  nums=$(printf '%s\n' "${paths[@]}" | sed 's|.*/||' | cut -c1-4 | sort -u | paste -sd, - | sed 's/,/, /g')
  git add -- "${paths[@]}" || return 1
  if ! git commit -q -m "docs(decisions): record $nums [$id]" -- "${paths[@]}"; then
    peal_err "close finish: the commit of the decision entries was refused (above)"
    return 1
  fi
  echo "committed decision(s) $nums"
}
