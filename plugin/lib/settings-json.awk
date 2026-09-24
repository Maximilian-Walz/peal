# Edits a JSON document (Claude Code's .claude/settings.json) in place of its text, so
# everything but the edit keeps its formatting. Paths are keys joined by ".", from the
# top-level object.
#
#   awk -v op=has -v path=enabledPlugins.peal@peal -f settings-json.awk FILE
#       status 0 if the member exists, 1 if not
#   awk -v op=kind -v path=P -f settings-json.awk FILE
#       object, array, string or other for the member (empty for none); for an object,
#       its member count after a space
#   awk -v op=insert -v path=P -v key=K -v json=JSON -f settings-json.awk FILE
#       the document with member K (JSON, its text on one line) added last to the
#       object at P ("" for the top level)
#   awk -v op=delete -v path=P -f settings-json.awk FILE
#       the document without member P
#
# A document that does not parse is status 2 with a message on stderr, for every op.

{ doc = doc $0 "\n" }

function fail(msg) {
  printf "peal: %s: %s\n", (name == "" ? FILENAME : name), msg > "/dev/stderr"
  failed = 1
  exit 2
}

function skipws(    c) {
  while (pos <= len) {
    c = substr(doc, pos, 1)
    if (c != " " && c != "\t" && c != "\n" && c != "\r") return
    pos++
  }
}

# str() -> the string at pos (on its opening quote), undecoded; pos after it.
function str(    start, c) {
  start = ++pos
  while (pos <= len) {
    c = substr(doc, pos, 1)
    if (c == "\"") { pos++; return substr(doc, start, pos - 1 - start) }
    if (c == "\\") pos++
    else if (c == "\n") fail("a string runs past its line")
    pos++
  }
  fail("a string is not closed")
}

# value(p) -> parses the value at pos, whose path is p; records objects' spans and
# members for the edits.
function value(p,    c, k, mp, n, start) {
  skipws()
  if (pos > len) fail("the document ends early")
  c = substr(doc, pos, 1)
  kindof[p] = c == "{" ? "object" : c == "[" ? "array" : c == "\"" ? "string" : "other"
  if (c == "{") {
    ostart[p] = pos
    pos++
    n = 0
    skipws()
    if (substr(doc, pos, 1) == "}") { oend[p] = pos; pos++; count[p] = 0; return }
    for (;;) {
      skipws()
      if (substr(doc, pos, 1) != "\"") fail("a key is not a string at offset " pos)
      start = pos
      k = str()
      mp = (p == "" ? k : p "." k)
      n++
      member[p, n] = mp
      kstart[mp] = start
      skipws()
      if (substr(doc, pos, 1) != ":") fail("no ':' after key \"" k "\"")
      pos++
      value(mp)
      vend[mp] = pos
      skipws()
      c = substr(doc, pos, 1)
      if (c == ",") { pos++; continue }
      if (c == "}") { oend[p] = pos; pos++; count[p] = n; return }
      fail("no ',' or '}' after key \"" k "\"")
    }
  }
  if (c == "[") {
    pos++
    n = 0
    skipws()
    if (substr(doc, pos, 1) == "]") { pos++; return }
    for (;;) {
      value(p "[]")
      skipws()
      c = substr(doc, pos, 1)
      if (c == ",") { pos++; continue }
      if (c == "]") { pos++; return }
      fail("no ',' or ']' in an array")
    }
  }
  if (c == "\"") { str(); return }
  start = pos
  while (pos <= len && index(",}] \t\n\r", substr(doc, pos, 1)) == 0) pos++
  if (substr(doc, start, pos - start) !~ /^(true|false|null|-?[0-9][0-9.eE+-]*)$/) fail("not a JSON value at offset " start)
}

# indent_at(i) -> the white space that starts the line holding offset i.
function indent_at(i,    s, m) {
  s = substr(doc, 1, i)
  sub(/.*\n/, "", s)
  match(s, /^[ \t]*/)
  return substr(s, 1, RLENGTH)
}

function emit(text) {
  printf "%s", text
}

END {
  if (failed) exit 2
  len = length(doc)
  pos = 1
  skipws()
  if (substr(doc, pos, 1) != "{") fail("the document is not a JSON object")
  value("")
  skipws()
  if (pos <= len) fail("text after the document at offset " pos)

  if (op == "has") exit !(path in kindof)
  if (op == "kind") {
    if (path in kindof) print kindof[path] (kindof[path] == "object" ? " " count[path] : "")
    exit 0
  }
  if (op == "insert") {
    if (kindof[path] != "object") fail("no object at " (path == "" ? "the top level" : path))
    mp = (path == "" ? key : path "." key)
    if (mp in kindof) fail(mp " is there already")
    n = count[path]
    if (n > 0) {
      last = member[path, n]
      ind = substr(doc, 1, kstart[last] - 1)
      # The last member's indentation when it starts a line, else one line of its own.
      if (ind ~ /\n[ \t]*$/) { sub(/.*\n/, "", ind); sep = ",\n" ind }
      else sep = ", "
      emit(substr(doc, 1, vend[last] - 1) sep "\"" key "\": " json substr(doc, vend[last]))
    } else {
      outer = indent_at(ostart[path])
      emit(substr(doc, 1, ostart[path]) "\n" outer "  \"" key "\": " json "\n" outer substr(doc, oend[path]))
    }
    exit 0
  }
  if (op == "delete") {
    if (!(path in kindof)) fail("no " path)
    p = path
    sub(/\.[^.]*$/, "", p)
    if (p == path) p = ""
    n = count[p]
    for (i = 1; i <= n; i++) if (member[p, i] == path) break
    if (n == 1) {
      # The only member: the object becomes {}.
      emit(substr(doc, 1, ostart[p]) substr(doc, oend[p]))
    } else if (i < n) {
      # Up to the next member's key: its comma and the space after it.
      emit(substr(doc, 1, kstart[path] - 1) substr(doc, kstart[member[p, i + 1]]))
    } else {
      # The last one: from the end of the one before, its comma included.
      emit(substr(doc, 1, vend[member[p, i - 1]] - 1) substr(doc, vend[path]))
    }
    exit 0
  }
  fail("unknown op " op)
}
