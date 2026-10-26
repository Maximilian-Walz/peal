#!/usr/bin/env bash
# Refuses a guard that docs/security.md names but .belfry.yml does not have reviewed: every
# plugin/, tools/ or .peal/ path in backticks on a `- Guard:` bullet (indented or not, and its two-space
# continuation lines) must match a pattern of the security-pr paths (the &never list),
# policy.never_auto_merge or policy.review_before_merge.paths. Under Belfry the security
# review runs only for those paths, so a guard outside them merges unreviewed.
#
#   tools/guards.sh [SECURITY_MD BELFRY_YML]
#
# Defaults: the repository's own docs/security.md and .belfry.yml. Lists are read with awk
# (no YAML library): block lists of `- item` lines, `*never` as an alias of the &never list.
# Matching is bash `case` globbing, where `*` also crosses `/` (unlike Belfry's `*`);
# the difference only makes this check more lenient on a pattern like `dir/*`.
# Prints `guards: PATH (FILE:LINE) is in neither ...`. Exit 0 clean, 1 on a finding,
# 2 when a list or the guard set is empty.
set -uo pipefail
if [ $# -eq 2 ]; then
  sec=$1 yml=$2
elif [ $# -eq 0 ]; then
  cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
  sec=docs/security.md yml=.belfry.yml
else
  echo "usage: tools/guards.sh [SECURITY_MD BELFRY_YML]" >&2
  exit 2
fi

patterns=$(awk '
  function item(s) {
    sub(/^[ \t]*-[ \t]+/, "", s); sub(/[ \t]+#.*$/, "", s); sub(/[ \t]+$/, "", s)
    gsub(/^["\x27]|["\x27]$/, "", s)
    return s
  }
  mode && /^[ \t]*-[ \t]/ { print item($0); n++; next }
  mode && /^[ \t]*(#|$)/ { next }
  { mode = 0 }
  /^[ \t]*paths:[ \t]*&never[ \t]*$/ { mode = 1; next }
  /^  never_auto_merge:[ \t]*$/ { mode = 1; next }
  /^  review_before_merge:/ { rv = 1; next }
  /^  [a-z_]+:/ { rv = 0 }
  rv && /^    paths:[ \t]*$/ { mode = 1; next }
' "$yml" 2>/dev/null)
if [ -z "$patterns" ] || ! grep -q . "$yml" 2>/dev/null; then
  echo "guards: no reviewed paths read from $yml; the search is broken" >&2
  exit 2
fi
if ! awk '/^[ \t]*review_before_merge:/ { rv = 1 } rv && /^[ \t]*paths:[ \t]*$/ { ok = 1 } END { exit !ok }' "$yml"; then
  echo "guards: no review_before_merge.paths in $yml" >&2
  exit 2
fi

guards=$(awk '
  /^ *- Guard:/ { on = 1 }
  on && !/^ *- Guard:/ && !/^  / { on = 0 }
  on {
    line = $0
    while (match(line, /`[^`]+`/)) {
      tok = substr(line, RSTART + 1, RLENGTH - 2)
      line = substr(line, RSTART + RLENGTH)
      if (tok ~ /^(plugin|tools|\.peal)\/[^ ]*$/) printf "%d %s\n", NR, tok
    }
  }
' "$sec" 2>/dev/null)
if [ -z "$guards" ]; then
  echo "guards: no guard paths read from $sec; the search is broken" >&2
  exit 2
fi

status=0
while read -r lineno path; do
  covered=0
  while IFS= read -r pattern; do
    # shellcheck disable=SC2254  # the pattern is meant to glob
    case "$path" in $pattern) covered=1; break ;; esac
  done <<<"$patterns"
  if [ $covered -eq 0 ]; then
    echo "guards: $path ($sec:$lineno) is in neither never_auto_merge nor review_before_merge.paths"
    status=1
  fi
done < <(printf '%s\n' "$guards" | sort -u -k2,2)
exit $status
