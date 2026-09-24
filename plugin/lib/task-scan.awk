# Task files -> one task record per file, the fields task-state.awk reads.
#
#   awk -v root=<dir holding the files> -v tasks=<tasks setting> \
#     -f yaml-lib.awk -f task-scan.awk FILE...
#
# FILEs are <root>/<tasks>/<dir>/NNNN-slug.md, dir one of backlog, doing, done; any other
# file is skipped. The record, tab-separated (lists joined with commas):
#
#   id  dir  -  slug  title  milestone  depends  part-of  size  plan  needs  path
#
# dir stands where task-state.awk's state goes and "-" where its detail does. The title
# is the first "# " heading after the frontmatter, without its "NNNN — " prefix. A file
# whose frontmatter leaves Peal's subset is warned about and listed without fields; a
# depends entry that is no task id, milestone or human is warned about and dropped. One
# bad file never stops the listing.

function flush(    rel, m, nrec, recs, j, f, key, kind, value, n, lst) {
  if (cur == "") return
  rel = substr(cur, length(root) + 2)
  cur = ""
  if (index(rel, tasks "/") != 1) return
  m = substr(rel, length(tasks) + 2)
  if (m !~ /^(backlog|doing|done)\/[0-9][0-9][0-9][0-9]-[^\/]+\.md$/) return
  dir = substr(m, 1, index(m, "/") - 1)
  m = substr(m, length(dir) + 2)
  id = substr(m, 1, 4)
  slug = substr(m, 6, length(m) - 8)

  name = rel
  split("", v)
  if (yaml_parse(count) == 0) {
    nrec = split(out, recs, "\n")
    for (j = 1; j <= nrec; j++) {
      if (recs[j] == "") continue
      split(recs[j], f, "\t")
      key = f[1]; kind = f[2]; value = f[4]
      gsub(/,/, " ", value)
      if (kind == "i") v[key] = (key in v && v[key] != "") ? v[key] "," value : value
      else if (kind == "s") v[key] = value
      else v[key] = ""
    }
  }
  if (("depends" in v) && v["depends"] != "") {
    n = split(v["depends"], lst, ",")
    v["depends"] = ""
    for (j = 1; j <= n; j++) {
      if (lst[j] ~ /^[0-9][0-9][0-9][0-9]$/ || lst[j] == "milestone" || lst[j] == "human")
        v["depends"] = v["depends"] (v["depends"] == "" ? "" : ",") lst[j]
      else
        printf "peal: warning: %s: depends: '%s' is no task id, milestone or human; ignored\n", rel, lst[j] > "/dev/stderr"
    }
  }
  if (("part-of" in v) && v["part-of"] !~ /^([0-9][0-9][0-9][0-9])?$/) {
    printf "peal: warning: %s: part-of: '%s' is no task id; ignored\n", rel, v["part-of"] > "/dev/stderr"
    v["part-of"] = ""
  }

  title = ""
  for (j = body; j <= count; j++) if (lines[j] ~ /^# /) { title = substr(lines[j], 3); break }
  sub(/^ +/, "", title); sub(/[ \r]+$/, "", title)
  if (index(title, id " ") == 1) {
    t = substr(title, 6)
    if (t ~ /^(—|-|–|:) /) { sub(/^[^ ]+ /, "", t); title = t }
  }
  gsub(/\t/, " ", title)

  printf "%s\t%s\t-\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, dir, slug, title,
    v["milestone"], v["depends"], v["part-of"], v["size"], v["plan"], v["needs"], rel
}

BEGIN { mode = "frontmatter" }

FNR == 1 {
  flush()
  cur = FILENAME
  count = 0
  body = 1
  infm = 0
}

{
  lines[++count] = $0
  if (count == 1 && $0 == "---") infm = 1
  else if (infm && $0 == "---") { infm = 0; body = count + 1 }
}

END { flush() }
