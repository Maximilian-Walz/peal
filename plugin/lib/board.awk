# The store's list records -> the board's task lines, one JSON object per task in the
# shape of Belfry's contract: id and state always, every other field when it has a value
# (url for an issue, path for a file). No ref: the contract's ref locates a file not on
# the main branch yet, and every task's file is there from its filing on.
#
#   awk -F '\t' -f json.awk -f board.awk

{
  line = "{\"id\":" json_str($1) ",\"state\":" json_str($2)
  if ($4 != "") line = line ",\"slug\":" json_str($4)
  if ($5 != "") line = line ",\"title\":" json_str($5)
  if ($6 != "") line = line ",\"milestone\":" json_str($6)
  if ($7 != "") line = line ",\"depends\":" json_list($7)
  if ($8 != "") line = line ",\"part_of\":" json_str($8)
  if ($9 != "") line = line ",\"size\":" json_str($9)
  if ($10 != "") line = line ",\"plan\":" json_str($10)
  if ($11 != "") line = line ",\"needs\":" json_list($11)
  if ($14 != "") line = line ",\"pr\":" json_str($14)
  if ($15 != "") line = line ",\"url\":" json_str($15)
  if ($12 != "") line = line ",\"path\":" json_str($12)
  print line "}"
}
