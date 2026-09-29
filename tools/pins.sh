#!/usr/bin/env bash
# Refuses an unpinned reference in the workflow files, so a supply-chain pin cannot
# quietly come loose. With no arguments it checks plugin/templates/*.yml and
# .github/workflows/*.yml; else the files named. Line-based; comment lines are skipped.
#
#   tools/pins.sh [FILE...]
#
# Refused:
# - a `uses:` that is not OWNER/REPO[/PATH]@<40 lowercase hex> followed by `# vX.Y...`
#   (a tag, a short SHA, no tag comment, ./local, docker://);
# - any `git clone`;
# - a git fetch of an https:// URL without a 40-hex SHA or without `# vMAJOR.MINOR.PATCH`
#   after it (a fetch by branch).
# Prints `path:line: reason`. Exit 0 clean, 1 on a finding, 2 when it finds no files.
set -uo pipefail
files=("$@")
if [ ${#files[@]} -eq 0 ]; then
  cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
  shopt -s nullglob
  files=(plugin/templates/*.yml .github/workflows/*.yml)
fi
if [ ${#files[@]} -eq 0 ]; then
  echo "pins: no files to check; the search is broken" >&2
  exit 2
fi

found=$(awk '
  # No {n} intervals: older awks lack them.
  function hex40(s) { return length(s) == 40 && s ~ /^[0-9a-f]+$/ }
  function vtag(s, strict) {
    if (strict) return s ~ "^v[0-9]+[.][0-9]+[.][0-9]+$"
    return s ~ "^v[0-9]+([.][0-9]+)*$"
  }
  /^[ \t]*#/ { next }
  /(^|[ \t-])uses:[ \t]/ {
    line = $0
    sub(/.*uses:[ \t]+/, "", line)
    n = split(line, w, /[ \t]+/)
    at = index(w[1], "@")
    ok = at > 0 && substr(w[1], 1, at - 1) ~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+(\/[^ ]+)?$/ \
      && hex40(substr(w[1], at + 1)) && w[2] == "#" && vtag(w[3], 0)
    if (!ok)
      printf "%s:%d: uses: is not pinned by a 40-hex SHA with a # vX.Y.Z comment\n", FILENAME, FNR
  }
  /git clone/ {
    printf "%s:%d: git clone is not pinned; fetch a commit by SHA\n", FILENAME, FNR
  }
  /git .*fetch .*https:\/\// {
    n = split($0, w, /[ \t]+/)
    ok = 0
    for (i = 1; i < n; i++)
      if (w[i] ~ /^https:\/\// && hex40(w[i + 1]) && w[i + 2] == "#" && vtag(w[i + 3], 1)) ok = 1
    if (!ok)
      printf "%s:%d: git fetch needs a 40-hex SHA and a # vMAJOR.MINOR.PATCH comment\n", FILENAME, FNR
  }
' "${files[@]}")
[ -z "$found" ] && exit 0
printf '%s\n' "$found"
exit 1
