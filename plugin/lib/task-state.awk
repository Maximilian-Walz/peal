# The read model's rules, the same for every storage: task records and claims in, one
# record per task out, with its state and detail.
#
#   awk -F '\t' [-v idprefix=#] [-v cycles=1] -f task-state.awk CLAIMS TASKS
#
# TASKS holds task-scan.awk's records (or a storage's records of that shape) in the order
# to print (by id). Its second field is where the task is: done, or backlog or doing for
# a task not done. CLAIMS holds what
# the refs say about a task that has a branch, "id<TAB>state<TAB>detail<TAB>ref<TAB>pr",
# state one of awaiting-merge, claimed-live, parked. Out comes the store's list record
# (lib/store.sh):
#
#   id  state  detail  slug  title  milestone  depends  part-of  size  plan  needs  path  ref  pr  url
#
# The state, first match wins: done (the file is under done/), the claim's state, blocked
# (a depends entry is not done yet), free. The detail: for a free task its milestone ("-"
# for none), then "split:<origin> <done>/<total>" when it belongs to a split; for a
# blocked one "needs:<id>,..." with human where that holds it; for a claim, the claim's.
#
# A task not done and not claimed that lies on a depends cycle is blocked, whatever else
# it waits for, its detail followed by "cycle: 0042 → 0043 → 0042", the shortest cycle
# from it back to it (idprefix before each numeric id: "#" for issues). The edges are
# the depends after the expansion below, to tasks that exist and are not done; human,
# and a task's own id, are none. With cycles=1, instead of the records, a line per task
# not done on a cycle: "id<TAB>members<TAB>cycle", members its tasks sorted, for
# telling a cycle apart from one already known (lib/tasks.sh).
#
# depends expands two keywords and split origins:
#   milestone  every other task of this task's milestone that is not done
#   human      never resolves; a human removes it
#   an origin  a task with pieces (part-of names it, at any depth) waits for the origin
#              and every piece below it, unless the waiting task is one of those pieces
#              itself: then it waits for the named task only.

function warn(msg) { printf "peal: warning: %s\n", msg > "/dev/stderr" }

function rank(dir) { return dir == "done" ? 3 : dir == "doing" ? 2 : 1 }

function done(id) { return (id in dir) && dir[id] == "done" }

# add(id): appends id to the unmet list being built, once.
function add(id) {
  if (index("," unmet ",", "," id ",")) return
  unmet = unmet (unmet == "" ? "" : ",") id
}

# subtree(id) -> every piece below id, at any depth, by id; a part-of cycle ends the walk.
function subtree(id,    queue, head, tail, c, n, kids, j, seen2, outl, sorted) {
  head = 1; tail = 0; outl = ""
  seen2[id] = 1
  queue[++tail] = id
  while (head <= tail) {
    c = queue[head++]
    n = split(children[c], kids, ",")
    for (j = 1; j <= n; j++) {
      if (kids[j] == "" || (kids[j] in seen2)) continue
      seen2[kids[j]] = 1
      queue[++tail] = kids[j]
      outl = outl (outl == "" ? "" : ",") kids[j]
    }
  }
  return sortids(outl)
}

# sortids(list) -> the comma list's ids in ascending order, as numbers.
function sortids(list,    n, a, i, j, t, s) {
  n = split(list, a, ",")
  for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] + 0 > t + 0; j--) a[j + 1] = a[j]; a[j + 1] = t }
  s = ""
  for (i = 1; i <= n; i++) s = s (i > 1 ? "," : "") a[i]
  return s
}

# sortstr(list) -> the comma list's items in ascending string order.
function sortstr(list,    n, a, i, j, t, s) {
  n = split(list, a, ",")
  for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t }
  s = ""
  for (i = 1; i <= n; i++) s = s (i > 1 ? "," : "") a[i]
  return s
}

function member(list, id) { return index("," list ",", "," id ",") > 0 }

function shown(id) { return id ~ /^[0-9]+$/ ? idprefix id : id }

# cycle(v) -> the shortest way along edges from v back to v, "v → a → v", or "" if there
# is none; the ids it passes through, v's included, in cyclemembers.
function cycle(v,    queue, head, tail, from, seen3, c, n, e, j, w, p, s) {
  head = 1; tail = 0
  queue[++tail] = v
  while (head <= tail) {
    c = queue[head++]
    n = split(edges[c], e, ",")
    for (j = 1; j <= n; j++) {
      w = e[j]
      if (w == "" || (w in seen3)) continue
      seen3[w] = 1; from[w] = c
      if (w == v) {
        s = shown(v); cyclemembers = v
        for (p = c; p != v; p = from[p]) { s = shown(p) " → " s; cyclemembers = cyclemembers "," p }
        return shown(v) " → " s
      }
      queue[++tail] = w
    }
  }
  return ""
}

# unmet_of(id) -> what task id waits for, by the expansion above: the ids not done,
# human, and ids that are no task.
function unmet_of(id,    nd, d, j, dep, k, peer, np, pc) {
  unmet = ""
  nd = split(deps[id], d, ",")
  for (j = 1; j <= nd; j++) {
    dep = d[j]
    if (dep == "human") { add("human"); continue }
    if (dep == "milestone") {
      if (ms[id] == "") {
        warn("task " id " depends on its milestone but has none; ignored")
        continue
      }
      for (k = 1; k <= n; k++) {
        peer = order[k]
        if (peer != id && ms[peer] == ms[id] && !done(peer)) add(peer)
      }
      continue
    }
    if (dep == id) { warn("task " id " depends on itself; ignored"); continue }
    if (!(dep in dir)) { warn("task " id " depends on " dep ", which is no task"); add(dep); continue }
    if ((dep in pieces) && !member(pieces[dep], id)) {
      if (!done(dep)) add(dep)
      np = split(pieces[dep], pc, ",")
      for (k = 1; k <= np; k++) if (pc[k] != id && !done(pc[k])) add(pc[k])
      continue
    }
    if (!done(dep)) add(dep)
  }
  return unmet
}

FILENAME == ARGV[1] {
  if ($1 == "") next
  cstate[$1] = $2; cdetail[$1] = $3; cref[$1] = $4; cpr[$1] = $5
  next
}

{
  id = $1
  if (id in dir) {
    if (rank($2) <= rank(dir[id])) {
      warn("task " id " has more than one file: " path[id] " and " $12 "; reading " path[id])
      next
    }
    warn("task " id " has more than one file: " path[id] " and " $12 "; reading " $12)
  } else order[++n] = id
  dir[id] = $2; slug[id] = $4; title[id] = $5; ms[id] = $6; deps[id] = $7
  partof[id] = $8; size[id] = $9; plan[id] = $10; needs[id] = $11; path[id] = $12; url[id] = $13
}

END {
  # Each task's own part-of, where it names another task that exists.
  for (i = 1; i <= n; i++) {
    id = order[i]; p = partof[id]
    if (p == "") continue
    if (p == id) { warn("task " id "'s part-of names itself; ignored"); continue }
    if (!(p in dir)) { warn("task " id "'s part-of " p " names no task; ignored"); continue }
    parent[id] = p
    children[p] = children[p] (children[p] == "" ? "" : ",") id
  }
  for (i = 1; i <= n; i++) {
    id = order[i]
    if (children[id] != "") pieces[id] = subtree(id)
  }

  # What every task not done waits for, claimed or not, and the edges among them.
  for (i = 1; i <= n; i++) {
    id = order[i]
    if (done(id)) continue
    need[id] = unmet_of(id)
    nu = split(need[id], u, ",")
    for (j = 1; j <= nu; j++)
      if ((u[j] in dir) && u[j] != id) edges[id] = edges[id] (edges[id] == "" ? "" : ",") u[j]
  }
  for (i = 1; i <= n; i++) {
    id = order[i]
    if (done(id) || edges[id] == "") continue
    cyc[id] = cycle(id)
    if (cycles && cyc[id] != "") printf "%s\t%s\t%s\n", id, sortstr(cyclemembers), cyc[id]
  }
  if (cycles) exit

  for (i = 1; i <= n; i++) {
    id = order[i]
    state = ""; detail = ""
    if (done(id)) state = "done"
    else if (id in cstate) { state = cstate[id]; detail = cdetail[id] }
    else {
      unmet = need[id]
      if (cyc[id] != "") { state = "blocked"; detail = "needs:" unmet " cycle: " cyc[id] }
      else if (unmet != "") { state = "blocked"; detail = "needs:" unmet }
      else {
        state = "free"
        detail = ms[id] == "" ? "-" : ms[id]
        # The split a free task belongs to: its own, if it has pieces, else its parent's.
        origin = (id in pieces) ? id : ((id in parent) ? parent[id] : "")
        if (origin != "") {
          np = split(pieces[origin], pc, ",")
          dn = done(origin) ? 1 : 0
          for (k = 1; k <= np; k++) if (done(pc[k])) dn++
          detail = detail " split:" origin " " dn "/" (np + 1)
        }
      }
    }
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, state, detail,
      slug[id], title[id], ms[id], deps[id], partof[id], size[id], plan[id], needs[id],
      path[id], cref[id], cpr[id], url[id]
  }
}
