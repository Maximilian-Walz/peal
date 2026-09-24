# An issue -> its task text: the frontmatter from its milestone, labels and reference
# lines, the heading "# ID — Title", and the body without those lines.
#
#   awk -F '\t' -v label=<filter label> -v claimed=<claim label> -v fields=<a,b> \
#     -f yaml-render.awk -f issues-lib.awk -f issues-text.awk ISSUE
#
# ISSUE holds one issue as issues-lib.awk describes it; fields names the project's own
# frontmatter fields (task.fields), which labels "<field>: <value>" carry like Peal's
# size, plan, model, breaking and release-note.

function put(key, list,    n, it) {
  if (list == "") return
  n = split(list, it, ",")
  if (key == "depends" || key == "needs" || n > 1) print key ": " yaml_flow_list(it, n)
  else print key ": " yaml_scalar(it[1], 0)
}

{
  n = split(tsv_unescape($5), ls, ",")
  nf = split("plan,size,model,breaking,release-note," fields, fl, ",")
  for (j = 1; j <= nf; j++) if (fl[j] != "") want[fl[j]] = 1
  for (j = 1; j <= n; j++) {
    l = trim(ls[j])
    if (l == claimed || l == label || !label_kv(l)) continue
    if (LKEY == "needs" || (LKEY in want)) v[LKEY] = add_item(v[LKEY], LVALUE)
  }
  body_refs(tsv_unescape($8))
  title = tsv_unescape($3)
  gsub(/[\t\r\n]/, " ", title)
  ms = tsv_unescape($4)

  print "---"
  if (ms != "") print "milestone: " yaml_scalar(ms, 0)
  put("plan", v["plan"])
  put("size", v["size"])
  put("depends", DEPS)
  put("part-of", PARTOF)
  put("needs", v["needs"])
  put("model", v["model"])
  put("breaking", v["breaking"])
  put("release-note", v["release-note"])
  for (j = 6; j <= nf; j++) if (fl[j] != "") put(fl[j], v[fl[j]])
  print "---"
  print ""
  print "# " $1 " — " title

  # The body without its leading and trailing blank lines.
  nb = split(BODY_REST, b, "\n")
  first = 1
  while (first <= nb && b[first] ~ /^[ \t]*$/) first++
  last = nb
  while (last >= first && b[last] ~ /^[ \t]*$/) last--
  if (first <= last) print ""
  for (j = first; j <= last; j++) print b[j]
  exit
}
