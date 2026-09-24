# shellcheck shell=bash
# Releases (docs/design.md, "Releases"): what /peal:release makes a release from, the
# tasks finished since the last release tag, and its steps, each rerunnable on its own:
# the proposal, the notes, the tag, the GitHub release, the wait for the tag's workflow
# runs. `peal release` is taken by the claims; these are `peal ship ...`.
#
# A release tag is <release.tag-prefix>MAJOR.MINOR.PATCH (a pre-release suffix "-rc.1"
# allowed when named, never counted as the last release). What went in since the last
# one is read from the main branch's commits, squash merges as the close's pull requests
# make them ("Title [ID] (#PR)"):
#
#   files   each task file the range adds under done/, but those retired
#           ("docs(tasks): retire ..."); its title, the first sentence of its Outcome,
#           its frontmatter; the pull request from the commit adding it
#   issues  each issue a commit subject of the range names ("[42]") that is closed as
#           completed; its title and labels, the first sentence of the Outcome its first
#           pull request's body holds
#
# and, for both, the commits typed feat or fix that belong to no such task. A task is
# breaking with "breaking: true" (a label "breaking" or "breaking: true") or a subject
# "type!:", a fix when its commit's subject starts "fix" or the issue is labelled
# "bug", a feature otherwise; "release-note: none" (field or label) leaves it out of
# the notes and the version.

PEAL_SHIP_SECTIONS="breaking:Breaking feature:Features fix:Fixes"

# _peal_ship_settings -> PEAL_REMOTE, PEAL_MAIN, PEAL_TASKS, PEAL_KIND, PEAL_PREFIX and
# PEAL_GH_REPO (owner/name, empty when the remote is not on GitHub); the remote fetched,
# its tags too.
_peal_ship_settings() {
  PEAL_REMOTE=$(peal_config_get remote) || return 2
  PEAL_MAIN=$(peal_config_get main) || return 2
  PEAL_TASKS=$(peal_config_get tasks) || return 2
  PEAL_KIND=$(peal_config_get storage.kind) || return 2
  PEAL_PREFIX=$(peal_config_get release.tag-prefix) || return 2
  PEAL_GH_REPO=$(peal_config_get storage.issues.repo) || return 2
  # The remote's own URL, not what a local insteadOf makes of it.
  [ -n "$PEAL_GH_REPO" ] \
    || PEAL_GH_REPO=$(peal_github_repo_of "$(git config --get "remote.$PEAL_REMOTE.url")") || PEAL_GH_REPO=""
  if ! git fetch -q --tags "$PEAL_REMOTE" 2>/dev/null; then
    peal_err "could not fetch $PEAL_REMOTE"
    return 2
  fi
  git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN^{commit}" >/dev/null || {
    peal_err "no $PEAL_REMOTE/$PEAL_MAIN"
    return 2
  }
}

# _peal_ship_version V -> the tag V names ("1.2.0" or "v1.2.0" with the prefix v);
# status 2 and a message for anything but a version.
_peal_ship_version() {
  local v=$1
  [ -z "$PEAL_PREFIX" ] || v=${v#"$PEAL_PREFIX"}
  v=${v#v}
  if ! [[ "$v" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$ ]]; then
    peal_err "'$1' is no version: MAJOR.MINOR.PATCH, e.g. ${PEAL_PREFIX}1.2.0"
    return 2
  fi
  printf '%s%s\n' "$PEAL_PREFIX" "$v"
}

# _peal_ship_last END [TAG] -> the last release before TAG: the highest release tag
# (no pre-release suffix) reachable from END, TAG left out, and lower than TAG when
# given; nothing when there is none.
_peal_ship_last() {
  git tag -l --merged "$1" "${PEAL_PREFIX}*" | awk -v p="$PEAL_PREFIX" -v tag="${2-}" '
    # key(t, pre) -> the version of t as a sortable key; "" for no version, or for a
    # pre-release unless pre.
    function key(t, pre,    v, a) {
      v = substr(t, length(p) + 1)
      if (v !~ ("^[0-9]+[.][0-9]+[.][0-9]+" (pre ? "(-.*)?" : "") "$")) return ""
      split(v, a, /[.-]/)
      return sprintf("%09d%09d%09d", a[1], a[2], a[3])
    }
    BEGIN { limit = (tag == "" ? "" : key(tag, 1)) }
    $0 != tag {
      k = key($0, 0)
      if (k == "" || (limit != "" && k >= limit)) next
      if (k > best) { best = k; last = $0 }
    }
    END { if (last != "") print last }'
}

# _peal_ship_range [TAG] -> PEAL_END (TAG when it exists, else the remote's main),
# PEAL_LAST (the release before it, or empty) and PEAL_RANGE (git log's range).
_peal_ship_range() {
  local tag=${1-}
  if [ -n "$tag" ] && git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    PEAL_END=$tag
  else
    PEAL_END=$PEAL_REMOTE/$PEAL_MAIN
  fi
  PEAL_LAST=$(_peal_ship_last "$PEAL_END" "$tag")
  PEAL_RANGE=$PEAL_END
  [ -z "$PEAL_LAST" ] || PEAL_RANGE="$PEAL_LAST..$PEAL_END"
}

# _peal_ship_subject -> per commit subject on stdin ("sha<TAB>subject"): sha, type
# ("" for none), breaking (1 for "type!:"), the task id of its last "[ID]", the pull
# request of a trailing "(#N)", and the subject without those, tab-separated.
_peal_ship_subject() {
  awk -F '\t' '{
    s = $2; type = ""; bang = 0; id = ""; pr = ""
    if (match(s, / \(#[0-9]+\)$/)) { pr = substr(s, RSTART + 3, RLENGTH - 4); s = substr(s, 1, RSTART - 1) }
    if (match(s, / ?\[[0-9A-Za-z-]+\]$/)) { id = substr(s, RSTART, RLENGTH); sub(/^ ?\[/, "", id); sub(/\]$/, "", id); s = substr(s, 1, RSTART - 1) }
    if (match(s, /^[a-z]+(\([^)]*\))?!?: /)) {
      head = substr(s, 1, RLENGTH - 2); s = substr(s, RLENGTH + 1)
      if (head ~ /!$/) { bang = 1; head = substr(head, 1, length(head) - 1) }
      area = head; sub(/\(.*$/, "", head); type = head
      if (area ~ /\((tasks|decisions)\)$/) type = type "(" (area ~ /tasks/ ? "tasks" : "decisions") ")"
    }
    print $1 "\t" type "\t" bang "\t" id "\t" pr "\t" s }'
}

# _peal_ship_sentence -> the first sentence of the first paragraph of the text on stdin
# (an Outcome), on one line: comments, headings and list markers dropped.
_peal_ship_sentence() {
  awk '
    { while (match($0, /<!--.*-->/)) $0 = substr($0, 1, RSTART - 1) substr($0, RSTART + RLENGTH)
      if (inc) { if (match($0, /-->/)) { $0 = substr($0, RSTART + RLENGTH); inc = 0 } else next }
      if (match($0, /<!--/)) { $0 = substr($0, 1, RSTART - 1); inc = 1 } }
    $0 == "---" || /^#/ || /^<\/?details>/ { if (p != "") exit; next }
    /^[ \t\r]*$/ { if (p != "") exit; next }
    { sub(/^[ \t]*([-*+]|[0-9]+\.)[ \t]+/, ""); sub(/^[ \t]+/, ""); sub(/[ \t\r]+$/, "")
      p = p (p == "" ? "" : " ") $0 }
    END {
      if (match(p, /[.!?] /)) p = substr(p, 1, RSTART)
      print p }'
}

# _peal_ship_items DIR -> DIR/items: one line per release item, oldest first,
# tab-separated: kind (breaking, feature, fix, or none for one left out), id ("" for a
# commit of no task), its pull requests ("#29 #31"), title, sentence, link (the task's
# page, or "").
_peal_ship_items() {
  local dir=$1
  git log --reverse --format='%H%x09%s' "$PEAL_RANGE" | _peal_ship_subject >"$dir/commits" || return 2
  : >"$dir/items"
  if [ "$PEAL_KIND" = issues ]; then
    _peal_ship_issue_items "$dir" || return 2
  else
    _peal_ship_file_items "$dir" || return 2
  fi
  # The commits typed feat or fix of no task found above, nor of one decided against.
  touch "$dir/dropped"
  awk -F '\t' 'FILENAME == ARGV[1] { if ($2 != "") task[$2] = 1; next }
    FILENAME == ARGV[2] { task[$0] = 1; next }
    ($2 == "feat" || $2 == "fix" || $3 == 1) && !($4 in task) {
      kind = ($3 == 1 ? "breaking" : ($2 == "fix" ? "fix" : "feature"))
      print kind "\t\t" ($5 == "" ? "" : "#" $5) "\t" $6 "\t\t" }' "$dir/items" "$dir/dropped" "$dir/commits" >"$dir/untracked"
  cat "$dir/untracked" >>"$dir/items"
}

# _peal_ship_file_items DIR -> DIR/items for the task files the range adds under done/.
_peal_ship_file_items() {
  local dir=$1 sha path id line type bang pr kind title sentence link text
  text=$dir/text
  git log --reverse --no-renames --diff-filter=A --format='%x01%H' --name-only "$PEAL_RANGE" -- "$PEAL_TASKS/done/" \
    | awk '/^\001/ { sha = substr($0, 2); next } NF && !seen[$0]++ { print sha "\t" $0 }' >"$dir/added" || return 2
  while IFS=$'\t' read -r sha path; do
    id=${path##*/}
    id=${id%%-*}
    [[ "$id" =~ ^[0-9]{4}$ ]] || continue
    # Done before the last release already (moved there and back): not this release's.
    [ -z "$PEAL_LAST" ] || ! git cat-file -e "$PEAL_LAST:$path" 2>/dev/null || continue
    line=$(awk -F '\t' -v s="$sha" '$1 == s' "$dir/commits")
    type=$(cut -f2 <<<"$line") bang=$(cut -f3 <<<"$line") pr=$(cut -f5 <<<"$line")
    [ "$type" != "docs(tasks)" ] || [[ "$(cut -f6 <<<"$line")" != retire\ * ]] || continue
    git show "$PEAL_END:$path" >"$text" 2>/dev/null || continue
    title=$(peal_text_title "$id" <"$text") || title=${path##*/}
    sentence=$(peal_text_section Outcome <"$text" | _peal_ship_sentence)
    kind=feature
    [ "$type" != fix ] || kind=fix
    [ "$bang" != 1 ] && [ "$(peal_fm_get "$text" breaking 2>/dev/null)" != true ] || kind=breaking
    [ "$(peal_fm_get "$text" release-note 2>/dev/null)" != none ] || kind=none
    link=""
    [ -z "$PEAL_GH_REPO" ] || link="https://github.com/$PEAL_GH_REPO/blob/$PEAL_SHIP_TAG/$path"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$id" "${pr:+#$pr}" "$title" "$sentence" "$link" >>"$dir/items"
  done <"$dir/added"
}

# _peal_ship_issue_items DIR -> DIR/items for the issues the range's subjects name that
# are closed as completed.
_peal_ship_issue_items() {
  local dir=$1 id row state reason title labels ispr prs kind first sentence
  [ -n "$PEAL_GH_REPO" ] || { peal_err "no GitHub repository: set storage.issues.repo"; return 2; }
  awk -F '\t' '$4 ~ /^[0-9]+$/ && !seen[$4]++ { print $4 }' "$dir/commits" >"$dir/ids"
  while IFS= read -r id; do
    row=$(peal_gh "repos/$PEAL_GH_REPO/issues/$id" \
      --jq '[.state, (.state_reason // ""), .title, ([.labels[].name] | join(",")), (if .pull_request then "pr" else "" end)] | join("\u001f")' </dev/null 2>/dev/null) \
      || continue
    # A separator that is no white space: an empty field stays a field.
    IFS=$'\x1f' read -r state reason title labels ispr <<<"$row"
    [ "$reason" != not_planned ] || echo "$id" >>"$dir/dropped"
    if [ "$state" != closed ] || [ "$reason" = not_planned ] || [ -n "$ispr" ]; then continue; fi
    prs=$(awk -F '\t' -v id="$id" '$4 == id && $5 != "" { printf "%s#%s", (n++ ? " " : ""), $5 }' "$dir/commits")
    kind=feature
    ! awk -F '\t' -v id="$id" '$4 == id && $2 == "fix" { f = 1 } END { exit !f }' "$dir/commits" || kind=fix
    [[ ",$labels," != *,bug,* ]] || kind=fix
    ! awk -F '\t' -v id="$id" '$4 == id && $3 == 1 { f = 1 } END { exit !f }' "$dir/commits" || kind=breaking
    [[ ",$labels," != *,breaking,* && ",$labels," != *",breaking: true,"* ]] || kind=breaking
    [[ ",$labels," != *",release-note: none,"* ]] || kind=none
    sentence=""
    first=${prs%% *}
    if [ -n "$first" ]; then
      sentence=$(peal_gh "repos/$PEAL_GH_REPO/pulls/${first#\#}" --jq '.body // ""' </dev/null 2>/dev/null \
        | tr -d '\r' | peal_text_section Outcome | _peal_ship_sentence)
    fi
    printf '%s\t%s\t%s\t%s\t%s\t\n' "$kind" "$id" "$prs" "$title" "$sentence" >>"$dir/items"
  done <"$dir/ids"
}

# _peal_ship_bump ITEMS -> major, minor, patch or none: what the items not left out call
# for.
_peal_ship_bump() {
  awk -F '\t' '
    $1 == "breaking" { b = 1 } $1 == "feature" { f = 1 } $1 == "fix" { x = 1 }
    END { print (b ? "major" : f ? "minor" : x ? "patch" : "none") }' "$1"
}

# _peal_ship_next BUMP -> the version after PEAL_LAST that BUMP makes.
_peal_ship_next() {
  local v=${PEAL_LAST#"$PEAL_PREFIX"} major minor patch
  IFS=. read -r major minor patch <<<"$v"
  case $1 in
    major) major=$((major + 1)) minor=0 patch=0 ;;
    minor) minor=$((minor + 1)) patch=0 ;;
    *) patch=$((patch + 1)) ;;
  esac
  printf '%s%s.%s.%s\n' "$PEAL_PREFIX" "$major" "$minor" "$patch"
}

# _peal_ship_count ITEMS -> "1 breaking change, 2 features, 1 fix" for the items not
# left out; empty for none.
_peal_ship_count() {
  awk -F '\t' '{ n[$1]++ }
    function one(c, s, p) { if (!c) return; out = out (out == "" ? "" : ", ") c " " (c == 1 ? s : p) }
    END {
      one(n["breaking"], "breaking change", "breaking changes")
      one(n["feature"], "feature", "features")
      one(n["fix"], "fix", "fixes")
      print out }' "$1"
}

# _peal_ship_notes TAG ITEMS -> the release notes: a first line (the tag's message),
# then the sections Breaking, Features and Fixes, one line per item.
_peal_ship_notes() {
  local tag=$1 items=$2 count
  count=$(_peal_ship_count "$items")
  if [ -z "$PEAL_LAST" ]; then
    printf '%s: the first release%s.\n' "$tag" "${count:+, $count}"
  elif [ -n "$count" ]; then
    printf '%s: %s since %s.\n' "$tag" "$count" "$PEAL_LAST"
  else
    printf '%s: no finished task since %s.\n' "$tag" "$PEAL_LAST"
  fi
  awk -F '\t' -v sections="$PEAL_SHIP_SECTIONS" -v kind="$PEAL_KIND" '
    { rows[++n] = $0 }
    END {
      ns = split(sections, s, " ")
      for (i = 1; i <= ns; i++) {
        k = s[i]; sub(/:.*/, "", k); h = s[i]; sub(/^[^:]*:/, "", h)
        head = 0
        for (j = 1; j <= n; j++) {
          split(rows[j], f, "\t")
          if (f[1] != k) continue
          if (!head) { printf "\n## %s\n\n", h; head = 1 }
          refs = ""
          if (f[2] != "") refs = (kind == "issues" ? "#" f[2] : (f[6] != "" ? "[" f[2] "](" f[6] ")" : f[2]))
          if (f[3] != "") refs = refs (refs == "" ? "" : ", ") f[3]
          line = "- " f[4] (f[5] == "" ? "" : ": " f[5])
          if (refs != "") line = line " (" refs ")"
          print line
        }
      }
    }' "$items"
}

# _peal_ship_collect DIR [TAG] -> the range and DIR/items for a release named TAG (or
# the one to propose).
_peal_ship_collect() {
  _peal_ship_settings || return 2
  _peal_ship_range "${2-}"
  PEAL_SHIP_TAG=${2:-$PEAL_END}
  _peal_ship_items "$1"
}

# peal_ship_propose -> what the next release would hold: "LAST <tag>" (or "LAST none"),
# an "ITEM kind id prs title" line per task and commit, then "PROPOSE <tag> <bump>"
# (first, major, minor or patch), or "NOTHING since <tag>" when nothing calls for one.
peal_ship_propose() {
  local dir bump status=0
  [ $# -eq 0 ] || { peal_err "ship propose: no arguments"; return 2; }
  dir=$(mktemp -d) || return 2
  _peal_ship_collect "$dir" || status=$?
  if [ $status = 0 ]; then
    echo "LAST ${PEAL_LAST:-none}"
    awk -F '\t' '{ printf "ITEM %s %s %s %s\n", $1, ($2 == "" ? "-" : $2), ($3 == "" ? "-" : $3), $4 }' "$dir/items"
    bump=$(_peal_ship_bump "$dir/items")
    if [ -z "$PEAL_LAST" ]; then
      echo "PROPOSE ${PEAL_PREFIX}0.1.0 first"
    elif [ "$bump" = none ]; then
      echo "NOTHING since $PEAL_LAST"
    else
      echo "PROPOSE $(_peal_ship_next "$bump") $bump"
    fi
  fi
  rm -rf "$dir"
  return $status
}

# peal_ship_notes VERSION -> the release notes of VERSION: what went in since the release
# before it (its tag, once it exists, else the remote's main branch).
peal_ship_notes() {
  local dir tag status=0
  [ $# -eq 1 ] || { peal_err "ship notes: VERSION"; return 2; }
  PEAL_PREFIX=$(peal_config_get release.tag-prefix) || return 2
  tag=$(_peal_ship_version "$1") || return 2
  dir=$(mktemp -d) || return 2
  _peal_ship_collect "$dir" "$tag" && _peal_ship_notes "$tag" "$dir/items" || status=2
  rm -rf "$dir"
  return $status
}

# peal_ship_tag VERSION -> the annotated tag of VERSION on the remote's main branch, the
# notes' first line its message, pushed. Refused: a tag that exists (here or on the
# remote), and a version not above the last release.
peal_ship_tag() {
  local dir tag msg sha status=0
  [ $# -eq 1 ] || { peal_err "ship tag: VERSION"; return 2; }
  PEAL_PREFIX=$(peal_config_get release.tag-prefix) || return 2
  tag=$(_peal_ship_version "$1") || return 2
  _peal_ship_settings || return 2
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null \
      || [ -n "$(git ls-remote --tags "$PEAL_REMOTE" "refs/tags/$tag" 2>/dev/null)" ]; then
    peal_err "ship tag: $tag exists already; a release is never moved. Name another version (peal ship publish $tag makes its GitHub release)."
    return 2
  fi
  PEAL_LAST=$(_peal_ship_last "$PEAL_REMOTE/$PEAL_MAIN")
  if [ -n "$PEAL_LAST" ] && [ "$(_peal_ship_last "$PEAL_REMOTE/$PEAL_MAIN" "$tag")" != "$PEAL_LAST" ]; then
    peal_err "ship tag: $tag is not above the last release, $PEAL_LAST"
    return 2
  fi
  dir=$(mktemp -d) || return 2
  _peal_ship_range "$tag"
  PEAL_SHIP_TAG=$tag
  if _peal_ship_items "$dir"; then
    msg=$(_peal_ship_notes "$tag" "$dir/items" | head -n 1)
  else
    status=2
  fi
  rm -rf "$dir"
  [ $status = 0 ] || return 2
  sha=$(git rev-parse "$PEAL_REMOTE/$PEAL_MAIN") || return 2
  git tag -a -m "$msg" "$tag" "$sha" || { peal_err "ship tag: could not tag $tag"; return 2; }
  if ! git push -q "$PEAL_REMOTE" "refs/tags/$tag" 2>/dev/null; then
    git tag -d "$tag" >/dev/null
    peal_err "ship tag: could not push $tag to $PEAL_REMOTE; taken back"
    return 2
  fi
  echo "tagged $tag at $(git rev-parse --short "$sha") ($PEAL_REMOTE/$PEAL_MAIN), pushed: $msg"
}

# _peal_ship_gh ARGS... -> gh ARGS (within a minute, where timeout exists); status 2 and
# gh's message when it fails.
_peal_ship_gh() {
  local err status=0
  if ! command -v gh >/dev/null 2>&1; then
    peal_err "this needs gh (https://cli.github.com), logged in"
    return 2
  fi
  err=$(mktemp) || return 2
  if command -v timeout >/dev/null 2>&1; then
    timeout 60 gh "$@" 2>"$err" || status=2
  else
    gh "$@" 2>"$err" || status=2
  fi
  [ $status = 0 ] || peal_err "gh $1 $2 failed: $(tr '\n' ' ' <"$err" | sed 's/ $//')"
  rm -f "$err"
  return $status
}

# peal_ship_publish VERSION -> the GitHub release of VERSION's tag, its notes
# peal_ship_notes's, created or brought up to date; nothing on a remote not on GitHub.
peal_ship_publish() {
  local dir tag url status=0
  [ $# -eq 1 ] || { peal_err "ship publish: VERSION"; return 2; }
  PEAL_PREFIX=$(peal_config_get release.tag-prefix) || return 2
  tag=$(_peal_ship_version "$1") || return 2
  _peal_ship_settings || return 2
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null || {
    peal_err "ship publish: no tag $tag; peal ship tag $tag first"
    return 2
  }
  if [ -z "$PEAL_GH_REPO" ]; then
    echo "no GitHub release: $PEAL_REMOTE is not on GitHub; the tag $tag is the release"
    return 0
  fi
  dir=$(mktemp -d) || return 2
  _peal_ship_range "$tag"
  PEAL_SHIP_TAG=$tag
  if _peal_ship_items "$dir" && _peal_ship_notes "$tag" "$dir/items" >"$dir/notes"; then
    if gh release view "$tag" -R "$PEAL_GH_REPO" --json url --jq .url >/dev/null 2>&1; then
      if url=$(_peal_ship_gh release edit "$tag" -R "$PEAL_GH_REPO" --title "$tag" --notes-file "$dir/notes"); then
        echo "updated the release $tag: $url"
      else
        status=2
      fi
    elif url=$(_peal_ship_gh release create "$tag" -R "$PEAL_GH_REPO" --verify-tag --title "$tag" --notes-file "$dir/notes"); then
      echo "released $tag: $url"
    else
      status=2
    fi
  else
    status=2
  fi
  rm -rf "$dir"
  return $status
}

# _peal_ship_runs TAG SHA -> "id<TAB>status<TAB>conclusion<TAB>name<TAB>url" per workflow
# run of the push of TAG.
_peal_ship_runs() {
  peal_gh "repos/$PEAL_GH_REPO/actions/runs?head_sha=$2&event=push&per_page=100" \
    --jq ".workflow_runs[] | select(.head_branch == \"$1\") | [(.id | tostring), .status, (.conclusion // \"\"), .name, .html_url] | @tsv"
}

# _peal_ship_report RUNS -> per text of release.report, "REPORT <line>" for the first
# line holding it in the logs of the runs' jobs (the log's timestamp dropped), or
# "REPORT <text>: not found".
_peal_ship_report() {
  local runs=$1 logs item id job found
  logs=$(mktemp) || return 2
  while IFS=$'\t' read -r id _; do
    for job in $(peal_gh "repos/$PEAL_GH_REPO/actions/runs/$id/jobs" --jq '.jobs[].id'); do
      peal_gh "repos/$PEAL_GH_REPO/actions/jobs/$job/logs" >>"$logs" || true
    done
  done <<<"$runs"
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    found=$(grep -F -m 1 -- "$item" "$logs" | tr -d '\r' \
      | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z //; s/^[[:space:]]+//; s/[[:space:]]+$//')
    if [ -n "$found" ]; then echo "REPORT $found"; else echo "REPORT $item: not found in the logs"; fi
  done < <(peal_config_get release.report)
  rm -f "$logs"
}

# peal_ship_wait VERSION -> waits for the workflow runs the push of VERSION's tag
# started, then one verdict: READY (0) when every run succeeded, FAILED:<run> <url>
# (1), NONE:<why> (1) when no run started within PEAL_SHIP_NO_RUN seconds (300) of the
# tag, or WAIT:<why> (3) when the budget (PEAL_SHIP_WAIT_BUDGET, 540 s; checked every
# PEAL_SHIP_WAIT_INTERVAL, 20) is spent; run it again then. A "RUN" line per run and
# the release.report lines come before READY and FAILED.
peal_ship_wait() {
  local tag sha runs start now born verdict pending bad
  [ $# -eq 1 ] || { peal_err "ship wait: VERSION"; return 2; }
  PEAL_PREFIX=$(peal_config_get release.tag-prefix) || return 2
  tag=$(_peal_ship_version "$1") || return 2
  _peal_ship_settings || return 2
  [ -n "$PEAL_GH_REPO" ] || { peal_err "ship wait: $PEAL_REMOTE is not on GitHub; no workflow runs to wait for"; return 2; }
  sha=$(git rev-parse -q --verify "refs/tags/$tag^{commit}") || { peal_err "ship wait: no tag $tag"; return 2; }
  born=$(git for-each-ref --format='%(creatordate:unix)' "refs/tags/$tag")
  start=$(date +%s)
  while :; do
    runs=$(_peal_ship_runs "$tag" "$sha") || return 2
    now=$(date +%s)
    if [ -z "$runs" ]; then
      if [ $((now - born)) -ge "${PEAL_SHIP_NO_RUN:-300}" ]; then
        echo "NONE:no workflow run for $tag; does a workflow run on pushed tags?"
        return 1
      fi
      verdict="WAIT:no workflow run for $tag yet"
    else
      pending=$(awk -F '\t' '$2 != "completed" { print $4 }' <<<"$runs" | paste -s -d , -)
      if [ -z "$pending" ]; then
        awk -F '\t' '{ printf "RUN %s %s %s\n", $4, $3, $5 }' <<<"$runs"
        _peal_ship_report "$runs"
        bad=$(awk -F '\t' '$3 != "success" && $3 != "skipped" && $3 != "neutral" { print $4 " " $5; exit }' <<<"$runs")
        if [ -n "$bad" ]; then
          echo "FAILED:$bad"
          return 1
        fi
        echo READY
        return 0
      fi
      verdict="WAIT:running: $pending"
    fi
    if [ $((now - start + ${PEAL_SHIP_WAIT_INTERVAL:-20})) -gt "${PEAL_SHIP_WAIT_BUDGET:-540}" ]; then
      echo "$verdict"
      return 3
    fi
    sleep "${PEAL_SHIP_WAIT_INTERVAL:-20}"
  done
}

# peal_ship propose | notes VERSION | tag VERSION | publish VERSION | wait VERSION
peal_ship() {
  local sub=${1-}
  [ $# -eq 0 ] || shift
  case $sub in
    propose) peal_ship_propose "$@" ;;
    notes) peal_ship_notes "$@" ;;
    tag) peal_ship_tag "$@" ;;
    publish) peal_ship_publish "$@" ;;
    wait) peal_ship_wait "$@" ;;
    *) peal_err "ship: propose | notes VERSION | tag VERSION | publish VERSION | wait VERSION"; return 2 ;;
  esac
}
