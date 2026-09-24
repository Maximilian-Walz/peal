# The human's summary: the tasks not done, grouped by milestone.
#
#   awk -F '\t' -f overview.awk MILESTONES LIST
#
# MILESTONES holds peal_ms_load's lines, LIST the store's list records. The groups: the
# current milestone, tasks without one, the open milestones by order, the parked ones,
# the done ones that still hold a task, and milestones no file defines. Each has a header
# with how many of its tasks are open and done, then "  NNNN  state  slug  detail" per open
# task, by id, the id marked "!" for an urgent task and "↑" for a high one. A free task's
# detail leaves out its milestone, which the header says.

$0 == "" { next }

FILENAME == ARGV[1] {
  ms[++nms] = $1; title[$1] = $2; mstate[$1] = $3
  next
}

{
  m = $6
  if (!(m in seen)) { seen[m] = 1; if (m != "" && !(m in mstate)) unknown[++nunknown] = m }
  if ($2 == "done") { ndone[m]++; next }
  detail = $3
  if ($2 == "free") { sub(/^[^ ]*/, "", detail); sub(/^ /, "", detail) }
  mark = $16 == "urgent" ? "!" : $16 == "high" ? "↑" : " "
  lines[m] = lines[m] sprintf("  %s%s %-14s %s%s\n", $1, mark, $2, $4, detail == "" ? "" : "  " detail)
  nopen[m]++
}

function group(m, header) {
  if (nopen[m] == 0) return
  printf "%s — %d open, %d done\n%s\n", header, nopen[m], ndone[m], lines[m]
}

function named(m) { return m (title[m] != "" && title[m] != m ? " " title[m] : "") " (" mstate[m] ")" }

END {
  for (i = 1; i <= nms; i++) if (mstate[ms[i]] == "current") group(ms[i], named(ms[i]))
  group("", "No milestone")
  for (i = 1; i <= nms; i++) if (mstate[ms[i]] == "open") group(ms[i], named(ms[i]))
  for (i = 1; i <= nms; i++) if (mstate[ms[i]] == "parked") group(ms[i], named(ms[i]))
  for (i = 1; i <= nms; i++) if (mstate[ms[i]] == "done") group(ms[i], named(ms[i]))
  for (i = 1; i <= nunknown; i++) group(unknown[i], unknown[i] " (no such milestone)")
}
