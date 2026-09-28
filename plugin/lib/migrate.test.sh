#!/usr/bin/env bash
# Harness for lib/migrate.sh and lib/migrate-headers.awk, through `peal migrate headers`
# and `peal migrate milestones`, against throwaway repositories with synthetic, anonymised
# fixtures (nothing copied from the reference project this generalises):
#
#   bash plugin/lib/migrate.test.sh
#
# Both converters' shapes, what they cannot convert and leave untouched, and an
# end-to-end fixture repo converted and read back through `peal list`, `peal board` and
# `peal check`.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"

# project -> a new git-initialised directory with empty tasks/{backlog,doing,done} and
# docs/milestones; prints its path.
project() {
  local dir
  dir=$(scratch_dir)
  git -C "$dir" init -q
  git -C "$dir" checkout -q -b main
  mkdir -p "$dir/tasks/backlog" "$dir/tasks/doing" "$dir/tasks/done" "$dir/docs/milestones"
  printf '%s\n' "$dir"
}

pl() {
  local dir=$1
  shift
  (cd "$dir" && "$PEAL" "$@")
}

# --- migrate headers ---------------------------------------------------------------------

headers() {
  local dir out status

  # title/blank/header/blank/## Intent -> frontmatter/blank/title/rest, byte-exact.
  dir=$(project)
  printf '# 0001 — Plain task\n\nmilestone: 08\nplan: required\ndepends: 0297, 0269\nsize: M\nneeds: display, gpu\nmodel: opus\n\n## Intent\n\nWhy.\n' \
    >"$dir/tasks/backlog/0001-plain-task.md"
  pl "$dir" migrate headers --parked later,any --open process --none unassigned >/dev/null
  check "byte-exact" \
    "$(printf -- '---\nmilestone: m08\nplan: required\ndepends: [0297, 0269]\nsize: M\nneeds: [display, gpu]\nmodel: opus\n---\n\n# 0001 — Plain task\n## Intent\n\nWhy.')" \
    "$(cat "$dir/tasks/backlog/0001-plain-task.md")"

  # A trailing comment, including an indented comment-only continuation line.
  dir=$(project)
  printf '# 0002 — Trailing comments\n\nmilestone: 01\nneeds: a b c  # a trailing comment\n  # an indented continuation comment\nsize: S\n\n## Intent\n' \
    >"$dir/tasks/backlog/0002-trailing-comments.md"
  pl "$dir" migrate headers --parked later --open process --none unassigned >/dev/null
  check "trailing and continuation comments" \
    "$(printf -- '---\nmilestone: m01\nneeds: [a, b, c]\nsize: S\n---\n\n# 0002 — Trailing comments\n## Intent')" \
    "$(cat "$dir/tasks/backlog/0002-trailing-comments.md")"

  # depends: space- and comma-separated, a keyword mixed in; needs: comma-separated.
  dir=$(project)
  printf '# 0003 — Deps\n\ndepends: 0608 0609\n\n## Intent\n' >"$dir/tasks/backlog/0003-deps.md"
  printf '# 0004 — Deps human\n\ndepends: 0230 human\n\n## Intent\n' >"$dir/tasks/backlog/0004-deps-human.md"
  pl "$dir" migrate headers >/dev/null
  check "depends: space-separated" "depends: [0608, 0609]" "$(sed -n 2p "$dir/tasks/backlog/0003-deps.md")"
  check "depends: space-separated with a keyword" "depends: [0230, human]" "$(sed -n 2p "$dir/tasks/backlog/0004-deps-human.md")"

  # Empty depends: and size: are dropped.
  dir=$(project)
  printf '# 0005 — Empty fields\n\nmilestone: 01\ndepends:\nsize:\n\n## Intent\n' >"$dir/tasks/backlog/0005-empty-fields.md"
  pl "$dir" migrate headers >/dev/null
  check "empty fields dropped" "$(printf -- '---\nmilestone: m01\n---\n\n# 0005 — Empty fields\n## Intent')" \
    "$(cat "$dir/tasks/backlog/0005-empty-fields.md")"

  # milestone: a number, a --none pool (dropped), a --parked and an --open pool (kept as ids).
  dir=$(project)
  printf '# 0006 — None pool\n\nmilestone: unassigned\n\n## Intent\n' >"$dir/tasks/backlog/0006-none-pool.md"
  printf '# 0007 — Parked pool\n\nmilestone: later\n\n## Intent\n' >"$dir/tasks/backlog/0007-parked-pool.md"
  printf '# 0008 — Open pool\n\nmilestone: process\n\n## Intent\n' >"$dir/tasks/backlog/0008-open-pool.md"
  pl "$dir" migrate headers --parked later --open process --none unassigned >/dev/null
  check "none pool dropped" "$(printf -- '---\n---\n\n# 0006 — None pool\n## Intent')" "$(cat "$dir/tasks/backlog/0006-none-pool.md")"
  check "parked pool kept as id" "milestone: later" "$(sed -n 2p "$dir/tasks/backlog/0007-parked-pool.md")"
  check "open pool kept as id" "milestone: process" "$(sed -n 2p "$dir/tasks/backlog/0008-open-pool.md")"

  # A "key: value"-shaped line under a later section is body, untouched.
  dir=$(project)
  printf '# 0009 — Model in notes\n\nsize: S\n\n## Intent\n\nWhy.\n\n## Notes\n\nmodel: art/some/path.md\n' \
    >"$dir/tasks/backlog/0009-model-in-notes.md"
  pl "$dir" migrate headers >/dev/null
  check "key: value under a heading untouched" "model: art/some/path.md" "$(grep '^model:' "$dir/tasks/backlog/0009-model-in-notes.md")"
  check "only one frontmatter field" "size: S" "$(sed -n 2p "$dir/tasks/backlog/0009-model-in-notes.md")"

  # TEMPLATE.md and a non-numbered file are skipped silently.
  dir=$(project)
  printf 'not a task\n' >"$dir/tasks/backlog/TEMPLATE.md"
  printf 'not a task either\n' >"$dir/tasks/backlog/checklist.md"
  out=$(pl "$dir" migrate headers 2>&1)
  status=$?
  check "unnumbered files: exit 0, nothing reported" "0:" "$status:$out"
  check "TEMPLATE.md untouched" "not a task" "$(cat "$dir/tasks/backlog/TEMPLATE.md")"
  check "unnumbered file untouched" "not a task either" "$(cat "$dir/tasks/backlog/checklist.md")"

  # A prose line, an unknown pool, and an unknown key: the file is untouched, reported,
  # exit 1.
  dir=$(project)
  printf '# 0010 — Prose\n\nmilestone: 01\nplain text here\n\n## Intent\n' >"$dir/tasks/backlog/0010-prose.md"
  cp "$dir/tasks/backlog/0010-prose.md" "$dir/before-prose.md"
  check_fails "prose line: exit 1, reported" 1 "not a key: value line" pl "$dir" migrate headers
  check "prose line: file untouched" "$(cat "$dir/before-prose.md")" "$(cat "$dir/tasks/backlog/0010-prose.md")"

  dir=$(project)
  printf '# 0011 — Unknown pool\n\nmilestone: nowhere\n\n## Intent\n' >"$dir/tasks/backlog/0011-unknown-pool.md"
  cp "$dir/tasks/backlog/0011-unknown-pool.md" "$dir/before-pool.md"
  check_fails "unknown pool: exit 1, reported" 1 "milestone 'nowhere' is not a number" \
    pl "$dir" migrate headers --parked later --open process
  check "unknown pool: file untouched" "$(cat "$dir/before-pool.md")" "$(cat "$dir/tasks/backlog/0011-unknown-pool.md")"

  dir=$(project)
  printf '# 0012 — Unknown key\n\nowner: me\n\n## Intent\n' >"$dir/tasks/backlog/0012-unknown-key.md"
  cp "$dir/tasks/backlog/0012-unknown-key.md" "$dir/before-key.md"
  check_fails "unknown key: exit 1, reported" 1 "unknown key owner" pl "$dir" migrate headers
  check "unknown key: file untouched" "$(cat "$dir/before-key.md")" "$(cat "$dir/tasks/backlog/0012-unknown-key.md")"

  # Second run is a no-op: already-migrated files are left exactly as they are.
  dir=$(project)
  printf '# 0013 — Idempotent\n\nmilestone: 01\nsize: S\n\n## Intent\n' >"$dir/tasks/backlog/0013-idempotent.md"
  pl "$dir" migrate headers >/dev/null
  cp "$dir/tasks/backlog/0013-idempotent.md" "$dir/once.md"
  out=$(pl "$dir" migrate headers 2>&1)
  check "second run: exit 0, nothing reported" "0:" "$?:$out"
  check "second run: file unchanged" "$(cat "$dir/once.md")" "$(cat "$dir/tasks/backlog/0013-idempotent.md")"
}

# --- migrate milestones ------------------------------------------------------------------

msfile() {
  printf '# Milestone %s\n' "$2" >"$1/docs/milestones/milestone-$2.md"
}

milestones() {
  local dir out status

  # Three numbered docs: id and order from the file name's digits, the highest current.
  dir=$(project)
  msfile "$dir" 01
  msfile "$dir" 02
  msfile "$dir" 08
  pl "$dir" migrate milestones >/dev/null
  check "m01: id/state/order" "m01 done 1" "$(pl "$dir" frontmatter get docs/milestones/milestone-01.md id) $(pl "$dir" frontmatter get docs/milestones/milestone-01.md state) $(pl "$dir" frontmatter get docs/milestones/milestone-01.md order)"
  check "m02: id/state/order" "m02 done 2" "$(pl "$dir" frontmatter get docs/milestones/milestone-02.md id) $(pl "$dir" frontmatter get docs/milestones/milestone-02.md state) $(pl "$dir" frontmatter get docs/milestones/milestone-02.md order)"
  check "m08: id/state/order, highest is current" "m08 current 8" "$(pl "$dir" frontmatter get docs/milestones/milestone-08.md id) $(pl "$dir" frontmatter get docs/milestones/milestone-08.md state) $(pl "$dir" frontmatter get docs/milestones/milestone-08.md order)"

  # Pool files: created for --parked and --open pools without one, state and a one-line
  # "# Title" heading, no order or reason.
  dir=$(project)
  msfile "$dir" 01
  pl "$dir" migrate milestones --parked later,any --open process >/dev/null
  check "parked pool file: state" "parked" "$(pl "$dir" frontmatter get docs/milestones/later.md state)"
  check "parked pool file: heading" "# Later" "$(sed -n '$p' "$dir/docs/milestones/later.md")"
  check "second parked pool file" "parked" "$(pl "$dir" frontmatter get docs/milestones/any.md state)"
  check "open pool file: state" "open" "$(pl "$dir" frontmatter get docs/milestones/process.md state)"
  check "open pool file: heading" "# Process" "$(sed -n '$p' "$dir/docs/milestones/process.md")"
  pl "$dir" frontmatter get docs/milestones/later.md order >/dev/null 2>&1
  check "pool file: no order field" "1" "$?"

  # Existing frontmatter is left alone.
  dir=$(project)
  printf -- '---\nid: mX\nstate: open\norder: 99\n---\n\n# Custom\n' >"$dir/docs/milestones/milestone-05.md"
  cp "$dir/docs/milestones/milestone-05.md" "$dir/before.md"
  pl "$dir" migrate milestones >/dev/null
  check "existing frontmatter untouched" "$(cat "$dir/before.md")" "$(cat "$dir/docs/milestones/milestone-05.md")"

  # An existing current prevents a second: refused, nothing converted.
  dir=$(project)
  printf -- '---\nid: m01\nstate: current\norder: 1\n---\n\n# One\n' >"$dir/docs/milestones/milestone-01.md"
  msfile "$dir" 02
  cp "$dir/docs/milestones/milestone-02.md" "$dir/before2.md"
  check_fails "second current: refused" 2 "already current" pl "$dir" migrate milestones
  check "second current: numbered doc untouched" "$(cat "$dir/before2.md")" "$(cat "$dir/docs/milestones/milestone-02.md")"

  # A task's milestone with no matching file is reported.
  dir=$(project)
  msfile "$dir" 01
  printf -- '---\nmilestone: m09\n---\n\n# 0001 — Orphan milestone\n\n## Intent\n' >"$dir/tasks/backlog/0001-orphan-milestone.md"
  check_fails "orphan milestone: exit 1, reported" 1 "milestone m09 has no milestone file" pl "$dir" migrate milestones
}

# --- end-to-end ---------------------------------------------------------------------------

repo() {
  local dir
  dir=$(cd "$(scratch_dir)" && pwd -P)
  git init -q --bare "$dir/remote.git"
  git -C "$dir/remote.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$dir/remote.git" "$dir/work" 2>/dev/null
  git -C "$dir/work" checkout -q -b main 2>/dev/null
  mkdir -p "$dir/work/docs/milestones" "$dir/work/tasks/backlog" "$dir/work/tasks/doing" "$dir/work/tasks/done"
  printf '%s\n' "$dir/work"
}

raw() {
  local file=$1 id=$2 title=$3 done=0
  shift 3
  [[ "$file" != *tasks/done/* ]] || done=1
  {
    printf '# %s — %s\n\n' "$id" "$title"
    [ $# -eq 0 ] || printf '%s\n' "$@"
    printf '\n## Intent\n\nWhy.\n'
    [ "$done" -eq 0 ] || printf '\n## Outcome\n\nDone: it works.\n'
  } >"$file"
}

end_to_end() {
  local work out

  work=$(repo)
  msfile "$work" 01
  msfile "$work" 02

  # A milestone m02 task and its review task (depends: milestone).
  raw "$work/tasks/backlog/0001-plain-task.md" 0001 "Plain task" "milestone: 02" "size: S"
  raw "$work/tasks/backlog/0002-review-task.md" 0002 "Review task" "milestone: 02" "depends: milestone"

  # A split origin with two pieces.
  raw "$work/tasks/backlog/0003-split-origin.md" 0003 "Split origin" "milestone: 02"
  raw "$work/tasks/backlog/0004-piece-one.md" 0004 "Piece one" "part-of: 0003"
  raw "$work/tasks/backlog/0005-piece-two.md" 0005 "Piece two" "part-of: 0003"

  # depends: human, never resolves.
  raw "$work/tasks/backlog/0006-needs-human.md" 0006 "Needs human" "depends: human"

  # A depends not done (blocked) and one done (free).
  raw "$work/tasks/backlog/0007-blocked.md" 0007 "Blocked" "depends: 0001"
  raw "$work/tasks/done/0008-done-dep.md" 0008 "Done dep" "milestone: 01"
  raw "$work/tasks/backlog/0009-freed-by-done.md" 0009 "Freed by done" "depends: 0008"

  # A recurring task in a never-offered pool.
  raw "$work/tasks/backlog/0010-recurring.md" 0010 "Recurring" "milestone: any"

  # Done tasks in every pool.
  raw "$work/tasks/done/0011-done-current.md" 0011 "Done current" "milestone: 02"
  raw "$work/tasks/done/0012-done-unassigned.md" 0012 "Done unassigned" "milestone: unassigned"
  raw "$work/tasks/done/0013-done-later.md" 0013 "Done later" "milestone: later"
  raw "$work/tasks/done/0014-done-process.md" 0014 "Done process" "milestone: process"

  git -C "$work" add -A
  git -C "$work" -c user.name=peal -c user.email=peal@example.com commit -q -m root
  git -C "$work" push -q -u origin main 2>/dev/null

  out=$(pl "$work" migrate headers --parked later,any --open process --none unassigned 2>&1)
  check "end-to-end: headers, exit 0, nothing reported" "0:" "$?:$out"
  out=$(pl "$work" migrate milestones --parked later,any --open process 2>&1)
  check "end-to-end: milestones, exit 0, nothing reported" "0:" "$?:$out"

  git -C "$work" add -A
  git -C "$work" -c user.name=peal -c user.email=peal@example.com commit -q -m migrated
  git -C "$work" push -q origin main 2>/dev/null

  out=$(pl "$work" check 2>&1)
  check "end-to-end: peal check clean" "0:" "$?:$out"

  # A hand-derived id:state table.
  local want got
  want=$(cat <<'EOF'
0001 free
0002 blocked
0003 free
0004 free
0005 free
0006 blocked
0007 blocked
0008 done
0009 free
0010 free
0011 done
0012 done
0013 done
0014 done
EOF
)
  got=$(pl "$work" list --no-pr | awk '{print $1, $2}')
  check "end-to-end: peal list states" "$want" "$got"

  # peal board's states agree with peal list's.
  local board_states list_states
  list_states=$(pl "$work" list --no-pr | awk '{print $1":"$2}' | LC_ALL=C sort)
  board_states=$(pl "$work" board --no-pr | grep -v '^{"milestone"' | awk -F'"' '
    /"id":/ {
      id = ""; state = ""
      for (i = 1; i <= NF; i++) {
        if ($i == "id") id = $(i + 2)
        if ($i == "state") state = $(i + 2)
      }
      if (id != "") print id":"state
    }' | LC_ALL=C sort)
  check "end-to-end: board states agree with list" "$list_states" "$board_states"
}

cases() {
  headers
  milestones
  end_to_end
}

for_each_awk cases
finish
