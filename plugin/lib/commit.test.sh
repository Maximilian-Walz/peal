#!/usr/bin/env bash
# Harness for `peal commit` (lib/commit.sh), in throwaway repositories with Peal's git
# hooks installed:
#
#   bash plugin/lib/commit.test.sh
#
# Staging (named paths, or everything), the body, the report, and each refusal: the main
# branch, a detached HEAD, no hooks installed, a new backlog task file, nothing staged, and
# the commit-msg gate's own.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }

cases() {
  local work out sha body mark
  work=$(repo)

  git -C "$work" checkout -q -b task/0001-some-task
  check_refused "no hooks installed" "Peal's git hooks are not installed here" peal commit "feat: x [0001]"
  git -C "$work" checkout -q main
  peal hooks install >/dev/null
  check_refused "on main" "commit: refused on main" peal commit "feat: x [0001]"
  git -C "$work" checkout -q --detach
  check_refused "detached" "refused on a detached HEAD" peal commit "feat: x [0001]"
  git -C "$work" checkout -q task/0001-some-task
  check_refused "no subject" "commit: \"<type>(<area>): <what>" peal commit
  check_refused "nothing staged" "nothing staged, nothing to commit" peal commit "feat: x [0001]"
  check_refused "--body without a text" "--body needs a text" peal commit "feat: x [0001]" --body
  check_refused "--body after paths" "--body goes right after the subject, once" peal commit "feat: x [0001]" a --body b
  check_refused "--body-file missing" "no readable file" peal commit "feat: x [0001]" --body-file /nonexistent

  # Named paths: only those.
  echo a >"$work/a"
  echo b >"$work/b"
  out=$(peal commit "feat: add a [0001]" a 2>&1)
  sha=$(git -C "$work" rev-parse --short HEAD)
  check "paths: the report" "0:committed $sha feat: add a [0001]

 a | 1 +
 1 file changed, 1 insertion(+)" "$?:$(printf '%s\n' "$out" | grep -v '^commit-msg:')"
  check "paths: b left alone" "?? b" "$(git -C "$work" status --porcelain)"

  # Everything, from a subdirectory, with a body.
  mkdir -p "$work/sub"
  echo c >"$work/sub/c"
  (cd "$work/sub" && "$PEAL" commit "feat: the rest [0001]" --body "Why: because." >/dev/null 2>&1)
  check "everything: committed" "b
sub/c" "$(git -C "$work" show --format= --name-only HEAD)"
  check "everything: the body" "feat: the rest [0001]

Why: because." "$(git -C "$work" log -1 --format=%B)"

  body=$(scratch_dir)/body
  printf 'From a file.\n' >"$body"
  echo d >"$work/d"
  peal commit "feat: d [0001]" --body-file "$body" d >/dev/null 2>&1
  check "--body-file" "From a file." "$(git -C "$work" log -1 --format=%b)"
  : >"$body"
  check_refused "--body-file empty" "is empty" peal commit "feat: d [0001]" --body-file "$body"

  # The gate's refusal is reported; nothing is committed.
  echo e >"$work/e"
  sha=$(git -C "$work" rev-parse HEAD)
  check_fails "the gate refuses" 1 "the commit was refused (above)" peal commit "no grammar" e
  check "the gate refuses: nothing committed" "$sha" "$(git -C "$work" rev-parse HEAD)"
  git -C "$work" reset -q

  # A new backlog task file is filed onto main, never committed on a branch.
  mkdir -p "$work/tasks/backlog"
  printf 'x\n' >"$work/tasks/backlog/0009-sneaky-task.md"
  check_refused "a new backlog file" "a new backlog task file is filed onto main" peal commit "feat: e [0001]"
  check "a new backlog file: unstaged again" "" "$(git -C "$work" diff --cached --name-only -- tasks)"
  check "a new backlog file: nothing committed" "$sha" "$(git -C "$work" rev-parse HEAD)"
  git -C "$work" reset -q
  rm -f "$work/e" "$work/tasks/backlog/0009-sneaky-task.md"

  # Named paths, from here down: a file staged elsewhere rides along no more (the 0057
  # regression).
  echo f >"$work/f"
  echo g >"$work/g"
  git -C "$work" add g
  peal commit "feat: f [0001]" f >/dev/null 2>&1
  check "named: only f committed" "f" "$(git -C "$work" show --format= --name-only HEAD)"
  check "named: g stays staged" "g" "$(git -C "$work" diff --cached --name-only)"

  # The gate judges only the named path: a checks.commit item on the other staged path
  # does not run.
  mkdir -p "$work/.peal"
  mark=$(scratch_dir)/mark
  printf 'checks:\n  commit:\n    - "g: echo ran >>%s"\n' "$mark" >"$work/.peal/config.yml"
  echo h >"$work/h"
  peal commit "feat: h [0001]" h >/dev/null 2>&1
  check "gate: the other path's check did not run" "" "$(cat "$mark" 2>/dev/null)"
  check "gate: h committed, g still staged" "g" "$(git -C "$work" diff --cached --name-only)"
  printf 'checks:\n  commit: []\n' >"$work/.peal/config.yml"

  # A named path with no change of its own (already committed, untouched since): refused,
  # HEAD unchanged, the other staged path untouched.
  sha=$(git -C "$work" rev-parse HEAD)
  check_refused "named path unchanged" "nothing staged, nothing to commit" peal commit "feat: a [0001]" a
  check "named path unchanged: HEAD unchanged" "$sha" "$(git -C "$work" rev-parse HEAD)"
  check "named path unchanged: g still staged" "g" "$(git -C "$work" diff --cached --name-only)"
  git -C "$work" reset -q
  rm -f "$work/g"

  # A new backlog file staged but not named: neither refused nor unstaged; named: refused
  # and unstaged, as without paths.
  printf 'x\n' >"$work/tasks/backlog/0010-sneaky.md"
  echo i >"$work/i"
  git -C "$work" add "$work/tasks/backlog/0010-sneaky.md" i
  peal commit "feat: i [0001]" i >/dev/null 2>&1
  check "backlog unnamed: i committed" "i" "$(git -C "$work" show --format= --name-only HEAD)"
  check "backlog unnamed: the backlog file stays staged" "tasks/backlog/0010-sneaky.md" "$(git -C "$work" diff --cached --name-only)"
  sha=$(git -C "$work" rev-parse HEAD)
  check_refused "backlog named" "a new backlog task file is filed onto main" peal commit "feat: j [0001]" tasks/backlog/0010-sneaky.md
  check "backlog named: unstaged" "" "$(git -C "$work" diff --cached --name-only -- tasks)"
  check "backlog named: nothing committed" "$sha" "$(git -C "$work" rev-parse HEAD)"
  rm -f "$work/tasks/backlog/0010-sneaky.md"

  # A deleted file as a named path commits the deletion.
  rm "$work/f"
  peal commit "feat: rm f [0001]" f >/dev/null 2>&1
  check "deletion: reported" "f" "$(git -C "$work" show --format= --name-only HEAD)"
  check "deletion: gone from the tree" "128" "$(git -C "$work" cat-file -e HEAD:f 2>/dev/null; echo $?)"

  # A path named from a subdirectory resolves from there; an absolute path works too.
  mkdir -p "$work/sub2"
  echo k >"$work/sub2/k"
  (cd "$work/sub2" && "$PEAL" commit "feat: k [0001]" k >/dev/null 2>&1)
  check "subdirectory: committed" "sub2/k" "$(git -C "$work" show --format= --name-only HEAD)"

  echo l >"$work/l"
  peal commit "feat: l [0001]" "$work/l" >/dev/null 2>&1
  check "absolute path: committed" "l" "$(git -C "$work" show --format= --name-only HEAD)"
}

for_each_awk cases
finish
