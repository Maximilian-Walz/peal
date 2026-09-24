# One milestone file -> one line "id<TAB>title<TAB>state<TAB>order<TAB>due<TAB>name", or
# every problem with it on stderr and exit 2.
#
#   awk -F '\t' -v name=<file for messages> -v base=<file name without .md> \
#     -f milestone-read.awk RECORDS FILE
#
# RECORDS is yaml-parse.awk's output for FILE's frontmatter. id defaults to base, title
# to FILE's first "# " heading after the frontmatter. state is required and one of open,
# current, done, parked; order is an integer; due a date, YYYY-MM-DD. Other keys are
# refused, so a misspelt one fails instead of being ignored.

function problem(msg) {
  printf "peal: %s: %s\n", name, msg > "/dev/stderr"
  bad = 1
}

function leap(y) {
  return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

# date(s) -> whether s is a real calendar date written YYYY-MM-DD.
function date(s,    y, m, d, days) {
  if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m < 1 || m > 12 || d < 1) return 0
  days = substr("312831303130313130313031", 2 * m - 1, 2) + 0
  if (m == 2 && leap(y)) days = 29
  return d <= days
}

FILENAME == ARGV[1] {
  if ($1 == "") next
  if ($1 != "id" && $1 != "title" && $1 != "state" && $1 != "order" && $1 != "due") {
    problem("line " $3 ": unknown key " $1 " (milestones have id, title, state, order, due)")
    next
  }
  if ($2 != "s") { problem("line " $3 ": " $1 " must be a single value, not a list"); next }
  value[$1] = $4
  has[$1] = 1
  next
}

# The body: the first "# " heading after the frontmatter is the default title.
FNR == 1 && $0 == "---" { infm = 1; next }
infm { if ($0 == "---") infm = 0; next }
heading == "" && /^# / {
  heading = substr($0, 3)
  sub(/^ +/, "", heading); sub(/[ \r]+$/, "", heading)
}

END {
  id = has["id"] ? value["id"] : base
  if (id !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/)
    problem("id '" id "' must be letters, digits, '.', '_' and '-', starting with a letter or digit")
  title = (has["title"] && value["title"] != "") ? value["title"] : heading
  gsub(/\t/, " ", title)
  state = value["state"]
  if (!has["state"] || state == "")
    problem("no state: write one of open, current, done, parked")
  else if (state != "open" && state != "current" && state != "done" && state != "parked")
    problem("state '" state "' is not one of open, current, done, parked")
  order = value["order"]
  if (order != "" && order !~ /^-?[0-9]+$/) problem("order '" order "' is not an integer")
  # JSON numbers have no leading zeros.
  if (order ~ /^-?0+[0-9]/) { neg = order ~ /^-/; sub(/^-?0+/, "", order); if (neg) order = "-" order }
  if (order == "-0") order = "0"
  due = value["due"]
  if (due != "" && !date(due)) problem("due '" due "' is not a date, YYYY-MM-DD")
  if (bad) exit 2
  printf "%s\t%s\t%s\t%s\t%s\t%s\n", id, title, state, order, due, name
}
