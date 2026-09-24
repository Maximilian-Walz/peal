# A request's JSON object from its arguments, pairs of KIND:KEY and VALUE: KIND s a
# string, f a file's content as a string, r raw JSON (a number, null), l a list of
# strings, one per line of VALUE.
#
#   awk -f json.awk -f json-request.awk s:title "A title" f:body FILE l:labels "$labels"

BEGIN {
  out = "{"
  for (i = 1; i < ARGC; i += 2) {
    kind = substr(ARGV[i], 1, 1); key = substr(ARGV[i], 3); v = ARGV[i + 1]
    if (kind == "f") {
      f = v; v = ""
      while ((getline line < f) > 0) v = v line "\n"
      close(f)
      sub(/\n$/, "", v)
      val = json_str(v)
    } else if (kind == "s") val = json_str(v)
    else if (kind == "r") val = v
    else {
      n = split(v, it, "\n"); val = ""
      for (j = 1; j <= n; j++) if (it[j] != "") val = val (val == "" ? "" : ",") json_str(it[j])
      val = "[" val "]"
    }
    out = out (i > 1 ? "," : "") json_str(key) ":" val
  }
  print out "}"
  exit
}
