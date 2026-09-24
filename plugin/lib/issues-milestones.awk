# A repository's milestones -> peal_ms_load's lines, by Belfry's rules: the id is the
# title; a closed milestone is done, an open one whose description starts with "parked"
# (any case) is parked, of the others the one due soonest is current (no due date counts
# as last, then the oldest), the rest open. The order follows the due date (none last),
# then the milestone's number.
#
#   awk -F '\t' -f issues-lib.awk -f issues-milestones.awk MILESTONES
#
# MILESTONES holds "number<TAB>title<TAB>state<TAB>due_on<TAB>description<TAB>url" per
# milestone, texts with @tsv's escapes. Out: "id<TAB>title<TAB>state<TAB>order<TAB>due<TAB>url";
# with PEAL_MS_FIND in the environment, only the number of the milestone of that title
# (status 1 if there is none).

function after(a, b) {
  if ((due[a] == "") != (due[b] == "")) return due[a] == ""
  if (due[a] != due[b]) return due[a] > due[b]
  return num[a] + 0 > num[b] + 0
}

$0 != "" {
  n++
  num[n] = $1; title[n] = tsv_unescape($2); st[n] = $3; due[n] = substr($4, 1, 10)
  desc[n] = tolower(trim(tsv_unescape($5))); url[n] = $6
  gsub(/[\t\r\n]/, " ", title[n])
}

END {
  if ("PEAL_MS_FIND" in ENVIRON && ENVIRON["PEAL_MS_FIND"] != "") {
    for (i = 1; i <= n; i++) if (title[i] == ENVIRON["PEAL_MS_FIND"]) { print num[i]; exit 0 }
    exit 1
  }
  for (i = 1; i <= n; i++) idx[i] = i
  for (i = 2; i <= n; i++) {
    t = idx[i]
    for (j = i - 1; j >= 1 && after(idx[j], t); j--) idx[j + 1] = idx[j]
    idx[j + 1] = t
  }
  for (k = 1; k <= n; k++) {
    i = idx[k]
    s = "open"
    if (st[i] == "closed") s = "done"
    else if (index(desc[i], "parked") == 1) s = "parked"
    else if (!current) { s = "current"; current = 1 }
    printf "%s\t%s\t%s\t%d\t%s\t%s\n", title[i], title[i], s, k, due[i], url[i]
  }
}
