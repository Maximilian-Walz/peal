# Issues -> one task record per issue, the fields task-state.awk reads, with two more.
#
#   awk -F '\t' -v label=<filter label> -v claimed=<claim label> \
#     -f issues-lib.awk -f issues-scan.awk LISTED EXTRA
#
# LISTED and EXTRA hold issues as issues-lib.awk describes them. LISTED are the tasks:
# without a filter label only those opened by someone with write access count (anyone
# may open an issue on a public repository). EXTRA are issues only named by a task's
# depends or part-of, read to know whether they are done. The record:
#
#   id  dir  -  slug  title  milestone  depends  part-of  size  plan  needs  path  url  labelled  extra
#
# dir is done for a closed issue, backlog for an open one; path is empty, url the
# issue's page; labelled is 1 when the issue carries the claim label, extra 1 for an
# issue from EXTRA (whose milestone and part-of are left out: it is no task here).

FNR == 1 { extra = FILENAME == ARGV[2] }

$0 == "" || ($1 in seen) { next }

{
  id = $1
  if (!extra && label == "" && $6 != "OWNER" && $6 != "MEMBER" && $6 != "COLLABORATOR") next
  seen[id] = 1
  title = tsv_unescape($3)
  gsub(/[\t\r\n]/, " ", title)
  ms = extra ? "" : tsv_unescape($4)
  n = split(tsv_unescape($5), ls, ",")
  labelled = size = plan = needs = ""
  for (j = 1; j <= n; j++) {
    l = trim(ls[j])
    if (l == claimed) labelled = 1
    else if (l != label && label_kv(l)) {
      if (LKEY == "needs") needs = add_item(needs, LVALUE)
      else if (LKEY == "size") size = LVALUE
      else if (LKEY == "plan") plan = LVALUE
    }
  }
  body_refs(tsv_unescape($8))
  printf "%s\t%s\t-\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t\t%s\t%s\t%s\n", id,
    ($2 == "closed" ? "done" : "backlog"), issue_slug(title), title, ms, DEPS,
    (extra ? "" : PARTOF), size, plan, needs, $7, labelled, (extra ? 1 : "")
}
