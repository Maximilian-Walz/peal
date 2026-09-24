# JSON helpers for the board's lines and the requests to GitHub; included with -f.

# json_str(s) -> s as a JSON string. By character: gsub escapes differ between awks.
function json_str(s,    i, c, out) {
  out = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == "\\" || c == "\"") out = out "\\"
    else if (c == "\n") c = "\\n"
    else if (c == "\t") c = "\\t"
    else if (c == "\r") c = "\\r"
    out = out c
  }
  return "\"" out "\""
}

# json_list(s) -> the comma-separated items of s as a JSON array of strings.
function json_list(s,    n, items, j, out) {
  n = split(s, items, ",")
  out = ""
  for (j = 1; j <= n; j++) out = out (j > 1 ? "," : "") json_str(items[j])
  return "[" out "]"
}
