# The decisions a task or a diff bears on, for the planner's and reviewer's prompts: the
# entries whose text names one of the paths. Reads decisions-scan.awk's R records, then
# the text the paths come from (a task's sections, or a diff's file names), then the
# entry files; prints the path candidates, then per entry that names one
#   NNNN — Title (matched: KEY)
#     the first line of its **Decision.** paragraph
# and how many superseded entries matched too, left out.
#
# A candidate is a word of two or more "/"-separated parts, or a file name with an
# extension; backticks, quotes, brackets and trailing punctuation around it do not count.
# An entry matches on the candidate, its last part, and each of its directories three or
# more parts deep: entries name the directory that governs a file more often than the file.

function clean(t,    prev) {
  prev = ""
  while (t != prev) {
    prev = t
    sub(/^[[`'"(<*]+/, "", t)
    sub(/'s$/, "", t)
    sub(/[]`'"),.;:!?>*]+$/, "", t)
  }
  return t
}

function parts(t,    a, k, c) {
  k = split(t, a, "/"); c = 0
  for (j = 1; j <= k; j++) if (a[j] != "") c++
  return c
}

function add(t,    base, rest, d) {
  t = clean(t)
  if (length(t) < 3 || (t in seen)) return
  if (index(t, "/")) {
    if (t ~ /:\/\// || parts(t) < 2) return
  } else if (t !~ /^[A-Za-z0-9_.-]*[A-Za-z0-9_-][A-Za-z0-9_-]\.[A-Za-z][A-Za-z0-9]*$/ || length(t) - index(t, ".") > 6) return
  seen[t] = 1
  nc++; cand[nc] = t
  nk[nc] = 0
  key(nc, t)
  base = t; sub(/\/+$/, "", base); sub(/.*\//, "", base)
  if (length(base) >= 2 && base != t) key(nc, base)
  rest = t; sub(/\/+$/, "", rest)
  while (index(rest, "/")) {
    sub(/\/[^\/]*$/, "", rest)
    if (parts(rest) < 3) break
    key(nc, rest)
    key(nc, rest "/")
  }
}

function key(c, k) { nk[c]++; keys[c, nk[c]] = k }

FILENAME == ARGV[1] {
  if ($1 == "R") { ne++; ename[ne] = $2; enum[ne] = $3; etitle[ne] = $4; estatus[ne] = $5; edec[ne] = $8 }
  next
}
FILENAME == ARGV[2] {
  w = split($0, words, /[ \t]+/)
  for (i = 1; i <= w; i++) if (words[i] != "") add(words[i])
  next
}
{
  f = FILENAME; sub(/.*\//, "", f)
  text[f] = text[f] $0 "\n"
}

END {
  if (nc == 0) { print "no path in it to look for"; exit }
  line = ""
  for (c = 1; c <= nc; c++) line = line " " cand[c]
  print "paths:" line
  for (e = 1; e <= ne; e++) {
    hit = ""
    for (c = 1; c <= nc && hit == ""; c++)
      for (k = 1; k <= nk[c]; k++)
        if (index(text[ename[e]], keys[c, k])) { hit = keys[c, k]; break }
    if (hit == "") continue
    if (target(estatus[e]) != "") { superseded++; continue }
    printf "%s — %s (matched: %s)\n", enum[e], etitle[e], hit
    d = edec[e]
    if (length(d) > 200) {
      d = substr(d, 1, 200)
      sub(/ [^ ]*$/, "", d)
      d = d " …"
    }
    if (d != "") print "  " d
    shown++
  }
  if (!shown) print "no entry names one of them"
  if (superseded) printf "(%d superseded %s matched too, left out)\n", superseded, superseded == 1 ? "entry" : "entries"
}
