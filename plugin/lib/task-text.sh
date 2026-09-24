# shellcheck shell=bash
# A task's text, whatever stores it: the heading "# NNNN — Title" after the frontmatter,
# the sections (Intent, Scope, Done when, Raw, Notes, Outcome), and the checks and edits
# the backlog commands make on them. Each reads the text on stdin.

# peal_text_title ID -> the title of the heading "# ID — Title"; status 1 if the first
# heading after the frontmatter is not that, or has no title.
peal_text_title() {
  awk -v id="$1" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm { if ($0 == "---") fm = 0; next }
    /^# / {
      p = "# " id " — "
      if (index($0, p) != 1) exit 1
      t = substr($0, length(p) + 1)
      sub(/^ +/, "", t); sub(/[ \r]+$/, "", t)
      if (t == "") exit 1
      print t; found = 1; exit
    }
    END { exit !found }'
}

# peal_text_section NAME -> the lines of section "## NAME", without its heading; status 1
# if there is no such section.
peal_text_section() {
  awk -v h="## $1" '
    $0 == h { in_ = 1; found = 1; next }
    /^## / { in_ = 0 }
    in_ { print }
    END { exit !found }'
}

# peal_text_has_section NAME -> status 0 if the text has the heading "## NAME".
peal_text_has_section() {
  awk -v h="## $1" '$0 == h { found = 1 } END { exit !found }'
}

# peal_text_outcome_filled -> status 0 if "## Outcome" holds anything but blank lines and
# HTML comments (the template's placeholder): work happened.
peal_text_outcome_filled() {
  peal_text_section_filled Outcome
}

# peal_text_section_filled NAME -> status 0 if section "## NAME" holds anything but blank
# lines, HTML comments and the "---" rule before the Outcome.
peal_text_section_filled() {
  peal_text_section "$1" | awk '
    $0 == "---" { next }
    { while (match($0, /<!--.*-->/)) $0 = substr($0, 1, RSTART - 1) substr($0, RSTART + RLENGTH)
      if (inc) { if (match($0, /-->/)) { $0 = substr($0, RSTART + RLENGTH); inc = 0 } else next }
      if (match($0, /<!--/)) { $0 = substr($0, 1, RSTART - 1); inc = 1 }
      if ($0 ~ /[^ \t\r]/) filled = 1 }
    END { exit !filled }'
}

# peal_text_outcome_placeholder -> status 0 if "## Outcome" still holds an HTML comment,
# the template's placeholder or a note left in it.
peal_text_outcome_placeholder() {
  peal_text_section Outcome | grep -q -F '<!--'
}

# peal_text_add_note LINE -> the text with LINE as its own paragraph right under the first
# "## Notes" heading.
peal_text_add_note() {
  PEAL_NOTE=$1 awk '
    { print }
    $0 == "## Notes" && !done { print ""; print ENVIRON["PEAL_NOTE"]; done = 1 }'
}

# peal_text_set_outcome LINE -> the text with everything from "## Outcome" on replaced by
# that heading and LINE; a text without the heading gets it at its end.
peal_text_set_outcome() {
  PEAL_NOTE=$1 awk '
    $0 == "## Outcome" { print; print ""; print ENVIRON["PEAL_NOTE"]; found = 1; exit }
    { print }
    END { if (!found) { print ""; print "## Outcome"; print ""; print ENVIRON["PEAL_NOTE"] } }'
}

# peal_slugify HINT -> HINT as a kebab-case slug of 2 to 5 words; status 2 and a message
# for fewer or more words.
peal_slugify() {
  local slug words
  slug=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9][^a-z0-9]*/-/g' -e 's/^-*//' -e 's/-*$//')
  words=$(printf '%s' "$slug" | awk -F- '{ print ($0 == "" ? 0 : NF) }')
  if [ "$words" -lt 2 ] || [ "$words" -gt 5 ]; then
    peal_err "slug '$1' makes $words words; a slug is 2 to 5 kebab-case words"
    return 2
  fi
  printf '%s\n' "$slug"
}
