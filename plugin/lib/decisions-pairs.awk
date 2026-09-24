# The supersedes pairing of a branch's decision entries: reads decisions-scan.awk's R
# records of the entries in the work tree, then the branch's changes to them as lines
#   A name | M name base-status | D name
# (tab-separated; base-status the entry's Status on the main branch), and prints
# "name<TAB>what is wrong" per problem:
#   - an entry deleted: entries are append-only;
#   - a Status turned "superseded by NNNN" (added, or changed on this branch) whose NNNN
#     is not an entry this branch adds, or whose **Supersedes** paragraph does not name it;
#   - an added entry's **Supersedes** naming no number right after its verb, naming no
#     entry, or naming one whose Status does not say "superseded by" the added one.
# Only what the branch changes is checked: a merged entry's text is frozen, however it
# was worded then.

FILENAME == ARGV[1] && $1 == "R" {
  num[$2] = $3; status[$2] = $5; claims[$2] = $6
  byn[$3] = $2
  next
}
FILENAME == ARGV[1] { next }

$1 == "D" { print $2 "\tis deleted: entries are append-only; a later one supersedes it instead"; next }
$1 == "A" { added[$2] = 1 }
$1 == "A" || $1 == "M" {
  if (!($2 in num)) next
  n++; order[n] = $2
  if ($1 == "M" && $3 == status[$2]) next
  t = target(status[$2])
  if (t == "") next
  succ = byn[t]
  if (succ == "") next
  turned[$2] = t
}

END {
  for (i = 1; i <= n; i++) {
    name = order[i]
    if (name in turned) {
      t = turned[name]; succ = byn[t]
      if (!(succ in added)) {
        print name "\tsays it is superseded by " t ", which this branch does not add: a supersession is a new entry naming the old one, both in one pull request"
      } else if (index("," claims[succ] ",", "," num[name] ",") == 0) {
        print name "\tsays it is superseded by " t ", but " succ " has no **Supersedes** paragraph naming " num[name]
      }
    }
    if (!(name in added) || claims[name] == "") continue
    c = split(claims[name], cl, ",")
    for (j = 1; j <= c; j++) {
      if (cl[j] == "?") {
        print name "\thas a **Supersedes** paragraph naming no entry right after its verb: \"**Supersedes** decision NNNN.\" (or decisions NNNN and MMMM)"
        continue
      }
      old = byn[cl[j]]
      if (old == "") { print name "\tsupersedes " cl[j] ", which is no entry"; continue }
      t = target(status[old])
      if (t == num[name]) continue
      if (t != "") print name "\tsupersedes " cl[j] ", which is superseded by " t " already: an entry's Status changes once; say how this one extends " cl[j] " instead"
      else print name "\tsupersedes " cl[j] ", whose Status still reads \"" status[old] "\": make it \"superseded by " num[name] "\" on this branch too"
    }
  }
}
