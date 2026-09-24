#!/usr/bin/env bash
# Harness for lib/frontmatter.sh, lib/yaml-parse.awk and lib/frontmatter-write.awk,
# through `peal frontmatter`:
#
#   bash plugin/lib/frontmatter.test.sh
#
# Every shape of the design's task example reads and writes back byte for byte; block
# lists and quoted values round-trip; what the subset does not cover is refused with the
# file, the line and the reason.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"

# The task example of docs/design.md, "Task files".
example() {
  cat <<'EOF'
---
milestone: m08
plan: required
size: M
depends: [0271, human]
part-of: 0190
needs: [display, gpu]
model: opus
---

# 0305 — Title

## Intent
## Scope
## Done when
## Raw
## Notes

---

## Outcome
EOF
}

# The example's body alone: what the frontmatter sits on.
body() {
  example | sed '1,/^---$/d' | sed '1d'
}

fm() { "$PEAL" frontmatter "$@"; }

cases() {
  local dir file
  dir=$(scratch_dir)
  file="$dir/0305-title.md"

  # Reading the example.
  example >"$file"
  check "example: keys" "$(printf '%s\n' milestone plan size depends part-of needs model)" "$(fm keys "$file")"
  check "example: scalar" "M" "$(fm get "$file" size)"
  check "example: flow list" "$(printf '0271\nhuman')" "$(fm get "$file" depends)"
  fm get "$file" absent >/dev/null
  check "example: absent key is status 1" "1" "$?"

  # Writing every field back unchanged leaves the file as it was.
  fm set "$file" milestone m08
  fm set "$file" plan required
  fm set "$file" size M
  fm set-list "$file" depends 0271 human
  fm set "$file" part-of 0190
  fm set-list "$file" needs display gpu
  fm set "$file" model opus
  check "example: unchanged writes" "$(example)" "$(cat "$file")"

  # Changing every field and changing it back restores the file byte for byte.
  fm set "$file" milestone m09
  fm set "$file" size L
  fm set-list "$file" depends 0100
  fm set-list "$file" needs
  fm set "$file" model sonnet
  check "example: changed" "L|0100||sonnet" \
    "$(fm get "$file" size)|$(fm get "$file" depends)|$(fm get "$file" needs)|$(fm get "$file" model)"
  fm set "$file" milestone m08
  fm set "$file" size M
  fm set-list "$file" depends 0271 human
  fm set-list "$file" needs display gpu
  fm set "$file" model opus
  check "example: changed and restored" "$(example)" "$(cat "$file")"

  # Writing the fields into a file without frontmatter builds the example exactly.
  body >"$file"
  fm set "$file" milestone m08
  fm set "$file" plan required
  fm set "$file" size M
  fm set-list "$file" depends 0271 human
  fm set "$file" part-of 0190
  fm set-list "$file" needs display gpu
  fm set "$file" model opus
  check "example: built from its body" "$(example)" "$(cat "$file")"

  # Unsetting removes only the field's line.
  fm unset "$file" part-of
  fm unset "$file" part-of
  check "unset" "$(example | grep -v '^part-of:')" "$(cat "$file")"

  # Block lists: read, kept in block style at their indentation, removed whole.
  printf -- '---\nsize: S\ndepends:\n  - 0271\n\n  - human\nneeds:\n- gpu\n---\nbody\n' >"$file"
  check "block: items" "$(printf '0271\nhuman')" "$(fm get "$file" depends)"
  check "block: unindented items" "gpu" "$(fm get "$file" needs)"
  cp "$file" "$dir/before"
  fm set-list "$file" depends 0271 human
  check "block: unchanged write" "$(cat "$dir/before")" "$(cat "$file")"
  fm set-list "$file" depends 0300 human 0301
  check "block: stays block" "$(printf -- '---\nsize: S\ndepends:\n  - 0300\n  - human\n  - 0301\nneeds:\n- gpu\n---\nbody')" "$(cat "$file")"
  fm set-list "$file" needs gpu display
  check "block: unindented stays unindented" "$(printf -- 'needs:\n- gpu\n- display')" "$(sed -n '/^needs:/,/^---/p' "$file" | sed '$d')"
  fm unset "$file" depends
  check "block: unset" "$(printf -- '---\nsize: S\nneeds:\n- gpu\n- display\n---\nbody')" "$(cat "$file")"
  fm set-list "$file" needs
  check "block: emptied" "needs: []" "$(grep '^needs' "$file")"

  # Values that need quoting read back as written.
  local value
  : >"$file"
  for value in 'a: b' "it's" '#x' '[x]' '{x}' ' lead' 'trail ' '- dash' '*star' 'a #b' '"q"' 'x:' '%p' 'ümlaut —'; do
    fm set "$file" v "$value"
    check "quoted scalar: $value" "$value" "$(fm get "$file" v)"
    fm set-list "$file" l "$value" 'x, y' ']'
    check "quoted item: $value" "$(printf '%s\nx, y\n]' "$value")" "$(fm get "$file" l)"
  done
  fm set "$file" v ""
  check "empty scalar" "v:" "$(grep '^v:' "$file")"
  check "empty scalar reads empty" "" "$(fm get "$file" v)"
  printf -- "---\na: 'it''s'\nb: \"say \\\\\"hi\\\\\" \\\\\\\\\"\nc: plain # comment\nd: [ 'x, y' , \"z\" ]\n---\n" >"$file"
  check "quoted: single" "it's" "$(fm get "$file" a)"
  check "quoted: double" "say \"hi\" \\" "$(fm get "$file" b)"
  check "comment dropped" "plain" "$(fm get "$file" c)"
  check "quoted flow items" "$(printf 'x, y\nz')" "$(fm get "$file" d)"

  # No frontmatter.
  printf '# 0001 — Title\n' >"$file"
  check "none: no keys" "" "$(fm keys "$file")"
  fm unset "$file" size
  check "none: unset is a no-op" "# 0001 — Title" "$(cat "$file")"

  # What the subset refuses, and where.
  refused() {
    printf -- "---\n%b\n---\n" "$2" >"$file"
    check_refused "refused: $1" "$file:$3: *$4" fm check "$file"
  }
  refused "nested map" 'a:\n  b: c' 3 "nested maps are not supported"
  refused "flow map" 'a: {b: c}' 2 "maps are not supported in frontmatter"
  refused "anchor" 'a: &x 1' 2 "anchors and aliases"
  refused "alias" 'a: *x' 2 "anchors and aliases"
  refused "tag" 'a: !!str 1' 2 "tags are not supported"
  refused "block scalar" 'a: |\n  text' 2 "block scalars"
  refused "folded scalar" 'a: >' 2 "block scalars"
  refused "list of maps" 'a:\n  - b: c' 3 "lists of maps"
  refused "flow map in list" 'a:\n  - {b: c}' 3 "lists of maps"
  refused "nested block list" 'a:\n  - - b' 3 "lists inside lists"
  refused "nested flow list" 'a: [[b]]' 2 "nested flow lists"
  refused "multi-line flow list" 'a: [b,\n  c]' 2 "must close on its line"
  refused "empty item" 'a: [b, , c]' 2 "empty item"
  refused "empty block item" 'a:\n  -' 3 "empty list items"
  refused "duplicate key" 'a: 1\na: 2' 3 "duplicate key a"
  refused "tab" 'a:\tb' 2 "tabs are not supported"
  refused "unclosed quote" "a: 'b" 2 "not closed"
  refused "escape" 'a: "\\n"' 2 "escape"
  refused "text after quote" "a: 'b' c" 2 "after a quoted value"
  refused "colon in plain" 'a: b: c' 2 "quote it"
  refused "stray item" '- a' 2 "belongs to no key"
  refused "not a key" 'just text' 2 "expected \"key: value\""
  refused "indented key" 'a: 1\n  b: 2' 3 "matches no enclosing key"
  printf -- '---\na: 1\n' >"$file"
  check_refused "refused: unclosed frontmatter" "$file:1: the frontmatter opened by --- is never closed" fm check "$file"

  # The writer refuses too, and leaves the file alone.
  printf -- '---\na: &x 1\n---\n' >"$file"
  check_refused "write: invalid file" "anchors and aliases" fm set "$file" b 1
  check "write: invalid file untouched" "$(printf -- '---\na: &x 1\n---')" "$(cat "$file")"
  printf -- '---\na: 1\n---\n' >"$file"
  check_refused "write: newline" "cannot hold a newline" fm set "$file" a "$(printf 'x\ny')"
  check_refused "write: bad key" "is not a frontmatter key" fm set "$file" "a b" 1
  check_refused "missing file" "no such file" fm keys "$dir/missing.md"
  check "write: no leftovers" "0305-title.md before" "$(cd "$dir" && echo *)"
}

for_each_awk cases
finish
