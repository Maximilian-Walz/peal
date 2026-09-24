# The checks on a task's frontmatter before it is filed or rewritten; every problem is
# reported, then exit 2. On success one line: "milestone<TAB>plan<TAB>size".
#
#   awk -F '\t' -v mode=plain|split|batch|revise -v label=<name for messages> \
#     [-v piece=<index> -v pieces=<count>] [-v check_ids=1] [-v check_ms=1] \
#     [-v oldms=<milestone>] -f task-check.awk CONTEXT RECORDS
#
# RECORDS is yaml-parse.awk's output for the frontmatter. CONTEXT tells what is known:
#   field<TAB>name<TAB>values   a project field (task.fields), values comma-joined or empty
#   size<TAB>S                  a size tier
#   ms<TAB>id<TAB>state         a milestone
#   id<TAB>ID                   a task that exists
# Milestones are checked only with check_ms, task ids only with check_ids: a queued idea
# is checked offline, and checked again when it is filed.
#
# By mode: split pieces carry "part-of: ORIGIN" and may name their siblings as PART1..n
# in depends and go into a parked milestone; plain and batch filings do neither. revise
# (oldms: the milestone before) checks a milestone only when it changes, and never moves
# a task into or out of a parked milestone: that is a milestone review's call.

function problem(msg) {
  printf "peal: %s: %s\n", label, msg > "/dev/stderr"
  bad = 1
}

function single(key) {
  if (kind[key] != "s") { problem(key " takes a single value, not a list"); return 0 }
  return 1
}

FILENAME == ARGV[1] {
  if ($1 == "field") { custom[$2] = 1; allowed[$2] = $3 }
  else if ($1 == "size") sizes[$2] = 1
  else if ($1 == "ms") msstate[$2] = $3
  else if ($1 == "id") ids[$2] = 1
  next
}

$1 == "" { next }

{
  key = $1
  if (!(key in kind)) keys[++nkeys] = key
  kind[key] = ($2 == "e") ? "i" : $2
  if ($2 == "i") { items[key, ++nitems[key]] = $4; value[key] = value[key] (nitems[key] > 1 ? "," : "") $4 }
  else if ($2 == "s") value[key] = $4
}

END {
  peal["milestone"] = peal["plan"] = peal["size"] = peal["depends"] = 1
  peal["part-of"] = peal["needs"] = peal["model"] = peal["owner"] = peal["priority"] = 1
  for (k = 1; k <= nkeys; k++) {
    key = keys[k]
    if (!(key in peal) && !(key in custom))
      problem("unknown field " key " (Peal's: milestone, plan, size, depends, part-of, needs, model, owner, priority; a project adds its own under task.fields in .peal/config.yml)")
  }

  m = value["milestone"]
  if (("milestone" in kind) && single("milestone") && m != "" && check_ms \
      && !(mode == "revise" && m == oldms)) {
    if (!(m in msstate)) problem("milestone " m " does not exist")
    else if (msstate[m] == "done") problem("milestone " m " is done")
    else if (msstate[m] == "parked" && mode != "split")
      problem("milestone " m " is parked; only a milestone review moves a task there")
  }
  if (mode == "revise" && m != oldms && oldms != "" && msstate[oldms] == "parked")
    problem("milestone " oldms " is parked; only a milestone review moves a task out of it")

  if (("plan" in kind) && single("plan") && value["plan"] !~ /^(required|skipped)?$/)
    problem("plan " value["plan"] " is not required or skipped")
  if (("size" in kind) && single("size") && value["size"] != "" && !(value["size"] in sizes))
    problem("size " value["size"] " is not one of the sizes setting's tiers")
  if ("model" in kind) single("model")
  if (("owner" in kind) && single("owner") && value["owner"] !~ /^(ai|human)?$/)
    problem("owner " value["owner"] " is not ai or human")
  if (("priority" in kind) && single("priority") && value["priority"] !~ /^(urgent|high|normal|low)?$/)
    problem("priority " value["priority"] " is not urgent, high, normal or low")

  if ("part-of" in kind) {
    if (mode == "split") {
      if (single("part-of") && value["part-of"] != "ORIGIN")
        problem("part-of must be ORIGIN, which becomes the task split")
    } else if (mode != "revise") problem("part-of is written by a split only")
  } else if (mode == "split") problem("a piece of a split needs part-of: ORIGIN")

  if (kind["depends"] == "s" && value["depends"] != "") { items["depends", 1] = value["depends"]; nitems["depends"] = 1 }
  for (j = 1; j <= nitems["depends"]; j++) {
    d = items["depends", j]
    if (d == "milestone") {
      if (m == "") problem("depends: milestone needs a milestone to wait for")
    } else if (d == "human") {
    } else if (d ~ /^[0-9]+$/) {
      if (check_ids && !(d in ids)) problem("depends: " d " is no task")
    } else if (mode == "split" && d == "ORIGIN") {
    } else if (mode == "split" && d ~ /^PART[0-9]+$/) {
      p = substr(d, 5) + 0
      if (p < 1 || p > pieces) problem("depends: " d " is not one of the pieces PART1..PART" pieces)
      else if (p == piece) problem("depends: " d " is this piece itself")
    } else problem("depends: " d " is no task id, milestone or human" (mode == "split" ? ", ORIGIN or PARTn" : ""))
  }

  for (key in custom) {
    if (!(key in kind) || allowed[key] == "") continue
    na = split(allowed[key], av, ",")
    if (kind[key] == "s") { nv = 1; vv[1] = value[key] } else nv = split(value[key], vv, ",")
    for (j = 1; j <= nv; j++) {
      if (vv[j] == "") continue
      ok = 0
      for (a = 1; a <= na; a++) if (vv[j] == av[a]) ok = 1
      if (!ok) problem(key " " vv[j] " is not one of " allowed[key])
    }
  }

  if (bad) exit 2
  printf "%s\t%s\t%s\n", m, value["plan"], value["size"]
}
