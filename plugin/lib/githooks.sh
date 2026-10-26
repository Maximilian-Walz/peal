# shellcheck shell=bash
# Peal's git gates (docs/design.md, "Git gates"): what may reach the main branch,
# and what a commit must satisfy. `peal hooks install` writes templates/githook under
# every hook name into the git directory and points core.hooksPath there; that stub runs
# the gates below through `peal githook NAME`, then the project's own hook of the same
# name.

PEAL_GITHOOKS="applypatch-msg pre-applypatch post-applypatch pre-commit pre-merge-commit
prepare-commit-msg commit-msg post-commit pre-rebase post-checkout post-merge pre-push
post-rewrite pre-auto-gc post-index-change sendemail-validate"

# The commit subject grammar: <type>(<area>): <what> [NNNN].
PEAL_COMMIT_TYPES="feat fix test refactor docs chore wip"
PEAL_SUBJECT_RE='^(feat|fix|test|refactor|docs|chore|wip)(\(([a-z0-9][a-z0-9-]*)\))?: (.*[^ ])$'

# _peal_hooks_dir -> where the stubs live: peal/hooks in the git directory all worktrees
# share, as an absolute path.
_peal_hooks_dir() {
  local common
  common=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd) || {
    peal_err "not inside a git repository"
    return 2
  }
  printf '%s/peal/hooks\n' "$common"
}

# peal_hooks_install -> the stubs written, core.hooksPath pointed at them, a hooks path
# set before kept as peal.projectHooks for the stubs to chain to, and this Peal's root
# recorded for the stubs to find (unless the record names a verified newer Peal,
# peal_write_root); refused for a Peal inside this repository, which the
# stubs would refuse to run.
peal_hooks_install() {
  local dir prev name chain
  dir=$(_peal_hooks_dir) || return 2
  if peal_repo_holds . "$PEAL_ROOT"; then
    peal_err "hooks install: this Peal ($PEAL_ROOT) lies inside the repository, and the hooks never run a Peal the repository holds; install from the installed plugin (.peal/peal hooks install)"
    return 2
  fi
  mkdir -p "$dir" || return 2
  for name in $PEAL_GITHOOKS; do
    if ! { cp "$PEAL_ROOT/templates/githook" "$dir/$name.$$" && chmod +x "$dir/$name.$$" \
        && mv -f "$dir/$name.$$" "$dir/$name"; }; then
      peal_err "could not write $dir/$name"
      return 2
    fi
  done
  prev=$(git config core.hooksPath)
  if [ -n "$prev" ] && [ "$prev" != "$dir" ]; then
    git config peal.projectHooks "$prev" || return 2
  fi
  git config core.hooksPath "$dir" || return 2
  peal_write_root "${dir%/peal/hooks}" || return 2
  chain=$(git config peal.projectHooks) || chain="${dir%/peal/hooks}/hooks"
  echo "installed Peal's git hooks in $dir (core.hooksPath); they chain to the hooks in $chain"
}

# peal_hooks_uninstall -> what peal_hooks_install did taken back: core.hooksPath back to
# the hooks path it replaced (peal.projectHooks), or unset, every peal.* key of the
# repository's config, the stubs and the recorded root removed.
peal_hooks_uninstall() {
  local dir prev now key
  dir=$(_peal_hooks_dir) || return 2
  if [ "$(git config core.hooksPath)" = "$dir" ]; then
    if prev=$(git config peal.projectHooks); then
      git config core.hooksPath "$prev" || return 2
    else
      git config --unset core.hooksPath || return 2
    fi
  fi
  git config --local --name-only --get-regexp '^peal\.' 2>/dev/null | sort -u | while IFS= read -r key; do
    git config --local --unset-all "$key"
  done
  git config --local --remove-section peal 2>/dev/null
  [ ! -d "${dir%/hooks}" ] || rm -rf "${dir%/hooks}" || return 2
  rm -f "${dir%/peal/hooks}/$PEAL_ROOT_RECORD" || return 2
  now=$(git config core.hooksPath) || now="unset"
  echo "removed Peal's git hooks from $dir; core.hooksPath is $now"
}

# peal_hooks_installed -> status 0 if core.hooksPath points at Peal's stubs.
peal_hooks_installed() {
  local dir
  dir=$(_peal_hooks_dir) || return 2
  [ "$(git config core.hooksPath)" = "$dir" ] && [ -x "$dir/commit-msg" ] && [ -x "$dir/pre-push" ]
}

# peal_hooks_required -> status 0 if the committed config records the `guardrails` stage:
# only then does the project ask for its commits and closes to be gated, so only then do
# `peal commit` and `peal close` refuse without Peal's git hooks. A project at the `tasks`
# stage alone runs them ungated. The caller's config must already be loaded.
peal_hooks_required() {
  peal_config_get stages 2>/dev/null | grep -qx guardrails
}

# peal_hooks_ensure -> a fresh clone whose committed config records the `guardrails`
# stage gets its git gates without a manual step: the caller's config must already be
# loaded (peal_config_load). Silent and a no-op when `guardrails` is not in `stages`, or
# the hooks are installed already. A `core.hooksPath` that already points elsewhere (not
# a stale path to these stubs) is left alone: one warning on stderr, naming the install
# that would chain to it, and nothing is installed. Otherwise `peal_hooks_install` runs,
# and its `installed Peal's git hooks in …` line goes to stdout. A failed install (its
# reason, if any, from `peal_hooks_install`'s own stderr) is reported on stderr with the
# command to run. Always returns 0: a session's start or claim is never refused by this.
peal_hooks_ensure() {
  local dir prev out reason
  peal_hooks_required || return 0
  peal_hooks_installed && return 0
  dir=$(_peal_hooks_dir 2>/dev/null) || return 0
  prev=$(git config core.hooksPath 2>/dev/null) || prev=""
  if [ -n "$prev" ] && [ "$prev" != "$dir" ]; then
    peal_err "Peal's git hooks are not installed: core.hooksPath is $prev; to install them chained to it, run: .peal/peal hooks install"
    return 0
  fi
  if out=$(peal_hooks_install 2>&1); then
    printf '%s\n' "$out"
  else
    reason=${out#peal: }
    peal_err "Peal's git hooks could not be installed (${reason:-see above}); run: .peal/peal hooks install"
  fi
  return 0
}

# _peal_gate_refuse HOOK MESSAGE [LINE...] -> the refusal on stderr; PEAL_GATE_FAIL set.
_peal_gate_refuse() {
  local hook=$1
  printf '%s: %s\n' "$hook" "$2" >&2
  shift 2
  [ $# -eq 0 ] || printf '%s\n' "$@" | sed 's/^/  /' >&2
  PEAL_GATE_FAIL=1
}

# peal_githook NAME ARGS... -> the gate of hook NAME; status 1 when it refuses.
peal_githook() {
  local name=$1
  shift
  PEAL_GATE_FAIL=0
  if ! peal_config_load; then
    echo "$name: Peal's settings do not load (above); the $name is refused until they do" >&2
    return 1
  fi
  case $name in
    pre-push) _peal_pre_push ;;
    commit-msg)
      [ $# -ge 1 ] || { peal_err "githook commit-msg: the message file"; return 2; }
      _peal_commit_msg "$1"
      ;;
    *) peal_err "githook: no gate for $name"; return 2 ;;
  esac
}

# --- pre-push ----------------------------------------------------------------------------
# Lets through to the main branch only what the storage writes there directly. Every
# commit the push adds to main's first-parent line is a commit the storage made, told by
# its subject and checked by its diff's shape (the subject alone is only a string the
# caller chose); a merge is never one (a remote-tracking ref is a local file, so "merged
# a pushed branch" proves nothing):
#       docs(tasks): file ...                  only added backlog task files
#       docs(tasks): revise|defer ID ...       exactly one modified backlog task file, ID's
#       docs(tasks): set milestone of ID ...
#       docs(tasks): note on ID ...
#       docs(tasks): retire ID ...             ID's backlog file moved to done/, unrenamed
#       docs(tasks): apply N proposal(s)       the subject exactly so; only added or
#                                              modified backlog task files, backlog files
#                                              moved to done/, unrenamed, and added or
#                                              modified milestone files (peal apply)
#       docs(decisions): regenerate the index  only the decisions index added or changed
#                                              (peal decision publish)
#       docs(tasks): milestone ID STATE ...    one or two modified milestone files (the
#                                              milestone's, and the one made current)
#       chore(release): <tag>                  only files of release.version-files
#                                              modified, each exactly as the version
#                                              written into its parent's, and
#                                              release.changelog modified (or added as
#                                              "# Changelog") by one entry "## <tag>"
#                                              inserted after its title (peal ship bump)
#       chore(release): pin <tag>              only files of release.commit-files
#                                              modified, each exactly as the SHA of the
#                                              tag's commit written into its parent's;
#                                              the tag known locally, its commit before
#                                              this one (peal ship pin)
# The backlog task files a file, revise, defer, set-milestone, note or apply commit adds or
# modifies are read too (_peal_pre_push_content): their frontmatter parses, before and
# after; merge is never added or changed; origin is never dropped or changed, but by an
# apply commit whose body vouches for the task; the Plan and the Outcome never go from
# empty to filled; an added file never sets merge, nor brings a filled Plan or Outcome
# with origin: outsider. A shape-only check let "docs(tasks): revise ..." carry any text.
# The first push of main (the remote has none) is refused in one line: which commits it
# adds would be told by the local remote-tracking refs, files anyone can fake, and the
# hook makes no network call; it is the human's own push, outside this gate. Rewriting
# main (not a fast-forward) and deleting it are refused, and so is a merge made
# on this machine. Git runs no pre-push for a merge made on the server (a pull request's),
# so this never stands in its way. A guard against honest mistakes: branch protection on
# main is what stops a deliberate push.
# Known limits: the main branch and the tasks and milestones directories are this
# worktree's settings; a Plan filled already may be rewritten; the subject and the vouch
# line are only strings the caller chose.

_peal_pre_push() {
  local main tasks milestones lsha rref rsha range sha parents
  main=$(peal_config_get main) || return 1
  tasks=$(peal_config_get tasks) || return 1
  tasks=${tasks%/}
  milestones=$(peal_config_get milestones) || return 1
  milestones=${milestones%/}
  while IFS=' ' read -r _ lsha rref rsha; do
    [ "$rref" = "refs/heads/$main" ] || continue
    if [[ "$lsha" =~ ^0+$ ]]; then
      _peal_gate_refuse pre-push "the push deletes $main; never."
      continue
    fi
    if [[ "$rsha" =~ ^0+$ ]]; then
      _peal_gate_refuse pre-push "the remote has no $main; its first push is the human's own, outside Peal's gate."
      continue
    elif ! git merge-base --is-ancestor "$rsha" "$lsha" 2>/dev/null; then
      _peal_gate_refuse pre-push "the push to $main is not a fast-forward: $main is never rewritten."
      continue
    else
      range="$rsha..$lsha"
    fi
    # shellcheck disable=SC2086 # the range is several words
    for sha in $(git rev-list --first-parent $range); do
      parents=$(git show -s --format=%P "$sha" | wc -w)
      if [ "$parents" -gt 1 ]; then
        _peal_gate_refuse pre-push \
          "$(git rev-parse --short "$sha") is a merge made here onto $main; a merge reaches $main as a pull request, made on the server."
      else
        _peal_pre_push_direct "$sha" "$main" "$tasks" "$milestones"
      fi
    done
  done
  [ "$PEAL_GATE_FAIL" = 0 ] || {
    echo "pre-push: nothing reaches $main but a merged pull request and Peal's own writes (peal create, revise, retire, ...)." >&2
    return 1
  }
}

# _peal_pre_push_direct SHA MAIN TASKS MILESTONES -> refused unless SHA is one of the
# storage's writes, by subject and by the shape of its diff.
_peal_pre_push_direct() {
  local sha=$1 main=$2 tasks=$3 milestones=$4 subject shape id diff short why
  subject=$(git show -s --format=%s "$sha")
  short=$(git rev-parse --short "$sha")
  case $subject in
    'docs(tasks): file '*) shape=add ;;
    'docs(tasks): revise '* | 'docs(tasks): defer '* | 'docs(tasks): set milestone of '* | 'docs(tasks): note on '*) shape=modify ;;
    'docs(tasks): retire '*) shape=retire ;;
    'docs(tasks): apply '*)
      if [[ ! "$subject" =~ ^docs\(tasks\):\ apply\ [1-9][0-9]*\ proposals?$ ]]; then
        _peal_gate_refuse pre-push "$short reaches $main directly and is none of Peal's own writes: \"$subject\""
        return
      fi
      shape=apply ;;
    'docs(decisions): regenerate the index')
      _peal_pre_push_index "$sha" "$main" "$short" "$subject"
      return
      ;;
    'docs(tasks): milestone '*) shape=milestone ;;
    'chore(release): pin '*)
      _peal_pre_push_pin "$sha" "$main" "$short" "$subject"
      return
      ;;
    'chore(release): '*)
      _peal_pre_push_release "$sha" "$main" "$short" "$subject"
      return
      ;;
    *)
      _peal_gate_refuse pre-push "$short reaches $main directly and is none of Peal's own writes: \"$subject\""
      return
      ;;
  esac
  id=""
  [[ "$subject" =~ \[([0-9][0-9][0-9][0-9])\]$ ]] && id=${BASH_REMATCH[1]}
  diff=$(git diff-tree -r --raw --no-commit-id --no-renames --root "$sha")
  if ! why=$(printf '%s\n' "$diff" | awk -v shape="$shape" -v tasks="$tasks" -v ms="$milestones" -v id="$id" '
      function bad(why) { print why; failed = 1; exit 1 }
      function task(p, dir,    f) {
        if (index(p, tasks "/" dir "/") != 1) return ""
        f = substr(p, length(tasks) + length(dir) + 3)
        return f ~ /^[0-9][0-9][0-9][0-9]-[^\/]+\.md$/ ? f : ""
      }
      $0 == "" { next }
      {
        split($0, f, "\t"); path = f[2]
        split(f[1], m, " "); omode = substr(m[1], 2); nmode = m[2]; st = m[5]
        n++
        if (shape == "milestone") {
          if (st != "M" || omode != "100644" || nmode != "100644" || index(path, ms "/") != 1 \
              || substr(path, length(ms) + 2) !~ /^[^\/]+\.md$/)
            bad("not a modified milestone file: " st " " nmode " " path)
        } else if (shape == "add") {
          if (st != "A" || nmode != "100644" || task(path, "backlog") == "")
            bad("not an added backlog task file: " st " " nmode " " path)
        } else if (shape == "apply") {
          if ((st == "A" || st == "M") && task(path, "backlog") != "" && nmode == "100644" && (st == "A" || omode == "100644")) {
          } else if ((st == "A" || st == "M") && index(path, ms "/") == 1 && substr(path, length(ms) + 2) ~ /^[^\/]+\.md$/ \
              && nmode == "100644" && (st == "A" || omode == "100644")) {
          } else if (st == "D" && task(path, "backlog") != "" && omode == "100644") gones[task(path, "backlog")]++
          else if (st == "A" && task(path, "done") != "" && nmode == "100644") cames[task(path, "done")]++
          else bad("not an added or modified backlog task or milestone file, nor a task file moved to done/: " st " " nmode " " path)
        } else if (shape == "modify") {
          if (st != "M" || omode != "100644" || nmode != "100644" || task(path, "backlog") == "")
            bad("not a modified backlog task file: " st " " nmode " " path)
          if (substr(task(path, "backlog"), 1, 4) != id) bad("not the file of task " id ": " path)
        } else {
          if (st == "D" && task(path, "backlog") != "" && omode == "100644") gone = task(path, "backlog")
          else if (st == "A" && task(path, "done") != "" && nmode == "100644") came = task(path, "done")
          else bad("neither a deleted backlog nor an added done task file: " st " " nmode " " path)
        }
      }
      END {
        if (failed) exit 1
        if (n == 0) { print "the diff is empty"; exit 1 }
        if (shape == "apply") {
          for (g in gones) if (!(g in cames)) { print "a backlog task file deleted, not moved to done/ as it is named: " g; exit 1 }
          for (g in cames) if (!(g in gones)) { print "a done task file added that left no backlog file: " g; exit 1 }
        }
        if (shape == "modify" && n != 1) { print n " files changed, not one"; exit 1 }
        if (shape == "milestone" && n > 2) { print n " milestone files changed, not one or two"; exit 1 }
        if (shape == "retire" && (n != 2 || gone == "" || gone != came)) { print "not one backlog task file moved to done/ as it is named"; exit 1 }
        if (shape == "retire" && substr(gone, 1, 4) != id) { print "not the file of task " id ": " gone; exit 1 }
      }'); then
    _peal_gate_refuse pre-push "$short reaches $main directly as \"$subject\", but its diff is not that shape:" "$why"
    return
  fi
  case $shape in
    add | modify | apply) _peal_pre_push_content "$sha" "$main" "$short" "$subject" "$shape" "$tasks" "$diff" ;;
  esac
}

# _peal_pre_push_guard BLOB NAME -> merge-gate.awk's guard verdict on the blob: "bad", or
# "ok", the merge and origin records and the filled Plan and Outcome. NAME is the path,
# made printable for yaml-lib.awk's messages.
_peal_pre_push_guard() {
  # shellcheck disable=SC1003 # tr reads the escaped backslash itself
  git cat-file blob "$1" | awk -v guard=1 \
    -v name="$(printf '%s' "$2" | LC_ALL=C tr -c '[:print:]' '?' | LC_ALL=C tr '\\' '?')" \
    -f "$PEAL_ROOT/lib/yaml-lib.awk" -f "$PEAL_ROOT/lib/merge-gate.awk"
}

# _peal_pre_push_content SHA MAIN SHORT SUBJECT SHAPE TASKS DIFF -> refused unless every
# backlog task file the commit adds or modifies (DIFF, its --raw lines) keeps what only
# the human, the close or a vouch writes: the frontmatter parses before and after; merge
# is not added or changed (the human's consent to a merge); origin is not dropped or
# changed (an outsider's mark), but by an apply commit whose body holds the vouch line
# "- <id> (vouch NNNN): " for that task; the Plan and the Outcome do not go from empty to
# filled (a filled Plan reads as agreed to peal work). An added file is held to peal
# create's checks: no merge, and no filled Plan or Outcome with origin: outsider.
_peal_pre_push_content() {
  local sha=$1 main=$2 short=$3 subject=$4 shape=$5 tasks=$6 diff=$7 body line meta path
  local st osha nsha file nid old new oldk newk sec problems=()
  body=$(git show -s --format=%b "$sha")
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    meta=${line%%$'\t'*}
    path=${line#*$'\t'}
    read -r _ _ osha nsha st <<<"$meta"
    case $st in A | M) ;; *) continue ;; esac
    case $path in "$tasks"/backlog/*) ;; *) continue ;; esac
    file=${path##*/}
    nid=${file:0:4}
    new=$(_peal_pre_push_guard "$nsha" "$path") || { problems+=("$path: cannot be read"); continue; }
    if [ "${new%%$'\n'*}" != ok ]; then
      problems+=("$path: its frontmatter does not parse")
      continue
    fi
    if [ "$st" = A ]; then
      if grep -q '^merge'$'\t' <<<"$new"; then problems+=("$path: sets merge; only the human sets merge: auto"); fi
      if grep -q '^filled'$'\t' <<<"$new" && grep -qx 'origin'$'\t''s'$'\t''outsider' <<<"$new"; then
        problems+=("$path: an outsider's new task with a filled $(grep '^filled' <<<"$new" | head -n 1 | cut -f 2); only the human's agreement writes one")
      fi
      continue
    fi
    old=$(_peal_pre_push_guard "$osha" "$path") || { problems+=("$path: cannot be read"); continue; }
    if [ "${old%%$'\n'*}" != ok ]; then
      problems+=("$path: its frontmatter did not parse before")
      continue
    fi
    newk=$(grep '^merge'$'\t' <<<"$new")
    oldk=$(grep '^merge'$'\t' <<<"$old")
    if [ -n "$newk" ] && [ "$newk" != "$oldk" ]; then
      problems+=("$path: sets merge; only the human sets merge: auto")
    fi
    newk=$(grep '^origin'$'\t' <<<"$new")
    oldk=$(grep '^origin'$'\t' <<<"$old")
    if [ -n "$oldk" ] && [ "$newk" != "$oldk" ]; then
      if [ "$shape" = apply ] && [ -z "$newk" ] && [ "$oldk" = $'origin\ts\toutsider' ] \
          && grep -Eq "^- .+ \(vouch $nid\): " <<<"$body"; then
        :
      else
        problems+=("$path: drops or changes origin; only a vouch (peal apply) drops origin: outsider")
      fi
    fi
    for sec in Plan Outcome; do
      if grep -qx "filled"$'\t'"$sec" <<<"$new" && ! grep -qx "filled"$'\t'"$sec" <<<"$old"; then
        problems+=("$path: fills the $sec; only planning or the close fills it")
      fi
    done
  done <<<"$diff"
  [ ${#problems[@]} -eq 0 ] \
    || _peal_gate_refuse pre-push "$short reaches $main directly as \"$subject\", but it changes what only the human writes:" "${problems[@]}"
}

# _peal_pre_push_index SHA MAIN SHORT SUBJECT -> refused unless SHA adds or changes the
# decisions index and nothing else, the decisions module on.
_peal_pre_push_index() {
  local dir diff
  if ! dir=$(peal_decisions_dir 2>/dev/null); then
    _peal_gate_refuse pre-push "$3 reaches $2 directly as \"$4\", but the decisions module is off"
    return
  fi
  diff=$(git diff-tree -r --raw --no-commit-id --no-renames --root "$1")
  if ! printf '%s\n' "$diff" | awk -v path="$dir/index.md" '
      $0 == "" { next }
      { split($0, f, "\t"); split(f[1], m, " "); n++
        if (f[2] != path || m[2] != "100644" || (m[5] != "A" && m[5] != "M")) bad = 1 }
      END { exit bad || n != 1 }'; then
    _peal_gate_refuse pre-push "$3 reaches $2 directly as \"$4\", but its diff is not the index alone:" "$diff"
  fi
}

# _peal_release_tag LEAD PREFIX SHORT MAIN SUBJECT -> PEAL_GATE_TAG, the release tag
# (PREFIX, then MAJOR.MINOR.PATCH with an optional pre-release) that follows LEAD in
# SUBJECT; status 1 and a refusal when SUBJECT names none.
_peal_release_tag() {
  local tag=${5#"$1"}
  if [ "${tag#"$2"}" = "$tag" ] && [ -n "$2" ] \
      || ! [[ "${tag#"$2"}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$ ]]; then
    _peal_gate_refuse pre-push "$3 reaches $4 directly as \"$5\", which names no release tag ($2MAJOR.MINOR.PATCH)"
    return 1
  fi
  PEAL_GATE_TAG=$tag
}

# _peal_pre_push_release SHA MAIN SHORT SUBJECT -> refused unless SHA's subject names a
# release tag, and its diff only modifies files of release.version-files, each exactly
# what setting its field or marked line to that version makes of its parent's
# (peal_version_edit), and release.changelog, the parent's with one entry of that tag
# inserted, or added as a new changelog holding that entry (peal_changelog_shape: its
# shape, not its text).
_peal_pre_push_release() {
  local sha=$1 short=$3 subject=$4 prefix files changelog version tag diff line mode path field why="" dir n=0 shape
  prefix=$(peal_config_get release.tag-prefix) || return 1
  _peal_release_tag "chore(release): " "$prefix" "$short" "$2" "$subject" || return
  tag=$PEAL_GATE_TAG
  version=${tag#"$prefix"}
  if ! files=$(peal_version_files 2>&1); then
    _peal_gate_refuse pre-push "$short reaches $2 directly as \"$subject\", but release.version-files is not right:" "$files"
    return
  fi
  if ! changelog=$(peal_changelog_file 2>&1); then
    _peal_gate_refuse pre-push "$short reaches $2 directly as \"$subject\", but release.changelog is not right:" "$changelog"
    return
  fi
  diff=$(git diff-tree -r --raw --no-commit-id --no-renames --root "$sha")
  dir=$(mktemp -d) || return 1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    path=${line#*$'\t'}
    mode=${line%%$'\t'*}
    field=$(awk -F '\t' -v p="$path" '$1 == p { print $2; exit }' <<<"$files")
    if [ -n "$changelog" ] && [ "$path" = "$changelog" ]; then
      if [[ "$mode" == ":100644 100644 "*" M" ]]; then
        git show "$sha^:$path" >"$dir/old" 2>/dev/null || why="$path: not in the parent"
      elif [[ "$mode" == ":000000 100644 "*" A" ]]; then
        printf '%s' "$PEAL_CHANGELOG_NEW" >"$dir/old"
      else
        why="not a modified or added plain file: $path"
      fi
      if [ -z "$why" ] && ! git show "$sha:$path" >"$dir/new" 2>/dev/null; then
        why="$path: not in the commit"
      fi
      if [ -z "$why" ] && ! shape=$(peal_changelog_shape "$dir/old" "$dir/new" "$tag"); then
        why="$path: $shape"
      fi
    elif [ -z "$field" ]; then
      why="not a file of release.version-files: $path"
    elif [[ "$mode" != ":100644 100644 "*" M" ]]; then
      why="not a modified plain file: $path"
    elif ! git show "$sha^:$path" >"$dir/old" 2>/dev/null \
        || ! peal_version_edit "$path" "$field" "$version" "$dir/old" >"$dir/new" 2>"$dir/err"; then
      why="$path: $(sed 's/^peal: //' "$dir/err" 2>/dev/null)"
    elif ! git show "$sha:$path" | cmp -s - "$dir/new"; then
      why="$path changes more than its $field to $version"
    fi
    [ -z "$why" ] || break
  done <<<"$diff"
  rm -rf "$dir"
  [ -n "$why" ] || [ $n -gt 0 ] || why="the diff is empty"
  [ -z "$why" ] || _peal_gate_refuse pre-push "$short reaches $2 directly as \"$subject\", but its diff is not that shape:" "$why"
}

# _peal_pre_push_pin SHA MAIN SHORT SUBJECT -> refused unless SHA's subject names a
# release tag that exists locally, whose commit is an ancestor of SHA's parent, and its
# diff only modifies files of release.commit-files, each exactly what setting its marked
# line's object name to the tag's commit makes of its parent's (peal_commit_edit). The
# tag is looked up locally only (a push runs no network): a tag made up locally passes
# as far as this goes (docs/security.md).
_peal_pre_push_pin() {
  local sha=$1 short=$3 subject=$4 prefix files version tag diff line mode path text why="" dir n=0 tsha
  prefix=$(peal_config_get release.tag-prefix) || return 1
  _peal_release_tag "chore(release): pin " "$prefix" "$short" "$2" "$subject" || return
  tag=$PEAL_GATE_TAG
  if ! tsha=$(git rev-parse -q --verify "refs/tags/$tag^{commit}"); then
    _peal_gate_refuse pre-push "$short reaches $2 directly as \"$subject\", but the tag $tag is not here" "git fetch --tags"
    return
  fi
  if ! git merge-base --is-ancestor "$tsha" "$sha^" 2>/dev/null; then
    _peal_gate_refuse pre-push "$short reaches $2 directly as \"$subject\", but the commit of $tag is not before it"
    return
  fi
  if ! files=$(peal_commit_files 2>&1); then
    _peal_gate_refuse pre-push "$short reaches $2 directly as \"$subject\", but release.commit-files is not right:" "$files"
    return
  fi
  diff=$(git diff-tree -r --raw --no-commit-id --no-renames --root "$sha")
  dir=$(mktemp -d) || return 1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    path=${line#*$'\t'}
    mode=${line%%$'\t'*}
    text=$(awk -F '\t' -v p="$path" '$1 == p { print $2; exit }' <<<"$files")
    if [ -z "$text" ]; then
      why="not a file of release.commit-files: $path"
    elif [[ "$mode" != ":100644 100644 "*" M" ]]; then
      why="not a modified plain file: $path"
    elif ! git show "$sha^:$path" >"$dir/old" 2>/dev/null \
        || ! peal_commit_edit "$path" "$text" "$tsha" "$dir/old" >"$dir/new" 2>"$dir/err"; then
      why="$path: $(sed 's/^peal: //' "$dir/err" 2>/dev/null)"
    elif ! git show "$sha:$path" | cmp -s - "$dir/new"; then
      why="$path changes more than its commit SHA to $tsha"
    fi
    [ -z "$why" ] || break
  done <<<"$diff"
  rm -rf "$dir"
  [ -n "$why" ] || [ $n -gt 0 ] || why="the diff is empty"
  [ -z "$why" ] || _peal_gate_refuse pre-push "$short reaches $2 directly as \"$subject\", but its diff is not that shape:" "$why"
}

# --- commit-msg --------------------------------------------------------------------------
# The subject: <type>(<area>): <what> [NNNN], type one of PEAL_COMMIT_TYPES, the area one
# of commit.areas (required when there are any; `tasks` is always one, and `decisions`
# with the decisions module on), NNNN the task's id (a task file's four digits, an
# issue's number), required on a task's branch and optional on any other named branch.
# Git's own subjects pass as they are (Revert, fixup!, squash!, amend!); a merge's is not
# checked, but its diff pays the checks. Two fast paths skip the checks:
#   wip: ... / wip(<area>): ...   honest work in progress, no task id needed;
#   <type>(tasks): ... [NNNN]     a task file's move or edit: the staged diff must lie in
#                                 the tasks directory and nowhere else;
#   <type>(decisions): ... [NNNN] decision entries, the same in the decisions directory;
#   chore(peal): ...              a project's Peal setup (/peal:setup), no task id
#                                 needed: the staged diff must lie in what peal init
#                                 writes (.peal/, .claude/settings.json, .belfry.yml, the
#                                 tasks and milestones directories).
# Otherwise each of checks.commit runs whose paths the staged diff touches: an item
# "PATH...: COMMAND" runs COMMAND when a staged path is PATH or under it (PATH may be a
# glob), an item without paths always runs.

# _peal_subject FILE -> the message's first line that is neither empty nor a comment.
_peal_subject() {
  awk '/^#/ || /^[ \t]*$/ { next } { print; exit }' "$1"
}

# _peal_staged -> every path the commit changes, both sides of a rename.
_peal_staged() {
  git diff --cached --name-only --no-renames
}

# _peal_off_task_branch -> 0 on a named branch that is no task's: work that is not a
# task, whose subject needs no id. The storage says what a task's branch is (task/NNNN-slug
# for files, issue/N for issues). A detached HEAD, or settings that do not load, count as a
# task's branch. In a subshell, so the storage's functions stay out of the gate.
_peal_off_task_branch() {
  git symbolic-ref -q HEAD >/dev/null || return 1
  (
    peal_store_load 2>/dev/null || exit 1
    ! peal_store_branch_task >/dev/null
  )
}

_peal_commit_msg() {
  local subject merge=0 area what areas tasks outside decisions
  subject=$(_peal_subject "$1")
  case $subject in
    "Revert "* | "fixup! "* | "squash! "* | "amend! "*) return 0 ;;
    "Merge "*) merge=1 ;;
  esac
  if [ $merge = 0 ]; then
    if ! [[ "$subject" =~ $PEAL_SUBJECT_RE ]]; then
      _peal_gate_refuse commit-msg "the subject is not <type>(<area>): <what> [NNNN]: \"$subject\"" \
        "types: $PEAL_COMMIT_TYPES; wip: <what> for work in progress"
      return 1
    fi
    area=${BASH_REMATCH[3]} what=${BASH_REMATCH[4]}
    if [ "${subject%%[(:]*}" = wip ]; then
      echo "commit-msg: a wip commit; the checks are skipped. Say what is in flight in the task's Outcome."
      return 0
    fi
    areas=$(peal_config_get commit.areas) || return 1
    decisions=$(peal_decisions_dir 2>/dev/null) || decisions=""
    if [ -n "$areas" ] && [ -z "$area" ]; then
      _peal_gate_refuse commit-msg "the subject names no area: <type>(<area>): ..." \
        "areas: $(printf '%s\n' "$areas" tasks ${decisions:+decisions} | tr '\n' ' ')"
      return 1
    fi
    if [ "${subject%%:*}" = "chore(peal)" ]; then
      _peal_setup_commit
      return
    fi
    if [ -n "$areas" ] && [ "$area" != tasks ] && { [ -z "$decisions" ] || [ "$area" != decisions ]; } \
        && ! printf '%s\n' "$areas" | grep -qxF -- "$area"; then
      _peal_gate_refuse commit-msg "the area $area is not one of commit.areas" \
        "areas: $(printf '%s\n' "$areas" tasks ${decisions:+decisions} | tr '\n' ' ')"
      return 1
    fi
    if ! [[ "$what" =~ ^(.*[^ ])\ \[[0-9]+\]$ ]] && ! _peal_off_task_branch; then
      _peal_gate_refuse commit-msg "the subject does not end with its task id, as in \"feat(x): what [0042]\"" \
        "subject: $subject"
      return 1
    fi
    if [ "$area" = tasks ]; then
      tasks=$(peal_config_get tasks) || return 1
      tasks=${tasks%/}
      outside=$(_peal_staged | awk -v t="$tasks/" 'index($0, t) != 1')
      if [ -n "$outside" ]; then
        _peal_gate_refuse commit-msg "a ($area) commit touches only $tasks/; this one also:" "$outside"
        return 1
      fi
      echo "commit-msg: only task files; the checks are skipped."
      return 0
    fi
    if [ "$area" = decisions ] && [ -n "$decisions" ]; then
      outside=$(_peal_staged | awk -v d="$decisions/" 'index($0, d) != 1')
      if [ -n "$outside" ]; then
        _peal_gate_refuse commit-msg "a ($area) commit touches only $decisions/; this one also:" "$outside"
        return 1
      fi
      echo "commit-msg: only decision entries; the checks are skipped."
      return 0
    fi
  fi
  _peal_commit_checks "$merge"
}

# _peal_setup_commit -> refused unless every staged path is one peal init writes.
_peal_setup_commit() {
  local tasks milestones outside
  tasks=$(peal_config_get tasks) || return 1
  milestones=$(peal_config_get milestones) || return 1
  outside=$(_peal_staged | awk -v t="${tasks%/}/" -v m="${milestones%/}/" '
    index($0, ".peal/") != 1 && $0 != ".claude/settings.json" && $0 != ".belfry.yml" \
      && index($0, t) != 1 && index($0, m) != 1')
  if [ -n "$outside" ]; then
    _peal_gate_refuse commit-msg "a (peal) commit is Peal's setup: .peal/, .claude/settings.json, .belfry.yml, ${tasks%/}/ and ${milestones%/}/ only; this one also:" "$outside"
    return 1
  fi
  echo "commit-msg: Peal's setup only; the checks are skipped."
}

# _peal_check_split ITEM -> PEAL_CHECK_PATHS and PEAL_CHECK_CMD from "PATH...: COMMAND";
# no paths for an item that does not start with plain path words and ": ".
_peal_check_split() {
  local re='^([^- :;&|<>$"'\''=][^ :;&|<>$"'\''=]*( +[^- :;&|<>$"'\''=][^ :;&|<>$"'\''=]*)*): +(.+)$'
  if [[ "$1" =~ $re ]]; then
    PEAL_CHECK_PATHS=${BASH_REMATCH[1]} PEAL_CHECK_CMD=${BASH_REMATCH[3]}
  else
    PEAL_CHECK_PATHS="" PEAL_CHECK_CMD=$1
  fi
}

# _peal_check_applies PATHS STAGED -> status 0 if a staged path is one of PATHS or under
# it; always for no PATHS.
_peal_check_applies() {
  local pattern file
  [ -n "$1" ] || return 0
  for pattern in $1; do
    pattern=${pattern%/}
    while IFS= read -r file; do
      # shellcheck disable=SC2254 # the pattern is a glob on purpose
      case $file in $pattern | $pattern/*) return 0 ;; esac
    done <<<"$2"
  done
  return 1
}

# _peal_commit_checks MERGE -> each applicable check of checks.commit run from the top of
# the work tree, git's variables for this hook unset so a check's own git calls see its
# repository plainly; status 1 at the first that fails.
_peal_commit_checks() {
  local merge=$1 checks staged item top ran=0 remedy="Fix it, or commit as 'wip: ...'."
  [ "$merge" = 0 ] || remedy="Fix it and commit again, or give up the merge with git merge --abort."
  checks=$(peal_config_get checks.commit) || return 1
  [ -n "$checks" ] || return 0
  staged=$(_peal_staged)
  top=$(git rev-parse --show-toplevel) || return 1
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    _peal_check_split "$item"
    _peal_check_applies "$PEAL_CHECK_PATHS" "$staged" || continue
    ran=1
    echo "commit-msg: running $PEAL_CHECK_CMD"
    # shellcheck disable=SC2046 # the names of the variables to unset
    if ! (cd "$top" && unset $(compgen -v GIT_) && bash -c "$PEAL_CHECK_CMD") </dev/null; then
      _peal_gate_refuse commit-msg "$PEAL_CHECK_CMD failed; the commit is refused. $remedy"
      return 1
    fi
  done <<<"$checks"
  [ $ran = 1 ] && echo "commit-msg: the checks passed." || echo "commit-msg: no check applies to this diff."
}
