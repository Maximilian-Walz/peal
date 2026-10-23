# One task file's frontmatter, as merge-gate.sh judges it: "bad" when it leaves Peal's
# YAML subset (yaml-lib.awk names the file and line on stderr), else "ok" and then each
# record of its merge key as "kind<TAB>value", the value as written once unquoted (never
# task-scan.awk's normalised one, which reads a word it does not know as the default).
#
#   awk -v name=<file for messages> -f yaml-lib.awk -f merge-gate.awk < FILE

BEGIN { mode = "frontmatter" }

{ lines[NR] = $0 }

END {
  if (yaml_parse(NR) != 0) { print "bad"; exit 0 }
  print "ok"
  n = split(out, recs, "\n")
  for (j = 1; j <= n; j++) {
    if (recs[j] == "") continue
    split(recs[j], f, "\t")
    if (f[1] == "merge") print f[2] "\t" f[4]
  }
}
