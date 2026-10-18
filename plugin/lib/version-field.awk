# version-field.awk: a version file with one top-level field's string value set, and
# nothing else changed; what `peal ship bump` writes and the pre-push gate re-derives.
#
#   awk -v format=json|toml|yaml -v field=F -v value=V -v eol=1|0 -v name=PATH \
#     -f version-field.awk FILE
#
# eol says whether FILE ends with a newline (awk cannot tell). Top level is, for JSON,
# the key at depth 1 of the top object; for TOML, "F = ..." before the first [table];
# for YAML, "F: ..." at column 0. The value must be a string: JSON's "...", TOML's
# basic or literal string on one line, YAML's plain, double- or single-quoted scalar on
# one line; its quoting is kept.
#
#   PEAL_MARK=TEXT awk -v format=line -v value=V -v eol=1|0 -v name=PATH \
#     -f version-field.awk FILE
#
# is the marked-line form, for any plain file: exactly one line contains TEXT (a literal,
# read from the environment so that no escape is interpreted), and that line holds
# exactly one version MAJOR.MINOR.PATCH(-pre)? with no digit or dot right before or
# after it; only that version is replaced, a "v" before it kept. Refused (status 2, a message, nothing on stdout): no
# such field, a field there twice, a value that is not such a string. V is written as
# it is: the caller passes a version, which needs no escaping.
#
#   PEAL_MARK=TEXT awk -v format=sha -v value=SHA -v eol=1|0 -v name=PATH \
#     -f version-field.awk FILE
#
# is the same for a commit's object name (`peal ship pin`): the one marked line holds
# exactly one run of letters and digits as long as SHA, all hexadecimal (so a longer or
# shorter run next to it is no match), and only that run is replaced by SHA.

function refuse(msg) {
  printf "peal: %s: %s\n", name, msg > "/dev/stderr"
  failed = 1
  exit 2
}

# found(i, s, e) -> the value's text is line i's characters s..e (e = s - 1: empty).
function found(i, s, e) {
  if (hits++) refuse("the field " field " is there more than once")
  at = i; from = s; to = e
}

{ line[++n] = $0 }

# json -> the string value of field in the top object, by one scan over every
# character: strings (their escapes), and the nesting of objects and arrays.
function json(    i, j, c, len, l, depth, stack, instr, esc, want, key, sstart, target) {
  depth = 0; want = ""; target = 0
  for (i = 1; i <= n; i++) {
    l = line[i]; len = length(l)
    for (j = 1; j <= len; j++) {
      c = substr(l, j, 1)
      if (instr) {
        if (esc) { esc = 0; continue }
        if (c == "\\") { esc = 1; continue }
        if (c != "\"") continue
        instr = 0
        if (depth == 1 && stack[1] == "{") {
          if (want == "key") { key = substr(l, sstart + 1, j - sstart - 1); want = "colon" }
          else if (target) { found(i, sstart + 1, j - 1); target = 0; want = "" }
        }
        continue
      }
      if (c ~ /[ \t\r]/) continue
      if (depth == 0 && c != "{") refuse("not a JSON object")
      if (depth == 1 && stack[1] == "{" && target && c != "\"")
        refuse("the field " field " is not a string")
      if (c == "\"") { instr = 1; sstart = j; continue }
      if (c == "{" || c == "[") {
        stack[++depth] = c
        if (depth == 1) want = "key"
        continue
      }
      if (c == "}" || c == "]") { depth--; continue }
      if (depth == 1 && stack[1] == "{") {
        if (c == ":") { if (want == "colon") { want = "value"; target = (key == field) } }
        else if (c == ",") want = "key"
      }
    }
  }
}

# quoted(l, p) -> the end of the quoted string starting at p in l (its closing quote),
# 0 for none; YAML's single quotes escape as '', TOML's literal strings never.
function quoted(l, p, yaml,    q, j, len, c) {
  q = substr(l, p, 1); len = length(l)
  for (j = p + 1; j <= len; j++) {
    c = substr(l, j, 1)
    if (q == "\"" && c == "\\") { j++; continue }
    if (c == q) {
      if (q == "'" && yaml && substr(l, j + 1, 1) == "'") { j++; continue }
      return j
    }
  }
  return 0
}

# rest_ok(l, j) -> whether what follows position j of l is only blanks and a comment.
function rest_ok(l, j,    r) {
  r = substr(l, j + 1)
  return r ~ /^[ \t\r]*(#.*)?$/
}

function toml(    i, l, p, e, ml, k, pre, t) {
  ml = ""
  for (i = 1; i <= n; i++) {
    l = line[i]
    if (ml != "") {
      if (index(l, ml)) ml = ""
      continue
    }
    if (l ~ /^[ \t]*\[/) break
    k = l
    if (!match(k, "^[ \t]*(" field "|\"" field "\"|'" field "')[ \t]*=[ \t]*")) {
      # A multi-line string opened here, that the lines after do not read as keys.
      t = l; sub(/^[^=]*=[ \t]*/, "", t)
      if (substr(t, 1, 3) == "\"\"\"" || substr(t, 1, 3) == "'''") {
        if (!index(substr(t, 4), substr(t, 1, 3))) ml = substr(t, 1, 3)
      }
      continue
    }
    p = RLENGTH + 1
    pre = substr(l, p, 3)
    if (pre == "\"\"\"" || pre == "'''") refuse("the field " field " is a multi-line string")
    t = substr(l, p, 1)
    if (t != "\"" && t != "'") refuse("the field " field " is not a string")
    e = quoted(l, p, 0)
    if (!e || !rest_ok(l, e)) refuse("the field " field " is not a string on one line")
    found(i, p + 1, e - 1)
  }
}

function yaml(    i, l, p, e, t, v, c) {
  for (i = 1; i <= n; i++) {
    l = line[i]
    if (!match(l, "^" field "[ \t]*:([ \t]|\r?$)")) continue
    p = RLENGTH + 1
    t = substr(l, p)
    match(t, /^[ \t]*/); p += RLENGTH
    c = substr(l, p, 1)
    if (c == "\"" || c == "'") {
      e = quoted(l, p, 1)
      if (!e || !rest_ok(l, e)) refuse("the field " field " is not a string on one line")
      found(i, p + 1, e - 1)
      continue
    }
    v = substr(l, p)
    # A plain scalar ends at " #" (a comment) and before trailing blanks.
    if (match(v, /[ \t]#/)) v = substr(v, 1, RSTART - 1)
    sub(/[ \t\r]+$/, "", v)
    if (v == "" || index("[]{}>|&*!%@`#,'\"", substr(v, 1, 1)) || v ~ /^[-?:]([ \t]|$)/)
      refuse("the field " field " is not a plain string")
    if (v ~ /^(~|null|Null|NULL|true|True|TRUE|false|False|FALSE)$/ \
        || v ~ /^[-+]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/ \
        || v ~ /^0[xo][0-9a-fA-F]+$/ || v ~ /^[-+]?[.](inf|Inf|INF)$/ || v ~ /^[.](nan|NaN|NAN)$/)
      refuse("the field " field " is not a string")
    # The next line indented and not a comment: the scalar goes on.
    if (i < n && line[i + 1] ~ /^[ \t]+[^ \t\r#]/)
      refuse("the field " field " is not a string on one line")
    found(i, p, p + length(v) - 1)
  }
}

# markline() -> at, the one line holding the marker.
function markline(    mark, i) {
  mark = ENVIRON["PEAL_MARK"]
  if (mark == "") refuse("the marker is empty")
  for (i = 1; i <= n; i++) {
    if (!index(line[i], mark)) continue
    if (hits++) refuse("the marker \"" mark "\" is on more than one line")
    at = i
  }
  if (!hits) refuse("no line holds the marker \"" mark "\"")
}

# line -> the one version on the one line holding the marker.
function marked(    mark, l, rest, off, s, e, cands, ok) {
  markline()
  mark = ENVIRON["PEAL_MARK"]
  l = line[at]; rest = l; off = 0
  while (match(rest, /[0-9]+[.][0-9]+[.][0-9]+(-[0-9A-Za-z.-]+)?/)) {
    s = off + RSTART; e = off + RSTART + RLENGTH - 1
    cands++
    if (!(s > 1 && substr(l, s - 1, 1) ~ /[0-9.]/) && !(substr(l, e + 1, 1) ~ /[0-9.]/)) { ok++; from = s; to = e }
    off = e; rest = substr(l, e + 1)
  }
  if (cands != 1 || ok != 1) refuse(cands ? "the line holding the marker \"" mark "\" does not hold exactly one version" : "the line holding the marker \"" mark "\" holds no version")
}

# sha -> the one object name on the one line holding the marker: a maximal run of
# letters and digits, as long as value and hexadecimal.
function sha(    mark, l, rest, off, s, e, cands, len) {
  markline()
  mark = ENVIRON["PEAL_MARK"]
  len = length(value)
  if (value !~ /^[0-9a-f]+$/ || len < 40) refuse("'" value "' is no object name")
  l = line[at]; rest = l; off = 0
  while (match(rest, /[0-9A-Za-z]+/)) {
    s = off + RSTART; e = off + RSTART + RLENGTH - 1
    if (RLENGTH == len && substr(l, s, len) ~ /^[0-9A-Fa-f]+$/) { cands++; from = s; to = e }
    off = e; rest = substr(l, e + 1)
  }
  if (cands != 1) refuse(cands ? "the line holding the marker \"" mark "\" holds more than one object name" : "the line holding the marker \"" mark "\" holds no object name of " len " hexadecimal digits")
}

END {
  if (failed) exit 2
  if (format == "line" || format == "sha") {
    if (format == "line") marked(); else sha()
    for (i = 1; i <= n; i++) {
      l = line[i]
      if (i == at) l = substr(l, 1, from - 1) value substr(l, to + 1)
      printf "%s%s", l, (i < n || eol ? "\n" : "")
    }
    exit
  }
  if (field !~ /^[A-Za-z0-9_-]+$/) refuse("'" field "' is no top-level field name")
  if (format == "json") json()
  else if (format == "toml") toml()
  else if (format == "yaml") yaml()
  else refuse("not a JSON, TOML or YAML file")
  if (!hits) refuse("no top-level field " field)
  for (i = 1; i <= n; i++) {
    l = line[i]
    if (i == at) l = substr(l, 1, from - 1) value substr(l, to + 1)
    printf "%s%s", l, (i < n || eol ? "\n" : "")
  }
}
