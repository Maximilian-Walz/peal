# Sets or removes one top-level setting of a .peal/config.yml as text, keeping every
# other line (comments included) as it is. A setting's block is its "key:" line at the
# start of a line and the indented lines after it; blank lines inside it belong to it only
# when an indented line follows.
#
#   awk -v key=storage -v block=FILE -f config-block.awk CONFIG
#       KEY's block replaced by FILE's lines, where it was; a new one goes after the
#       file's last setting, else before the line "# Peal's defaults", else last. An
#       empty FILE removes it (and a blank line, when one is left on either side).
#   awk -v key=K -v op=has -f config-block.awk CONFIG
#       status 0 if the file sets K
#   awk -v op=active -f config-block.awk CONFIG
#       status 0 if the file sets anything at all

{ line[NR] = $0 }

function indented(s) { return s ~ /^[ \t]/ && s !~ /^[ \t]*$/ }
function blank(s) { return s ~ /^[ \t]*$/ }
function comment(s) { return s ~ /^[ \t]*#/ }

END {
  n = NR
  if (op == "active") {
    for (i = 1; i <= n; i++) if (!blank(line[i]) && !comment(line[i])) exit 0
    exit 1
  }
  first = 0
  for (i = 1; i <= n; i++)
    if (index(line[i], key ":") == 1) { first = i; break }
  if (op == "has") exit !first
  if (first) {
    last = first
    for (j = first + 1; j <= n; j++) {
      if (indented(line[j])) { last = j; continue }
      if (blank(line[j])) continue
      break
    }
    if (block == "" && first > 1 && blank(line[first - 1]) && (last == n || blank(line[last + 1]))) last++
  } else {
    first = 0
    for (i = n; i >= 1 && !first; i--) if (!blank(line[i]) && !comment(line[i])) first = i + 1
    for (i = 1; i <= n && !first; i++) if (index(line[i], "# Peal's defaults") == 1) first = i
    if (!first) first = n + 1
    last = first - 1
  }
  for (i = 1; i < first; i++) print line[i]
  if (block != "") while ((getline l < block) > 0) print l
  for (i = last + 1; i <= n; i++) print line[i]
}
