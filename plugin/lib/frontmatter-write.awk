# Rewrites one field of a file's frontmatter and prints the whole file.
#
#   PEAL_FM_OP=scalar|list|unset PEAL_FM_KEY=key PEAL_FM_COUNT=n PEAL_FM_VALUES=v1\nv2... \
#     awk -f yaml-render.awk -f frontmatter-write.awk FILE
#
# Only the field's own lines change: a field that is there is replaced where it stands
# (a block list stays a block list at its indentation), a new one goes last, a file
# without frontmatter gets one. Everything else is copied byte for byte, though a missing
# final newline is added. The caller has checked FILE with yaml-parse.awk first; the
# values arrive through the environment because awk -v would interpret backslashes.

function field_lines(    j, out) {
  if (op == "unset") return ""
  if (op == "scalar") return key ":" (items[1] == "" ? "" : " " yaml_scalar(items[1], 0)) "\n"
  if (isblock && n > 0) {
    out = key ":\n"
    for (j = 1; j <= n; j++) out = out blockind "- " yaml_scalar(items[j], 0) "\n"
    return out
  }
  return key ": " yaml_flow_list(items, n) "\n"
}

function continues(s) { return s ~ /^ / || s ~ /^-( |$)/ }

BEGIN {
  op = ENVIRON["PEAL_FM_OP"]
  key = ENVIRON["PEAL_FM_KEY"]
  n = ENVIRON["PEAL_FM_COUNT"] + 0
  split(ENVIRON["PEAL_FM_VALUES"], items, "\n")
  if (n == 1 && ENVIRON["PEAL_FM_VALUES"] == "") items[1] = ""
  if (op == "scalar") n = 1
}

{ lines[NR] = $0 }

END {
  if (NR == 0 || lines[1] != "---") {
    if (op == "unset") { for (i = 1; i <= NR; i++) print lines[i]; exit }
    printf "---\n%s---\n", field_lines()
    if (NR > 0) print ""
    for (i = 1; i <= NR; i++) print lines[i]
    exit
  }
  for (c = 2; c <= NR; c++) if (lines[c] == "---") break
  s = 0
  for (i = 2; i < c; i++) {
    if (index(lines[i], key ":") == 1 && (length(lines[i]) == length(key) + 1 \
        || substr(lines[i], length(key) + 2, 1) == " ")) { s = i; break }
  }
  blockind = ""; isblock = 0
  if (s) {
    e = s
    for (j = s + 1; j < c; j++) {
      if (continues(lines[j])) { e = j; continue }
      if (lines[j] !~ /^ *$/) break
      for (k = j; k < c && lines[k] ~ /^ *$/; k++) ;
      if (k < c && continues(lines[k])) { e = k; j = k; continue }
      break
    }
    for (j = s + 1; j <= e; j++) {
      if (lines[j] ~ /^ *- / || lines[j] ~ /^ *-$/) { match(lines[j], /^ */); blockind = substr(lines[j], 1, RLENGTH); isblock = 1; break }
      if (lines[j] !~ /^ *$/) break
    }
  } else {
    s = c; e = c - 1
  }
  for (i = 1; i < s; i++) print lines[i]
  printf "%s", field_lines()
  for (i = e + 1; i <= NR; i++) print lines[i]
}
