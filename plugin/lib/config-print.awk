# Prints yaml-parse.awk records as "path: value" lines, a list's items gathered into one
# flow list. Used with yaml-render.awk:
#
#   awk -F '\t' -f yaml-render.awk -f config-print.awk RECORDS

function flush() {
  if (path == "") return
  if (kind == "s") print path ":" (items[1] == "" ? "" : " " yaml_scalar(items[1], 0))
  else if (kind == "m") print path ": {}"
  else print path ": " yaml_flow_list(items, n)
  path = ""
}

$0 == "" { next }
$1 != path { flush(); path = $1; kind = $2; n = 0 }
$2 == "s" || $2 == "i" { items[++n] = $4 }
END { flush() }
