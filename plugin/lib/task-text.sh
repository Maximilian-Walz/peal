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

# peal_text_one_line TITLE -> TITLE as one line: control characters to spaces, runs of
# spaces to one, ends trimmed.
peal_text_one_line() {
  printf '%s' "$1" | tr '[:cntrl:]' ' ' | tr -s ' ' | sed -e 's/^ //' -e 's/ $//'
}

# peal_text_ensure_heading TITLE -> the text on stdin with a heading: when the first
# non-blank line after the frontmatter is not an H1 ("# ..."), "# NNNN — TITLE" (NNNN
# literal, for the caller to replace with the id) and a blank line go after the frontmatter
# and its blank lines, at the top when there is none; the rest unchanged. A text that has an H1
# passes as it is, whatever its title or number (peal_task_check judges those). TITLE
# is made one line: control characters to spaces, runs of spaces to one, ends trimmed.
peal_text_ensure_heading() {
  PEAL_HTITLE=$(peal_text_one_line "$1") awk '
    { l[NR] = $0 }
    END {
      s = 1
      if (l[1] == "---") {
        for (i = 2; i <= NR; i++) if (l[i] == "---") { s = i + 1; break }
        if (s == 1) s = NR + 1
      }
      for (j = s; j <= NR; j++) if (l[j] !~ /^[ \t\r]*$/) break
      ins = !(j <= NR && l[j] ~ /^# /)
      if (!ins) j = 1
      for (i = 1; i < j; i++) print l[i]
      if (ins) {
        if (s > 1 && j == s) print ""
        print "# NNNN — " ENVIRON["PEAL_HTITLE"]; print ""
        j = (j > NR ? NR + 1 : j)
      }
      for (i = j; i <= NR; i++) print l[i]
    }'
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

# peal_text_human_section -> the first of Plan and Outcome filled in the task text on
# stdin, status 0, or status 1 when neither is: the sections only the human's agreement
# (or the close) writes, which an outsider's filed text may not bring (docs/security.md,
# "Hostile prose is read, never run"): a filled Plan reads as agreed to peal work.
peal_text_human_section() {
  local text sec
  text=$(cat)
  for sec in Plan Outcome; do
    if printf '%s\n' "$text" | peal_text_section_filled "$sec"; then
      printf '%s\n' "$sec"
      return 0
    fi
  done
  return 1
}

# peal_text_outcome_placeholder -> status 0 if "## Outcome" still holds an HTML comment,
# the template's placeholder or a note left in it, outside any indented (quoted) block: an
# idea copied out of the queue by hand and indented into the Outcome carries its own
# "<!-- Written at close ... -->" placeholder, which is not this task's.
peal_text_outcome_placeholder() {
  peal_text_section Outcome | awk '/^[ \t]/ { next } /<!--/ { found = 1 } END { exit !found }'
}

# peal_text_add_note LINE -> the text with LINE as its own paragraph right under the first
# "## Notes" heading.
peal_text_add_note() {
  PEAL_NOTE=$1 awk '
    { print }
    $0 == "## Notes" && !done { print ""; print ENVIRON["PEAL_NOTE"]; done = 1 }'
}

# peal_text_add_note_or_section LINE -> the text with LINE under its "## Notes" heading
# (as peal_text_add_note); a text without that heading gets the section with LINE just
# before the "---" rule above "## Outcome", or at its end.
peal_text_add_note_or_section() {
  local text
  text=$(cat; printf x) || return 2
  text=${text%x}
  if printf '%s' "$text" | peal_text_has_section Notes; then
    printf '%s' "$text" | peal_text_add_note "$1"
    return
  fi
  printf '%s' "$text" | PEAL_NOTE=$1 awk '
    { l[NR] = $0 }
    END {
      p = NR + 1
      for (i = 1; i <= NR; i++) if (l[i] == "## Outcome") { p = i; break }
      k = p - 1
      while (k >= 1 && l[k] ~ /^[ \t\r]*$/) k--
      if (k >= 1 && l[k] == "---") p = k
      for (i = 1; i < p; i++) print l[i]
      if (p > 1 && l[p - 1] !~ /^[ \t\r]*$/) print ""
      print "## Notes"; print ""; print ENVIRON["PEAL_NOTE"]
      if (p <= NR) print ""
      for (i = p; i <= NR; i++) print l[i]
    }'
}

# peal_text_set_outcome LINE -> the text with everything from "## Outcome" on replaced by
# that heading and LINE; a text without the heading gets it at its end.
peal_text_set_outcome() {
  PEAL_NOTE=$1 awk '
    $0 == "## Outcome" { print; print ""; print ENVIRON["PEAL_NOTE"]; found = 1; exit }
    { print }
    END { if (!found) { print ""; print "## Outcome"; print ""; print ENVIRON["PEAL_NOTE"] } }'
}

# _peal_slug_normalise HINT -> HINT lower-cased, every run of anything but a-z0-9
# collapsed to one hyphen, no leading or trailing hyphen; not a slug on its own (nothing
# checks its word count). Shared by peal_slugify and peal_create_filed (backlog.sh),
# which truncates to the first five words instead of refusing a longer one.
_peal_slug_normalise() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9][^a-z0-9]*/-/g' -e 's/^-*//' -e 's/-*$//'
}

# peal_slugify HINT -> HINT as a kebab-case slug of 2 to 5 words; status 2 and a message
# for fewer or more words.
peal_slugify() {
  local slug words
  slug=$(_peal_slug_normalise "$1")
  words=$(printf '%s' "$slug" | awk -F- '{ print ($0 == "" ? 0 : NF) }')
  if [ "$words" -lt 2 ] || [ "$words" -gt 5 ]; then
    peal_err "slug '$1' makes $words words; a slug is 2 to 5 kebab-case words"
    return 2
  fi
  printf '%s\n' "$slug"
}
