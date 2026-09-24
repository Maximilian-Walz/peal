# A string or number at a dotted key path of a JSON document, as a Claude Code hook's
# input carries it: `awk -v key=tool_input.command -f json-get.awk`. Prints the value
# decoded, nothing if there is none; arrays are stepped over. \uXXXX escapes beyond ASCII
# become "?", enough for the git guard, which only looks at ASCII words.

{ doc = doc $0 "\n" }

function hexval(h,    i, v, c) {
  v = 0
  for (i = 1; i <= length(h); i++) {
    c = index("0123456789abcdef", tolower(substr(h, i, 1)))
    if (!c) return -1
    v = v * 16 + c - 1
  }
  return v
}

# str() -> the string starting at pos (on its opening quote), decoded; pos after it.
function str(    out, c, e, v) {
  out = ""
  pos++
  while (pos <= len) {
    c = substr(doc, pos, 1)
    if (c == "\"") { pos++; return out }
    if (c == "\\") {
      e = substr(doc, pos + 1, 1)
      pos += 2
      if (e == "n") out = out "\n"
      else if (e == "t") out = out "\t"
      else if (e == "r") out = out "\r"
      else if (e == "b") out = out "\b"
      else if (e == "f") out = out "\f"
      else if (e == "u") {
        v = hexval(substr(doc, pos, 4))
        pos += 4
        out = out ((v > 0 && v < 128) ? sprintf("%c", v) : "?")
      } else out = out e
      continue
    }
    out = out c
    pos++
  }
  return out
}

function skipws(    c) {
  while (pos <= len) {
    c = substr(doc, pos, 1)
    if (c != " " && c != "\t" && c != "\n" && c != "\r") return
    pos++
  }
}

# value(path) -> walks one value at pos whose key path is path; prints it if wanted.
function value(path,    c, k, v, start) {
  skipws()
  c = substr(doc, pos, 1)
  if (c == "{") {
    pos++
    for (;;) {
      skipws()
      c = substr(doc, pos, 1)
      if (c == "}") { pos++; return }
      if (c == ",") { pos++; continue }
      if (c != "\"") { pos = len + 1; return }
      k = str()
      skipws()
      if (substr(doc, pos, 1) == ":") pos++
      value(path == "" ? k : path "." k)
      if (pos > len) return
    }
  }
  if (c == "[") {
    pos++
    for (;;) {
      skipws()
      c = substr(doc, pos, 1)
      if (c == "]") { pos++; return }
      if (c == ",") { pos++; continue }
      if (pos > len) return
      value(path "[]")
    }
  }
  if (c == "\"") {
    v = str()
    if (path == key && !found) { printf "%s", v; found = 1 }
    return
  }
  start = pos
  while (pos <= len && index(",}] \t\n\r", substr(doc, pos, 1)) == 0) pos++
  if (path == key && !found) { printf "%s", substr(doc, start, pos - start); found = 1 }
}

END {
  len = length(doc)
  pos = 1
  value("")
}
