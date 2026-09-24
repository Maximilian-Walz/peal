# Functions the decisions module's awk scripts share (lib/decisions.sh runs each with
# this file first).

function tidy(s) { gsub(/\t/, " ", s); sub(/\r$/, "", s); return s }

function basename(p) { sub(/.*\//, "", p); return p }

function is4(s) { return s ~ /^[0-9][0-9][0-9][0-9]$/ }

# target(status) -> the NNNN of "superseded by [decision ]NNNN...", else "".
function target(s) {
  if (s !~ /^superseded by /) return ""
  s = substr(s, 15)
  sub(/^decision /, "", s)
  s = substr(s, 1, 4)
  return is4(s) ? s : ""
}
