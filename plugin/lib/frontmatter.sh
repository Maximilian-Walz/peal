# shellcheck shell=bash
# Reading and writing a file's frontmatter, the `---` block at its top, in Peal's YAML
# subset: scalars, and lists of scalars in flow ([a, b]) or block (- a) style. Anything
# else is refused with the file, the line and what is not supported (lib/yaml-lib.awk).

# peal_fm_records FILE -> the parser's "key<TAB>kind<TAB>line<TAB>value" records for
# FILE's frontmatter; nothing if FILE has none; status 2 and a message if it leaves the
# subset.
peal_fm_records() {
  if [ ! -f "$1" ]; then
    peal_err "$1: no such file"
    return 2
  fi
  awk -v mode=frontmatter -v name="$1" -f "$PEAL_ROOT/lib/yaml-lib.awk" -f "$PEAL_ROOT/lib/yaml-parse.awk" "$1"
}

# peal_fm_check FILE -> status 0 if FILE's frontmatter is within the subset.
peal_fm_check() {
  peal_fm_records "$1" >/dev/null
}

# peal_fm_keys FILE -> the frontmatter's keys, in file order.
peal_fm_keys() {
  local records
  records=$(peal_fm_records "$1") || return 2
  printf '%s\n' "$records" | awk -F '\t' '$1 != "" && !seen[$1]++ { print $1 }'
}

# peal_fm_get FILE KEY -> KEY's value, or a list's items one per line (nothing for an
# empty value or list); status 1 if KEY is absent.
peal_fm_get() {
  local records
  records=$(peal_fm_records "$1") || return 2
  printf '%s\n' "$records" | awk -F '\t' -v key="$2" '
    $1 == key { found = 1; if ($2 == "s" && $4 == "") next; if ($2 == "s" || $2 == "i") print $4 }
    END { exit !found }'
}

# peal_fm_set FILE KEY VALUE -> sets the scalar KEY.
peal_fm_set() {
  _peal_fm_write "$1" "$2" scalar "$3"
}

# peal_fm_set_list FILE KEY [ITEM...] -> sets KEY to the list of ITEMs.
peal_fm_set_list() {
  local file=$1 key=$2
  shift 2
  _peal_fm_write "$file" "$key" list "$@"
}

# peal_fm_unset FILE KEY -> removes KEY; nothing happens if it is absent.
peal_fm_unset() {
  _peal_fm_write "$1" "$2" unset
}

# _peal_fm_write FILE KEY OP [VALUE...]: the writers' shared body. Leaves FILE untouched
# when it already holds the value, so a read and a write of the same value round-trip
# byte for byte whatever style the file used.
_peal_fm_write() {
  local file=$1 key=$2 op=$3 records current wanted value values="" tmp
  shift 3
  if ! [[ "$key" =~ ^[A-Za-z0-9_-]+$ ]]; then
    peal_err "'$key' is not a frontmatter key: use letters, digits, - and _"
    return 2
  fi
  for value in "$@"; do
    if [[ "$value" == *$'\n'* || "$value" == *$'\t'* ]]; then
      peal_err "$file: $key: a value cannot hold a newline or a tab"
      return 2
    fi
  done
  records=$(peal_fm_records "$file") || return 2

  current=$(printf '%s\n' "$records" | awk -F '\t' -v key="$key" '$1 == key { print $2 "\t" $4 }')
  case $op in
    scalar) wanted="s"$'\t'"$1" ;;
    list) if [ $# -eq 0 ]; then wanted="e"$'\t'; else wanted=$(printf 'i\t%s\n' "$@"); fi ;;
    unset) wanted="" ;;
  esac
  [ "$current" = "$wanted" ] && return 0

  if [ $# -gt 0 ]; then values=$(printf '%s\n' "$@"); fi
  tmp=$(mktemp "$file.XXXXXX") || return 2
  if ! PEAL_FM_OP=$op PEAL_FM_KEY=$key PEAL_FM_COUNT=$# PEAL_FM_VALUES=$values \
      awk -f "$PEAL_ROOT/lib/yaml-render.awk" -f "$PEAL_ROOT/lib/frontmatter-write.awk" \
      "$file" >"$tmp" || ! peal_fm_check "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    peal_err "$file: could not write $key"
    return 2
  fi
  chmod "$(stat -c %a "$file" 2>/dev/null || stat -f %Lp "$file")" "$tmp" 2>/dev/null
  mv "$tmp" "$file"
}
