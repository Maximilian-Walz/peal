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
  local work out sha body
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
}

for_each_awk cases
finish
