# Merges a project's settings over Peal's defaults; both arrive as yaml-parse.awk records,
# the defaults as the first file. Prints the effective records, in the defaults' order.
#
#   awk -F '\t' -v name=.peal/config.yml -f config-merge.awk DEFAULTS PROJECT
#
# A project may only set what the defaults hold, with the same shape (a single value or a
# list). An empty map in the defaults ({}) is open: the project adds its own keys under
# it, each with a list of allowed values or nothing. Anything else is refused, with the
# line, and status 2.

function fail(n, msg) {
  printf "peal: %s:%d: %s\n", name, n, msg > "/dev/stderr"
  failed = 1
  exit 2
}

function parent(p) {
  sub(/\.[^.]*$/, "", p)
  return p
}

$0 == "" { next }

FNR == NR {
  p = $1
  if (!(p in kind)) {
    order[++count] = p
    kind[p] = $2
    for (a = p; index(a, "."); ) { a = parent(a); group[a] = 1 }
  }
  if ($2 == "i" || $2 == "s") value[p, ++items[p]] = $4
  next
}

{
  p = $1; k = $2; n = $3
  if (p in kind && !(p in extra)) {
    if (kind[p] == "m" && !(p in set)) {
      if (k != "m") fail(n, p " holds keys of your own, not a value")
      next
    }
    if (!(p in set)) {
      if (kind[p] == "s" && k != "s") fail(n, p " takes a single value, not a list")
      if (kind[p] != "s" && k != "i" && k != "e") fail(n, p " takes a list, like " p ": [a, b]")
      set[p] = 1
      kind[p] = k
      items[p] = 0
    }
  } else if (parent(p) in kind && kind[parent(p)] == "m") {
    if (!(p in kind)) {
      if (k == "s" && $4 != "") fail(n, p ": give the allowed values as a list, or nothing")
      if (k == "m") fail(n, p ": give the allowed values as a list, or nothing")
      extra[p] = 1
      kind[p] = k
      children[parent(p), ++nchildren[parent(p)]] = p
    }
  } else if (p in group) {
    if (k != "m") fail(n, p " is a group of settings, not a value")
    next
  } else {
    fail(n, "unknown setting " p)
  }
  if (k == "i" || k == "s") value[p, ++items[p]] = $4
}

function put(p,    j) {
  if (kind[p] == "i" || kind[p] == "s") {
    for (j = 1; j <= items[p]; j++) printf "%s\t%s\t0\t%s\n", p, kind[p], value[p, j]
  } else {
    printf "%s\t%s\t0\t\n", p, kind[p]
  }
}

END {
  if (failed) exit 2
  for (o = 1; o <= count; o++) {
    p = order[o]
    if (kind[p] == "m" && nchildren[p]) {
      for (c = 1; c <= nchildren[p]; c++) put(children[p, c])
    } else {
      put(p)
    }
  }
}
