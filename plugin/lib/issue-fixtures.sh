# shellcheck shell=bash
# shellcheck disable=SC2016 # jq's $variables, not the shell's
# Fixtures for the harnesses of the issues storage: a throwaway repository with a bare
# remote whose GitHub is lib/fake-gh, issues, milestones and pull requests put into it.
# Sourced after test-lib.sh and task-fixtures.sh; needs jq, which fake-gh runs.

# issues_repo -> work, a new repository as task-fixtures.sh's repo makes, set to the
# issues storage of acme/widgets, with the milestones m0 (closed), m1 (due soonest:
# current), m2 (due later: open) and m3 (parked). FAKE_GH is its fake GitHub, and the
# fake gh first on PATH; ISSUES_CONFIG, when set, is added to its .peal/config.yml. Not
# in a subshell: it sets the caller's work.
issues_repo() {
  local bin
  work=$(repo)
  FAKE_GH=$(dirname "$work")/gh
  export FAKE_GH
  mkdir -p "$FAKE_GH"
  bin=$(dirname "$work")/bin
  mkdir -p "$bin"
  ln -s "$PEAL_ROOT/lib/fake-gh" "$bin/gh"
  case ":$PATH:" in *":$bin:"*) ;; *) PATH="$bin:$PATH" ;; esac
  mkdir -p "$work/.peal"
  printf 'storage:\n  kind: issues\n  issues:\n    repo: acme/widgets\n%s' "${ISSUES_CONFIG-}" >"$work/.peal/config.yml"
  git -C "$work" rm -q -r docs/milestones
  git -C "$work" add -A
  git -C "$work" commit -q -m issues
  git -C "$work" push -q origin main 2>/dev/null
  printf '[]\n' >"$FAKE_GH/issues.json"
  printf '[]\n' >"$FAKE_GH/pulls.json"
  printf '[]\n' >"$FAKE_GH/comments.json"
  printf '[]\n' >"$FAKE_GH/milestones.json"
  : >"$FAKE_GH/log"
  milestone 1 m0 closed "" ""
  milestone 2 m1 open "2026-10-01T07:00:00Z" ""
  milestone 3 m2 open "2026-12-01T07:00:00Z" "Second"
  milestone 4 m3 open "" "Parked: until later"
}

# milestone NUMBER TITLE STATE DUE DESCRIPTION -> a milestone on the fake GitHub.
milestone() {
  gh_save milestones '. + [{number: ($n | tonumber), title: $t, state: $s,
      due_on: (if $d == "" then null else $d end), description: $desc,
      html_url: ("https://github.com/acme/widgets/milestone/" + $n)}]' \
    --arg n "$1" --arg t "$2" --arg s "$3" --arg d "$4" --arg desc "$5"
}

# issue NUMBER TITLE [--closed | --not-planned] [--label L]... [--milestone M]
# [--body TEXT] [--assoc ASSOCIATION] -> an issue on the fake GitHub, opened by its owner
# unless --assoc says otherwise.
issue() {
  local n=$1 title=$2 state=open reason="" labels="[]" ms="" body="" assoc=OWNER
  shift 2
  while [ $# -gt 0 ]; do
    case $1 in
      --closed) state=closed reason=completed ;;
      --not-planned) state=closed reason=not_planned ;;
      --label) labels=$(jq -c --arg l "$2" '. + [{name: $l}]' <<<"$labels"); shift ;;
      --milestone) ms=$2; shift ;;
      --body) body=$2; shift ;;
      --assoc) assoc=$2; shift ;;
    esac
    shift
  done
  gh_save issues '. + [{number: ($n | tonumber), title: $t, state: $s,
      state_reason: (if $r == "" then null else $r end), body: $b, labels: $l,
      author_association: $a, html_url: ("https://github.com/acme/widgets/issues/" + $n),
      milestone: (if $m == "" then null else ($ms[0][] | select(.title == $m) | {number, title}) end)}]' \
    --arg n "$n" --arg t "$title" --arg s "$state" --arg r "$reason" --arg b "$body" \
    --argjson l "$labels" --arg a "$assoc" --arg m "$ms" --slurpfile ms "$FAKE_GH/milestones.json"
}

# pr NUMBER BODY [--draft] [--fork ASSOCIATION] [--closed] -> a pull request on the fake
# GitHub, from a branch of the repository unless --fork names its author's association.
pr() {
  local n=$1 body=$2 draft=false head=acme/widgets assoc=OWNER state=open
  shift 2
  while [ $# -gt 0 ]; do
    case $1 in
      --draft) draft=true ;;
      --fork) head=someone/widgets assoc=$2; shift ;;
      --closed) state=closed ;;
    esac
    shift
  done
  gh_save pulls '. + [{number: ($n | tonumber), body: $b, draft: $d, state: $s,
      author_association: $a, html_url: ("https://github.com/acme/widgets/pull/" + $n),
      head: {ref: ("issue/" + $n), repo: {full_name: $h}}, base: {repo: {full_name: "acme/widgets"}}}]' \
    --arg n "$n" --arg b "$body" --argjson d "$draft" --arg s "$state" --arg a "$assoc" --arg h "$head"
}

# gh_save FILE FILTER [ARGS...] -> the fake GitHub's FILE.json rewritten by the jq FILTER.
gh_save() {
  local file=$FAKE_GH/$1.json filter=$2
  shift 2
  jq "$@" "$filter" "$file" >"$file.new" && mv "$file.new" "$file"
}

# gh_get FILTER [FILE] -> jq -r FILTER over the fake GitHub's FILE.json (issues).
gh_get() {
  jq -r "$1" "$FAKE_GH/${2:-issues}.json"
}

# labels N -> issue N's labels, one line, comma-joined.
labels() {
  gh_get ".[] | select(.number == $1) | [.labels[].name] | join(\",\")"
}
