# Reads decision entry files (their paths the arguments) and prints, tab-separated:
#   R name number title status claims placeholder decision
# per file: name its file name, number the file name's four digits, title and status from
# its heading "# NNNN — Title" and its first "Status: " line, claims the numbers its
# **Supersedes** paragraphs name (comma-joined; "?" for one naming none this can read),
# placeholder 1 when a "<!--" comment is left in it, decision the first line of its
# **Decision.** paragraph. Then one line
#   E name what is wrong
# per problem of shape: a name that is not NNNN-slug.md, an empty file, a heading that is
# not "# NNNN — Title" with the file's number, no Status line or one that is neither
# "accepted" nor "superseded by NNNN" (NNNN another entry here, maybe "decision NNNN",
# anything after it free), a placeholder left, a number used twice.

# claims_of(para) -> the numbers a **Supersedes** paragraph names right after its verb:
# "decision NNNN", "decisions NNNN, MMMM and PPPP", "[NNNN](...)" or "`dir/NNNN-...`";
# "?" when it starts with none of those.
function claims_of(p,    rest, out, n) {
  rest = p
  sub(/^\*\*Supersedes( \(in part\))?\.?\*\*( \(in part\))?\.?[ \t]*/, "", rest)
  if (rest ~ /^decisions? [0-9][0-9][0-9][0-9]/) {
    sub(/^decisions? /, "", rest)
    out = ""
    while (match(rest, /^[0-9][0-9][0-9][0-9]/)) {
      out = out (out == "" ? "" : ",") substr(rest, 1, 4)
      rest = substr(rest, 5)
      if (!match(rest, /^[ \t]*([,\/&][ \t]*)?(and[ \t]+)?[0-9]/)) break
      rest = substr(rest, RLENGTH)
    }
    return out
  }
  if (rest ~ /^\[[0-9][0-9][0-9][0-9]\]/) return substr(rest, 2, 4)
  if (match(rest, /^`[^`]*[0-9][0-9][0-9][0-9]-[^`]*`/)) {
    n = substr(rest, 2, RLENGTH - 2)
    n = basename(n)
    if (is4(substr(n, 1, 4))) return substr(n, 1, 4)
  }
  return "?"
}

function flush(    c) {
  if (file == "") return
  if (para != "") claims = claims (claims == "" ? "" : ",") claims_of(para)
  name = basename(file)
  num = substr(name, 1, 4)
  nrec++
  rname[nrec] = name; rnum[nrec] = num; rtitle[nrec] = title; rstatus[nrec] = status
  rclaims[nrec] = claims; rph[nrec] = ph; rdec[nrec] = decision; rhead[nrec] = head
  rhasstatus[nrec] = hasstatus
  file = ""
}

FNR == 1 {
  flush()
  file = FILENAME; seen[FILENAME] = 1
  head = tidy($0); title = ""; status = ""; hasstatus = 0; claims = ""; para = ""
  ph = 0; decision = ""; indec = 0
}
{ line = tidy($0) }
index(line, "<!--") { ph = 1 }
!hasstatus && line ~ /^Status: / { status = substr(line, 9); sub(/[ \t]+$/, "", status); hasstatus = 1 }
line ~ /^\*\*Decision\.\*\*/ && decision == "" { decision = line; sub(/^\*\*Decision\.\*\*[ \t]*/, "", decision) }
line ~ /^\*\*Supersedes/ {
  if (para != "") claims = claims (claims == "" ? "" : ",") claims_of(para)
  para = line; next
}
para != "" {
  if (line ~ /^[ \t]*$/) { claims = claims (claims == "" ? "" : ",") claims_of(para); para = "" }
  else para = para " " line
}

END {
  flush()
  for (i = 1; i < ARGC; i++) {
    if (ARGV[i] == "" || (ARGV[i] in seen)) continue
    nrec++
    rname[nrec] = basename(ARGV[i]); rnum[nrec] = substr(rname[nrec], 1, 4); rempty[nrec] = 1
  }
  for (i = 1; i <= nrec; i++) {
    if (rname[i] ~ /^[0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*\.md$/) byn[rnum[i]] = byn[rnum[i]] (byn[rnum[i]] == "" ? "" : " ") rname[i]
  }
  for (i = 1; i <= nrec; i++) {
    n = rname[i]
    if (n !~ /^[0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*\.md$/) {
      print "E\t" n "\tits name is not NNNN-slug.md (four digits, a kebab-case slug)"
      continue
    }
    if (rempty[i]) { print "E\t" n "\tis empty"; continue }
    p = "# " rnum[i] " — "
    if (index(rhead[i], p) != 1) {
      if (rhead[i] ~ /^# [0-9][0-9][0-9][0-9] — /) print "E\t" n "\tits heading says " substr(rhead[i], 3, 4) ", its file name " rnum[i]
      else print "E\t" n "\tits first line is not the heading \"# " rnum[i] " — Title\""
    } else {
      rtitle[i] = substr(rhead[i], length(p) + 1)
      sub(/^ +/, "", rtitle[i]); sub(/ +$/, "", rtitle[i])
      if (rtitle[i] == "") print "E\t" n "\tits heading has no title"
    }
    if (!rhasstatus[i]) print "E\t" n "\thas no \"Status: \" line (accepted, or superseded by NNNN)"
    else if (rstatus[i] != "accepted") {
      t = target(rstatus[i])
      if (t == "") print "E\t" n "\tits Status is \"" rstatus[i] "\": accepted, or superseded by NNNN"
      else if (t == rnum[i]) print "E\t" n "\tsays it is superseded by itself"
      else if (!(t in byn)) print "E\t" n "\tis superseded by " t ", which is no entry here"
    }
    if (rph[i]) print "E\t" n "\tstill holds a placeholder (<!-- ... -->): fill it in"
    if (index(byn[rnum[i]], " ") && !dup[rnum[i]]++) print "E\t" n "\tshares its number with another entry: " byn[rnum[i]]
    print "R\t" n "\t" rnum[i] "\t" rtitle[i] "\t" rstatus[i] "\t" rclaims[i] "\t" rph[i] "\t" rdec[i]
  }
}
