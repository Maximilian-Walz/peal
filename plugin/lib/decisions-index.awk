# The decisions index, index.md beside the entries: reads decisions-scan.awk's R records,
# in the order of their numbers, and prints the accepted entries first, then the
# superseded ones with what superseded each.

$1 == "R" {
  n++; name[n] = $2; num[n] = $3; title[n] = $4; status[n] = $5
  byn[$3] = $2
}

END {
  print "# Decisions"
  print ""
  print "Generated from the entries in this directory by `peal decision index`. Never edit it"
  print "by hand, and no pull request changes it: it is regenerated on the main branch after a"
  print "merge (`peal decision publish`), so two pull requests that each add an entry never"
  print "conflict here. If it looks stale, the entries are the truth."
  print ""
  print "One entry per decision: what was decided, why, and what it rules out. Once merged, an"
  print "entry is append-only: a later entry supersedes it, and the old entry's `Status:` line,"
  print "changed in the same pull request, is the one edit it ever gets. Numbers come from"
  print "`peal decision reserve SLUG`, never from reading this directory."
  print ""
  print "| # | Title |"
  print "|---|---|"
  for (i = 1; i <= n; i++) {
    if (target(status[i]) != "") continue
    printf "| [%s](%s) | %s |\n", num[i], name[i], title[i]
  }
  for (i = 1; i <= n; i++) {
    t = target(status[i])
    if (t == "") continue
    if (!shown++) {
      print ""
      print "## Superseded"
      print ""
      print "| # | Title | Superseded by |"
      print "|---|---|---|"
    }
    printf "| [%s](%s) | %s | [%s](%s) |\n", num[i], name[i], title[i], t, byn[t]
  }
}
