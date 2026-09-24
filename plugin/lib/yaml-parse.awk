# Peal's YAML subset -> one record per value: "path<TAB>kind<TAB>line<TAB>value" (see
# yaml-lib.awk for the records and the subset).
#
#   awk -v mode=frontmatter|config -v name=<file for messages> \
#     -f yaml-lib.awk -f yaml-parse.awk FILE
#
# A problem is reported with the file and line: exit 2, and no records.

{ lines[NR] = $0 }

END {
  status = yaml_parse(NR)
  printf "%s", out
  exit status
}
