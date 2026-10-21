# The proposals `peal apply` reads (lib/apply.sh): a JSON document {"proposals": [{...},
# ...]} on stdin, flattened. Run under LC_ALL=C, so a string is bytes:
#
#   LC_ALL=C awk -v dir=DIR -f apply.awk
#
# Each field of proposal I (from 1) whose key is a plain name (a-z and _) and whose value
# is a string, number, true, false or null gets a line "I<TAB>KEY<TAB>TYPE" on stdout,
# TYPE one of s, n, true, false, null; a string's or number's value is written, decoded,
# to the file DIR/I.KEY, never put on a line, so no value is ever a shell word.
# \uXXXX escapes become UTF-8, surrogate pairs included. An array of strings is taken on
# the keys named in -v arrays="KEY KEY" (apply.sh passes them) only: the line is
# "I<TAB>KEY<TAB>a" and item n (from 1) is written, decoded, to DIR/I.KEY.n, so each item
# is a file of its own, never a word or a separator. What makes one proposal invalid
# is a line "I<TAB>error<TAB>MESSAGE": a key that is no plain name, a key given twice, an
# object or an array as a value (an array on a key not in arrays), an item that is no
# string, a \u0000 or a lone surrogate, a proposal that is no object.
# The last line is "count<TAB>N". A document that is not JSON, or has no "proposals"
# array, is one line "doc<TAB>error<TAB>MESSAGE" and nothing else. Other top-level keys
# are stepped over.

{ doc = doc $0 "\n" }

function fail(msg) {
  if (!failed) printf "doc\terror\t%s\n", msg
  failed = 1
  pos = len + 1
}

function hexval(h,    i, v, c) {
  if (length(h) != 4) return -1
  v = 0
  for (i = 1; i <= 4; i++) {
    c = index("0123456789abcdef", tolower(substr(h, i, 1)))
    if (!c) return -1
    v = v * 16 + c - 1
  }
  return v
}

# utf8(cp) -> code point cp as UTF-8 bytes.
function utf8(cp) {
  if (cp < 128) return sprintf("%c", cp)
  if (cp < 2048) return sprintf("%c%c", 192 + int(cp / 64), 128 + cp % 64)
  if (cp < 65536) return sprintf("%c%c%c", 224 + int(cp / 4096), 128 + int(cp / 64) % 64, 128 + cp % 64)
  return sprintf("%c%c%c%c", 240 + int(cp / 262144), 128 + int(cp / 4096) % 64, 128 + int(cp / 64) % 64, 128 + cp % 64)
}

function skipws(    c) {
  while (pos <= len) {
    c = substr(doc, pos, 1)
    if (c != " " && c != "\t" && c != "\n" && c != "\r") return
    pos++
  }
}

# str() -> the string at pos (on its opening quote), decoded; pos after it. A problem
# with its content (not its syntax) is left in serr. Linear in the string's length, its
# escapes included: the document is read in windows of 4096 bytes, each split once at
# its backslashes; the plain run up to the next backslash is appended in one piece (cut
# at a quote or a line break in it), an escape is read from the window, and a window's
# decoded text joins the result once. An escape that may run past the window's end
# starts the next window. One byte at a time, appended to the whole result, a long string
# took time quadratic in its length (busybox's substr is also linear in the document's).
function str(    out, seg, w, wl, nb, parts, bp, k, j, b, run, q, nl, e, v, lo, adv) {
  out = ""
  pos++
  while (pos <= len) {
    w = substr(doc, pos, 4096)
    wl = length(w)
    nb = split(w, parts, "\\") - 1
    b = 0
    for (k = 1; k <= nb; k++) { b += length(parts[k]) + 1; bp[k] = b }
    seg = ""
    j = 1
    k = 1
    for (;;) {
      while (k <= nb && bp[k] < j) k++
      b = k <= nb ? bp[k] : wl + 1
      run = substr(w, j, b - j)
      q = index(run, "\"")
      nl = index(run, "\n")
      if (nl && (!q || nl < q)) { fail("a line break inside a string; JSON writes it \\n"); return "" }
      if (q) { pos += j + q - 1; return out seg substr(run, 1, q - 1) }
      seg = seg run
      if (b > wl) { pos += wl; break }
      # An escape is at most 12 bytes (a surrogate pair): one that may not fit is read
      # from the next window, unless this one ends the document.
      if (b + 11 > wl && pos + wl <= len) { pos += b - 1; break }
      e = substr(w, b + 1, 1)
      adv = 2
      if (e == "n") seg = seg "\n"
      else if (e == "t") seg = seg "\t"
      else if (e == "r") seg = seg "\r"
      else if (e == "b") seg = seg "\b"
      else if (e == "f") seg = seg "\f"
      else if (e == "/" || e == "\\" || e == "\"") seg = seg e
      else if (e == "u") {
        v = hexval(substr(w, b + 2, 4))
        if (v < 0) { fail("a \\u escape without four hex digits"); return "" }
        adv = 6
        if (v >= 55296 && v < 56320) {
          lo = -1
          if (substr(w, b + 6, 2) == "\\u") lo = hexval(substr(w, b + 8, 4))
          if (lo >= 56320 && lo < 57344) {
            adv = 12
            v = 65536 + (v - 55296) * 1024 + (lo - 56320)
          } else { serr = "a lone surrogate (\\u" substr(w, b + 2, 4) ")"; v = -1 }
        } else if (v >= 56320 && v < 57344) { serr = "a lone surrogate (\\u" substr(w, b + 2, 4) ")"; v = -1 }
        else if (v == 0) { serr = "a \\u0000 in a string"; v = -1 }
        if (v >= 0) seg = seg utf8(v)
      } else { fail("an unknown escape \\" e); return "" }
      j = b + adv
    }
    out = out seg
  }
  fail("a string that does not end")
  return ""
}

# skip() -> steps over one value at pos, whatever it is; its kind returned.
function skip(    c, k) {
  skipws()
  c = substr(doc, pos, 1)
  if (c == "{") {
    pos++
    skipws()
    if (substr(doc, pos, 1) == "}") { pos++; return "obj" }
    for (;;) {
      skipws()
      if (substr(doc, pos, 1) != "\"") { fail("an object key that is not a string"); return "" }
      str()
      skipws()
      if (substr(doc, pos, 1) != ":") { fail("no ':' after an object key"); return "" }
      pos++
      skip()
      if (failed) return ""
      skipws()
      c = substr(doc, pos, 1)
      pos++
      if (c == "}") return "obj"
      if (c != ",") { fail("no ',' or '}' in an object"); return "" }
    }
  }
  if (c == "[") {
    pos++
    skipws()
    if (substr(doc, pos, 1) == "]") { pos++; return "arr" }
    for (;;) {
      skip()
      if (failed) return ""
      skipws()
      c = substr(doc, pos, 1)
      pos++
      if (c == "]") return "arr"
      if (c != ",") { fail("no ',' or ']' in an array"); return "" }
    }
  }
  if (c == "\"") { scalar = str(); return "s" }
  return literal()
}

# literal() -> a number, true, false or null at pos: its type, its text in scalar.
function literal(    start, t) {
  start = pos
  while (pos <= len && index(",}] \t\n\r", substr(doc, pos, 1)) == 0) pos++
  t = substr(doc, start, pos - start)
  scalar = t
  if (t == "true" || t == "false" || t == "null") return t
  if (t ~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) return "n"
  fail(t == "" ? "a value is missing" : "not a JSON value: " substr(t, 1, 20))
  return ""
}

# items(i, k) -> the array at pos (on its "["), its strings written to DIR/i.k.n; the
# problem with an item, if any, is left in aerr. Returns "a".
function items(i, k,    n, c) {
  n = 0
  pos++
  skipws()
  if (substr(doc, pos, 1) == "]") { pos++; return "a" }
  for (;;) {
    skipws()
    if (substr(doc, pos, 1) == "\"") {
      serr = ""
      scalar = str()
      if (failed) return ""
      if (serr != "") { if (aerr == "") aerr = "holds " serr }
      else {
        n++
        printf "%s", scalar > (dir "/" i "." k "." n)
        close(dir "/" i "." k "." n)
      }
    } else {
      skip()
      if (failed) return ""
      if (aerr == "") aerr = "holds an item that is not a string"
    }
    skipws()
    c = substr(doc, pos, 1)
    pos++
    if (c == "]") return "a"
    if (c != ",") { fail("no ',' or ']' in an array"); return "" }
  }
}

# proposal(i) -> proposal i at pos, flattened.
function proposal(i,    c, k, t, seen, bad) {
  skipws()
  if (substr(doc, pos, 1) != "{") {
    skip()
    if (!failed) printf "%d\terror\tthe proposal is not an object\n", i
    return
  }
  pos++
  skipws()
  if (substr(doc, pos, 1) == "}") { pos++; return }
  for (;;) {
    skipws()
    if (substr(doc, pos, 1) != "\"") { fail("an object key that is not a string"); return }
    serr = ""
    k = str()
    skipws()
    if (substr(doc, pos, 1) != ":") { fail("no ':' after an object key"); return }
    pos++
    serr = ""
    aerr = ""
    skipws()
    if (substr(doc, pos, 1) == "[" && !bad && !(k in seen) && k ~ /^[a-z_]+$/ && index(" " arrays " ", " " k " ")) t = items(i, k)
    else t = skip()
    if (failed) return
    if (bad) {
    } else if (k !~ /^[a-z_]+$/) {
      gsub(/[^ -~]/, "?", k)
      printf "%d\terror\tunknown field \"%s\"\n", i, substr(k, 1, 40)
      bad = 1
    } else if (k in seen) {
      printf "%d\terror\tfield %s given twice\n", i, k
      bad = 1
    } else if (t == "a") {
      if (aerr != "") {
        printf "%d\terror\tfield %s %s\n", i, k, aerr
        bad = 1
      } else {
        seen[k] = 1
        printf "%d\t%s\ta\n", i, k
      }
    } else if (t == "obj" || t == "arr") {
      printf "%d\terror\tfield %s is an %s, not a string\n", i, k, (t == "obj" ? "object" : "array")
      bad = 1
    } else if (serr != "") {
      printf "%d\terror\tfield %s holds %s\n", i, k, serr
      bad = 1
    } else {
      seen[k] = 1
      if (t == "s" || t == "n") {
        printf "%s", scalar > (dir "/" i "." k)
        close(dir "/" i "." k)
      }
      printf "%d\t%s\t%s\n", i, k, t
    }
    skipws()
    c = substr(doc, pos, 1)
    pos++
    if (c == "}") return
    if (c != ",") { fail("no ',' or '}' in proposal " i); return }
  }
}

END {
  len = length(doc)
  pos = 1
  n = 0
  skipws()
  if (substr(doc, pos, 1) != "{") fail("the document is not a JSON object")
  else {
    pos++
    skipws()
    if (substr(doc, pos, 1) == "}") pos++
    else for (;;) {
      skipws()
      if (substr(doc, pos, 1) != "\"") { fail("an object key that is not a string"); break }
      k = str()
      skipws()
      if (substr(doc, pos, 1) != ":") { fail("no ':' after an object key"); break }
      pos++
      skipws()
      if (k == "proposals" && !got) {
        got = 1
        if (substr(doc, pos, 1) != "[") { fail("proposals is not an array"); break }
        pos++
        skipws()
        if (substr(doc, pos, 1) == "]") pos++
        else for (;;) {
          proposal(++n)
          if (failed) break
          skipws()
          c = substr(doc, pos, 1)
          pos++
          if (c == "]") break
          if (c != ",") { fail("no ',' or ']' in proposals"); break }
        }
      } else skip()
      if (failed) break
      skipws()
      c = substr(doc, pos, 1)
      pos++
      if (c == "}") break
      if (c != ",") { fail("no ',' or '}' in the document"); break }
    }
  }
  if (!failed) {
    skipws()
    if (pos <= len) fail("text after the document")
    else if (!got) fail("no \"proposals\" array")
  }
  if (!failed) printf "count\t%d\n", n
}
