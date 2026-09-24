# Peal's YAML subset -> one record per value: "path<TAB>kind<TAB>line<TAB>value".
#
#   awk -v mode=frontmatter|config -v name=<file for messages> -f yaml-parse.awk FILE
#
# kind: s (scalar; an empty one is a key with no value), i (one list item; a list is
# several i records with the same path, in order), e (an empty list, []), m (an empty
# map, {}). A nested key's path is its keys joined by dots.
#
# The subset: plain, 'single'- and "double"-quoted scalars; lists of scalars in flow
# ([a, b]) or block (- a) style; comments. In config mode also nested block maps and flow
# maps of scalars. Everything else (anchors, tags, block scalars, multi-line flow, lists
# of maps, ...) is refused with the file and line, exit 2, and no records.
#
# frontmatter mode reads only the block between a first line "---" and the next "---";
# a file that does not start with "---" has no frontmatter and yields nothing.

function fail(n, msg) {
  printf "peal: %s:%d: %s\n", name, n, msg > "/dev/stderr"
  failed = 1
  exit 2
}

function emit(path, kind, n, value) {
  out = out path "\t" kind "\t" n "\t" value "\n"
}

# quoted(t, n) -> the value of the quoted scalar t starts with; the text after its closing
# quote is left in qrest.
function quoted(t, n,    q, j, ch, nx, v) {
  q = substr(t, 1, 1)
  v = ""
  for (j = 2; j <= length(t); j++) {
    ch = substr(t, j, 1)
    if (q == "'") {
      if (ch == "'") {
        if (substr(t, j + 1, 1) == "'") { v = v "'"; j++; continue }
        qrest = substr(t, j + 1)
        return v
      }
      v = v ch
      continue
    }
    if (ch == "\\") {
      nx = substr(t, j + 1, 1)
      if (nx == "\"" || nx == "\\") { v = v nx; j++; continue }
      fail(n, "the escape \\" nx " is not supported; use a 'single-quoted' value")
    }
    if (ch == "\"") { qrest = substr(t, j + 1); return v }
    v = v ch
  }
  fail(n, "a quoted value is not closed on its line")
}

# plain(t, n) -> t checked as a plain scalar, its trailing comment and spaces dropped.
function plain(t, n,    c, j) {
  c = substr(t, 1, 1)
  if (c == "|" || c == ">") fail(n, "block scalars (| and >) are not supported")
  if (c == "&" || c == "*") fail(n, "anchors and aliases are not supported")
  if (c == "!") fail(n, "tags are not supported")
  if (c == "%" || c == "@" || c == "`") fail(n, "a value cannot start with " c "; quote it")
  if (c == "]" || c == "}") fail(n, "unexpected " c)
  if (t ~ /^[-?:]( |$)/) fail(n, "a value cannot start with \"" c " \"; quote it")
  j = index(t, " #")
  if (j) t = substr(t, 1, j - 1)
  sub(/ +$/, "", t)
  if (index(t, ": ") || t ~ /:$/) fail(n, "a plain value cannot contain \": \"; quote it")
  return t
}

# scalar(t, n) -> the value of the scalar t, which must fill the rest of its line.
function scalar(t, n,    c, v) {
  c = substr(t, 1, 1)
  if (c == "\"" || c == "'") {
    v = quoted(t, n)
    if (qrest !~ /^( +(#.*)?)?$/) fail(n, "unexpected text after a quoted value")
    return v
  }
  return plain(t, n)
}

# flow(path, t, n, closer) reads the flow list ([a, b], closer "]") or flow map ({k: v},
# closer "}") t, which must fill the rest of its line.
function flow(path, t, n, closer,    j, ch, start, item, k, count) {
  j = 2
  count = 0
  while (1) {
    while (substr(t, j, 1) == " ") j++
    ch = substr(t, j, 1)
    if (ch == "") fail(n, "a flow " (closer == "]" ? "list" : "map") " must close on its line")
    if (ch == closer) { j++; break }
    k = ""
    if (closer == "}") {
      start = j
      while (substr(t, j, 1) ~ /[A-Za-z0-9_-]/) j++
      k = substr(t, start, j - start)
      if (k == "" || substr(t, j, 2) != ": ") fail(n, "expected \"key: value\" in a flow map")
      j += 2
      while (substr(t, j, 1) == " ") j++
      ch = substr(t, j, 1)
      if (seen[path "." k]++) fail(n, "duplicate key " path "." k)
    }
    if (ch == "[" || ch == "{") fail(n, "nested flow lists and maps are not supported")
    if (ch == "\"" || ch == "'") {
      item = quoted(substr(t, j), n)
      j = length(t) - length(qrest) + 1
    } else {
      start = j
      while (j <= length(t) && substr(t, j, 1) != "," && substr(t, j, 1) != closer) j++
      item = substr(t, start, j - start)
      sub(/ +$/, "", item)
      if (item == "") fail(n, "empty item in a flow " (closer == "]" ? "list" : "map"))
      item = plain(item, n)
    }
    count++
    if (closer == "]") emit(path, "i", n, item)
    else emit(path "." k, "s", n, item)
    while (substr(t, j, 1) == " ") j++
    ch = substr(t, j, 1)
    if (ch == ",") { j++; continue }
    if (ch == closer) { j++; break }
    fail(n, "expected , or " closer)
  }
  if (substr(t, j) !~ /^( +(#.*)?)?$/) fail(n, "unexpected text after " closer)
  if (count == 0) emit(path, closer == "]" ? "e" : "m", n, "")
}

{ lines[NR] = $0 }

END {
  if (failed) exit 2
  first = 1
  last = NR
  if (mode == "frontmatter") {
    if (NR == 0 || lines[1] != "---") exit 0
    last = 0
    for (i = 2; i <= NR; i++) if (lines[i] == "---") { last = i - 1; break }
    if (!last) fail(1, "the frontmatter opened by --- is never closed")
    first = 2
  }
  depth = 0; ind[0] = 0; pre[0] = ""
  pending = ""    # a key with nothing after its colon: a list, a map or empty follows
  listpath = ""   # the block list being read
  for (i = first; i <= last; i++) {
    s = lines[i]
    if (s ~ /^[ \t]*(#.*)?\r?$/) continue
    if (s ~ /\r$/) fail(i, "carriage returns are not supported")
    if (index(s, "\t")) fail(i, "tabs are not supported")
    match(s, /^ */)
    indent = RLENGTH
    body = substr(s, indent + 1)

    if (body ~ /^-( |$)/) {
      if (pending != "" && indent >= pind) {
        listpath = pending; lind = indent; pending = ""
      }
      if (listpath == "" || indent != lind) fail(i, "this list item belongs to no key")
      item = substr(body, 2)
      sub(/^ +/, "", item)
      if (item == "" || item ~ /^#/) fail(i, "empty list items are not supported")
      if (item ~ /^-( |$)/ || item ~ /^\[/) fail(i, "lists inside lists are not supported")
      if (item ~ /^\{/ || item ~ /^[A-Za-z0-9_-]+:( |$)/) fail(i, "lists of maps are not supported")
      emit(listpath, "i", i, scalar(item, i))
      continue
    }
    listpath = ""

    if (!match(body, /^[A-Za-z0-9_-]+:/) || (length(body) > RLENGTH && substr(body, RLENGTH + 1, 1) != " "))
      fail(i, "expected \"key: value\"")
    key = substr(body, 1, RLENGTH - 1)
    rest = substr(body, RLENGTH + 1)
    sub(/^ +/, "", rest)

    if (pending != "") {
      if (indent > pind) {
        if (mode == "frontmatter") fail(i, "nested maps are not supported in frontmatter")
        depth++; ind[depth] = indent; pre[depth] = pending "."
      } else {
        emit(pending, "s", pline, "")
      }
      pending = ""
    }
    while (depth > 0 && indent < ind[depth]) depth--
    if (indent != ind[depth]) fail(i, "this key's indentation matches no enclosing key")
    path = pre[depth] key
    if (seen[path]++) fail(i, "duplicate key " path)

    if (rest == "" || rest ~ /^#/) { pending = path; pind = indent; pline = i; continue }
    c = substr(rest, 1, 1)
    if (c == "[") flow(path, rest, i, "]")
    else if (c == "{") {
      if (mode == "frontmatter") fail(i, "maps are not supported in frontmatter")
      flow(path, rest, i, "}")
    } else emit(path, "s", i, scalar(rest, i))
  }
  if (pending != "") emit(pending, "s", pline, "")
  printf "%s", out
}
