# Rendering values into Peal's YAML subset; included with -f by the writers.
# Every rendering reads back through yaml-parse.awk as the same value.

# yaml_scalar(v, inlist) -> v plain where that reads back as v, else 'single-quoted'.
# inlist: v is an item of a flow list, where , [ ] { } end a plain value too.
function yaml_scalar(v, inlist) {
  if (v != "" && v !~ /^ | $/ && v !~ /^[][{}#&*!|>'"%@`,]/ && v !~ /^[-?:]( |$)/ \
      && !index(v, ": ") && v !~ /:$/ && !index(v, " #") \
      && !(inlist && v ~ /[][{},]/))
    return v
  gsub(/'/, "''", v)
  return "'" v "'"
}

# yaml_flow_list(items, n) -> "[a, b]" for items[1..n].
function yaml_flow_list(items, n,    j, s) {
  s = ""
  for (j = 1; j <= n; j++) s = s (j > 1 ? ", " : "") yaml_scalar(items[j], 1)
  return "[" s "]"
}
