# A shell command line -> its simple commands, each as its words the way the shell would
# pass them: quotes removed, escapes resolved, expansions left as written. Each word is
# followed by \037, each command by \036. For the git guard, which judges the git
# invocations a command runs, not the text around them:
#   - heredoc bodies and comments are dropped: data, not commands;
#   - redirections and their targets are dropped;
#   - ; & && | || newlines and ( ) separate commands;
#   - $(...), `...` and <(...) are commands of their own, and stay as written in the word
#     that holds them.
# `bash -c STRING` and `eval` are for the caller to feed back in. Not a shell: a case
# pattern's ")" inside $(...), for one, ends the substitution early.

{ text = text $0 "\n" }

END {
  US = sprintf("%c", 31)
  RS_ = sprintf("%c", 30)
  parse(text)
  printf "%s", out
}

# closing(s, i) -> the index of the ")" that closes the "(" before i.
function closing(s, i,    depth, c, n, e) {
  depth = 1
  n = length(s)
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") { i += 2; continue }
    if (c == "'") { e = index(substr(s, i + 1), "'"); if (!e) return n + 1; i += e + 1; continue }
    if (c == "\"") { i = dq_end(s, i + 1) + 1; continue }
    if (c == "(") depth++
    if (c == ")" && --depth == 0) return i
    i++
  }
  return n + 1
}

# dq_end(s, i) -> the index of the '"' closing a double-quoted string begun before i.
function dq_end(s, i,    c, n) {
  n = length(s)
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") { i += 2; continue }
    if (c == "\"") return i
    if (c == "$" && substr(s, i + 1, 1) == "(") { i = closing(s, i + 2) + 1; continue }
    i++
  }
  return n + 1
}

# backtick_end(s, i) -> the index of the "`" closing one begun before i.
function backtick_end(s, i,    c, n) {
  n = length(s)
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") { i += 2; continue }
    if (c == "`") return i
    i++
  }
  return n + 1
}

# unbacktick(s) -> the command inside `...`, its \` \\ \$ escapes resolved.
function unbacktick(s,    i, c, nx, r) {
  r = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    nx = substr(s, i + 1, 1)
    if (c == "\\" && (nx == "`" || nx == "\\" || nx == "$")) { r = r nx; i++; continue }
    r = r c
  }
  return r
}

# parse(s) -> every simple command of s appended to out. The state is local, so a
# substitution parses as a line of its own in the middle of a word.
function parse(s,    n, i, c, nx, word, inword, seg, skipnext, hdnext, hdcount, hd, hddash, j, k, e, line, t, op) {
  n = length(s)
  i = 1
  word = ""; inword = 0; seg = ""; skipnext = 0; hdnext = 0; hdcount = 0
  while (i <= n + 1) {
    c = i <= n ? substr(s, i, 1) : "\n"
    nx = substr(s, i + 1, 1)

    if (c == " " || c == "\t" || c == "\n" || c == ";" || c == "&" || c == "|" || c == "(" || c == ")" || c == "<" || c == ">") {
      if (c == "<" || c == ">") {
        # A redirection: an fd number before it is part of it, not a word.
        if (inword && word ~ /^[0-9]+$/) { word = ""; inword = 0 }
      }
      if (inword) {
        if (skipnext) skipnext = 0
        else if (hdnext) { hd[++hdcount] = word; hddash[hdcount] = hdnext == 2; hdnext = 0 }
        else seg = seg word US
        word = ""; inword = 0
      }
      if (c == "&" && nx == ">") { c = ">"; i++; nx = substr(s, i + 1, 1) }
      if (c == "<" || c == ">") {
        if ((c == "<" || c == ">") && nx == "(") {
          k = closing(s, i + 2)
          parse(substr(s, i + 2, k - i - 2))
          i = k + 1
          continue
        }
        op = c
        i++
        while (i <= n && index("<>&|-", substr(s, i, 1))) { op = op substr(s, i, 1); i++ }
        if (op == "<<<") skipnext = 1
        else if (op == "<<") hdnext = 1
        else if (op == "<<-") hdnext = 2
        else if (op ~ /&$/ || op ~ /&-$/) {
          while (i <= n && substr(s, i, 1) ~ /[0-9-]/) i++
          if (op !~ /-$/ && substr(s, i, 1) !~ /[ \t\n;&|]/ && i <= n) skipnext = 1
        } else skipnext = 1
        continue
      }
      if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")" || c == "\n") {
        if (seg != "") { out = out seg RS_; seg = "" }
      }
      if (c == "\n" && hdcount) {
        # The bodies of the heredocs this line opened: skipped, line by line.
        i++
        for (j = 1; j <= hdcount; j++) {
          while (i <= n) {
            e = index(substr(s, i), "\n")
            line = e ? substr(s, i, e - 1) : substr(s, i)
            i += e ? e : length(line) + 1
            t = line
            if (hddash[j]) sub(/^\t+/, "", t)
            if (t == hd[j]) break
          }
        }
        hdcount = 0
        continue
      }
      i++
      continue
    }

    if (c == "#" && !inword) {
      e = index(substr(s, i), "\n")
      i = e ? i + e - 1 : n + 1
      continue
    }
    if (c == "\\") {
      if (nx != "\n") { word = word nx; inword = 1 }
      i += 2
      continue
    }
    if (c == "'") {
      e = index(substr(s, i + 1), "'")
      if (!e) e = n - i + 1
      word = word substr(s, i + 1, e - 1); inword = 1
      i += e + 1
      continue
    }
    if (c == "$" && nx == "'") {
      i += 2
      inword = 1
      while (i <= n && substr(s, i, 1) != "'") {
        c = substr(s, i, 1)
        if (c == "\\") {
          nx = substr(s, i + 1, 1)
          word = word (nx == "n" ? "\n" : nx == "t" ? "\t" : nx)
          i += 2
          continue
        }
        word = word c
        i++
      }
      i++
      continue
    }
    if (c == "\"") {
      inword = 1
      i++
      while (i <= n && substr(s, i, 1) != "\"") {
        c = substr(s, i, 1)
        nx = substr(s, i + 1, 1)
        if (c == "\\" && index("$`\"\\\n", nx)) {
          if (nx != "\n") word = word nx
          i += 2
          continue
        }
        if (c == "$" && nx == "(") {
          k = closing(s, i + 2)
          parse(substr(s, i + 2, k - i - 2))
          word = word substr(s, i, k - i + 1)
          i = k + 1
          continue
        }
        if (c == "`") {
          k = backtick_end(s, i + 1)
          parse(unbacktick(substr(s, i + 1, k - i - 1)))
          word = word substr(s, i, k - i + 1)
          i = k + 1
          continue
        }
        word = word c
        i++
      }
      i++
      continue
    }
    if (c == "$" && nx == "(") {
      k = closing(s, i + 2)
      parse(substr(s, i + 2, k - i - 2))
      word = word substr(s, i, k - i + 1); inword = 1
      i = k + 1
      continue
    }
    if (c == "`") {
      k = backtick_end(s, i + 1)
      parse(unbacktick(substr(s, i + 1, k - i - 1)))
      word = word substr(s, i, k - i + 1); inword = 1
      i = k + 1
      continue
    }
    word = word c; inword = 1
    i++
  }
  if (seg != "") out = out seg RS_
}
