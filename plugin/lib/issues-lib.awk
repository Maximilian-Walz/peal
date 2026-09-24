# What an issue says, as the issues storage reads it; functions included with -f by
# issues-scan.awk, issues-text.awk and issues-prs.awk. Issues arrive as jq's @tsv rows
# (lib/store-issues.sh):
#
#   number  state  title  milestone  labels  author_association  url  body
#
# labels joined by commas; every text field with @tsv's escapes (\t \n \r \\).
#
# The conventions, Belfry's where it has one:
#   depends   lines "Depends on #3, #7" (the keywords human and milestone too); the
#             items are read up to the first word that is none of those
#   part-of   a line "Part of #3"
#   needs     labels "needs: <capability>"
#   fields    labels "<field>: <value>": size, plan, model, breaking, release-note and
#             the project's own; a field with several such labels is a list
#   priority  labels "priority: urgent|high|low", the higher of two; none is normal
#   owner     the label "owner: human" for a human task; none is ai
#   claimed   the label "in progress"

# tsv_unescape(s) -> s with @tsv's escapes undone.
function tsv_unescape(s,    out, i, c, n) {
  if (!index(s, "\\")) return s
  out = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == "\\" && i < length(s)) {
      n = substr(s, ++i, 1)
      if (n == "n") c = "\n"
      else if (n == "t") c = "\t"
      else if (n == "r") c = "\r"
      else if (n == "\\") c = "\\"
      else c = c n
    }
    out = out c
  }
  return out
}

function trim(s) {
  sub(/^[ \t\r]+/, "", s)
  sub(/[ \t\r]+$/, "", s)
  return s
}

# label_kv(l) -> 1 and LKEY, LVALUE for a label "key: value" (key lower-cased); 0 for
# any other label.
function label_kv(l,    i) {
  i = index(l, ":")
  if (i < 2) return 0
  LKEY = tolower(trim(substr(l, 1, i - 1)))
  LVALUE = trim(substr(l, i + 1))
  return LKEY ~ /^[a-z0-9_-]+$/ && LVALUE != ""
}

# prio_rank(p) -> how a priority ranks: urgent 4, high 3, normal 2, low 1; 0 for a word
# that is none of them.
function prio_rank(p) { return p == "urgent" ? 4 : p == "high" ? 3 : p == "normal" ? 2 : p == "low" ? 1 : 0 }

# add_item(list, v) -> the comma list with v appended, once.
function add_item(list, v) {
  if (index("," list ",", "," v ",")) return list
  return list (list == "" ? "" : ",") v
}

# body_refs(body) -> DEPS (a comma list) and PARTOF from the body's reference lines, and
# BODY_REST: the body without them, CRs dropped. A "Depends on" line naming anything but
# issues and keywords keeps its leading items and stays in the body, as prose.
function body_refs(body,    n, lines, j, line, low, rest, nt, toks, k, t, whole) {
  DEPS = ""; PARTOF = ""; BODY_REST = ""
  n = split(body, lines, "\n")
  for (j = 1; j <= n; j++) {
    line = lines[j]
    sub(/\r$/, "", line)
    low = tolower(line)
    if (match(low, /^[ \t]*depends on:?[ \t]*/)) {
      rest = substr(low, RLENGTH + 1)
      nt = split(rest, toks, /[ \t,]+/)
      whole = 0
      for (k = 1; k <= nt; k++) {
        t = toks[k]
        if (t == "") continue
        if (t ~ /^#[0-9]+$/) t = substr(t, 2) + 0
        else if (t != "human" && t != "milestone") { whole = -1; break }
        DEPS = add_item(DEPS, t)
        if (!whole) whole = 1
      }
      if (whole == 1) continue
    } else if (match(low, /^[ \t]*part of:?[ \t]*#[0-9]+[ \t.]*$/)) {
      t = low
      sub(/^[^#]*#/, "", t)
      sub(/[^0-9].*$/, "", t)
      if (PARTOF == "") { PARTOF = t + 0; continue }
    }
    BODY_REST = BODY_REST line "\n"
  }
}

# issue_slug(title) -> the title as a kebab-case slug of its first five words.
function issue_slug(title,    t, n, w, j, s, k) {
  t = tolower(title)
  gsub(/[^a-z0-9]+/, "-", t)
  n = split(t, w, "-")
  s = ""
  k = 0
  for (j = 1; j <= n && k < 5; j++) if (w[j] != "") { s = s (k++ ? "-" : "") w[j] }
  return s == "" ? "issue" : s
}
