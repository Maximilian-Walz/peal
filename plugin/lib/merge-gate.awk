# One task file's frontmatter, as merge-gate.sh judges it: "bad" when it leaves Peal's
# YAML subset (yaml-lib.awk names the file and line on stderr), else "ok" and then each
# record of its merge key as "kind<TAB>value", the value as written once unquoted (never
# task-scan.awk's normalised one, which reads a word it does not know as the default).
#
#   awk -v name=<file for messages> -f yaml-lib.awk -f merge-gate.awk < FILE
#
# With -v guard=1 (the pre-push gate, lib/githooks.sh), after "ok" each record of the
# merge and origin keys as "key<TAB>kind<TAB>value", then "filled<TAB>Plan" and
# "filled<TAB>Outcome" for those sections that hold anything but blank lines, HTML
# comments and "---" rules (peal_text_section_filled's rule, lib/task-text.sh).

BEGIN { mode = "frontmatter" }

{ lines[NR] = $0 }

END {
  if (yaml_parse(NR) != 0) { print "bad"; exit 0 }
  print "ok"
  n = split(out, recs, "\n")
  for (j = 1; j <= n; j++) {
    if (recs[j] == "") continue
    split(recs[j], f, "\t")
    if (guard && (f[1] == "merge" || f[1] == "origin")) print f[1] "\t" f[2] "\t" f[4]
    else if (!guard && f[1] == "merge") print f[2] "\t" f[4]
  }
  if (!guard) exit 0
  # The sections as peal_text_section reads them: from the line "## NAME" to the next
  # line starting "## ".
  # Each section's open comment its own, as each is read alone there.
  sec = ""
  for (i = 1; i <= NR; i++) {
    s = lines[i]
    if (s == "## Plan" || s == "## Outcome") { sec = substr(s, 4); continue }
    if (s ~ /^## /) { sec = ""; continue }
    if (sec == "" || s == "---") continue
    while (match(s, /<!--.*-->/)) s = substr(s, 1, RSTART - 1) substr(s, RSTART + RLENGTH)
    if (inc[sec]) { if (match(s, /-->/)) { s = substr(s, RSTART + RLENGTH); inc[sec] = 0 } else continue }
    if (match(s, /<!--/)) { s = substr(s, 1, RSTART - 1); inc[sec] = 1 }
    if (s ~ /[^ \t\r]/) filled[sec] = 1
  }
  if ("Plan" in filled) print "filled\tPlan"
  if ("Outcome" in filled) print "filled\tOutcome"
}
