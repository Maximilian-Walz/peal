# Converts one reference-style task file's `key: value` header into frontmatter.
#
#   awk -v name=<file, for messages> -v parked=<comma pools> -v open=<comma pools> \
#     -v none=<comma pools> -f yaml-render.awk -f migrate-headers.awk FILE
#
# FILE's layout: a title line 1, then its header up to the first "## " heading, which
# this prints as frontmatter, then the rest of the file (from that heading) byte for
# byte. Only key: value lines, blank lines and comment-only lines (# ..., any indent) may
# be in the header; a value's trailing " # ..." is dropped. depends and needs split on
# [ ,]+ into a flow list; other known keys (milestone, plan, size, part-of, model) stay
# scalars. milestone: a number N becomes mN (its digits as they stand); a value in none
# drops the field; a value in parked or open stays as is; anything else, and any unknown
# key or line the header cannot hold, is a problem.
#
# On success the converted file is printed to stdout and the exit status is 0. Any
# problem is instead printed to stderr as "name:line: message", one per line, nothing to
# stdout, and the exit status is 1: FILE is not touched by this script; the caller must
# not write stdout back in that case.

function in_list(v, list) {
  return v != "" && list != "" && index("," list ",", "," v ",") > 0
}

function problem(n, msg) {
  printf "%s:%s: %s\n", name, n, msg > "/dev/stderr"
  bad = 1
}

function known_key(k) {
  return k == "milestone" || k == "plan" || k == "depends" || k == "size" || \
         k == "part-of" || k == "needs" || k == "model"
}

# render(key, value) -> the frontmatter line for key: value, value already resolved
# (milestone mapped, list split); "" values were dropped by the caller.
function render(key, value,    n, items, clean, j, cnt) {
  if (key == "depends" || key == "needs") {
    n = split(value, items, /[ ,]+/)
    cnt = 0
    for (j = 1; j <= n; j++) if (items[j] != "") clean[++cnt] = items[j]
    return key ": " yaml_flow_list(clean, cnt)
  }
  return key ": " yaml_scalar(value, 0)
}

{ nlines[++count] = $0 }

END {
  if (count == 0) { problem(1, "empty file"); exit 1 }
  title = nlines[1]

  bodystart = 0
  for (i = 2; i <= count; i++) {
    if (nlines[i] ~ /^## /) { bodystart = i; break }
  }
  if (bodystart == 0) { problem(count, "no ## heading found; the header never ends"); exit 1 }

  nfields = 0
  for (i = 2; i < bodystart; i++) {
    s = nlines[i]
    if (s ~ /^[ \t]*$/) continue
    if (s ~ /^[ \t]*#/) continue
    if (!match(s, /^[A-Za-z0-9_-]+:/)) {
      problem(i, "not a key: value line: " s)
      continue
    }
    key = substr(s, 1, RLENGTH - 1)
    rest = substr(s, RLENGTH + 1)
    sub(/^[ \t]+/, "", rest)
    j = index(rest, " #")
    if (j) rest = substr(rest, 1, j - 1)
    sub(/[ \t]+$/, "", rest)

    if (!known_key(key)) { problem(i, "unknown key " key); continue }
    if (rest == "") continue

    if (key == "milestone") {
      if (rest ~ /^[0-9]+$/) { fields[++nfields] = render("milestone", "m" rest); continue }
      if (in_list(rest, none)) continue
      if (in_list(rest, parked) || in_list(rest, open)) { fields[++nfields] = render("milestone", rest); continue }
      problem(i, "milestone '" rest "' is not a number, and no --parked, --open or --none names it")
      continue
    }
    fields[++nfields] = render(key, rest)
  }

  if (bad) exit 1

  printf "---\n"
  for (i = 1; i <= nfields; i++) printf "%s\n", fields[i]
  printf "---\n\n%s\n", title
  for (i = bodystart; i <= count; i++) printf "%s\n", nlines[i]
}
