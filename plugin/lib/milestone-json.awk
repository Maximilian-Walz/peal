# peal_ms_load's lines -> the board's milestone lines, the shape of Belfry's contract:
# {"milestone":{"id":...,"title":...,"state":...,"order":...,"due":...}}, empty fields
# left out, and a parked milestone's "reason" after them (Belfry reads an "until #12, ..."
# in it).
#
#   awk -F '\t' -f json.awk -f milestone-json.awk

{ line = "{\"milestone\":{\"id\":" json_str($1)
  if ($2 != "") line = line ",\"title\":" json_str($2)
  line = line ",\"state\":" json_str($3)
  if ($4 != "") line = line ",\"order\":" $4
  if ($5 != "") line = line ",\"due\":" json_str($5)
  if ($7 != "") line = line ",\"reason\":" json_str($7)
  print line "}}" }
