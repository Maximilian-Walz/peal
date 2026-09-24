# shellcheck shell=bash
# Fixtures for the harnesses of the task storage: a throwaway repository with a bare
# remote, task texts, and tasks put straight onto the remote's main branch. Sourced after
# test-lib.sh.

export GIT_AUTHOR_NAME=peal GIT_AUTHOR_EMAIL=peal@example.com
export GIT_COMMITTER_NAME=peal GIT_COMMITTER_EMAIL=peal@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# shellcheck disable=SC2034 # used by the harnesses
today=$(date -u +%Y-%m-%d)

# repo -> a new directory holding remote.git (bare) and work, a clone on main with a
# milestone m1 (current), m2 (open), m3 (parked) and m0 (done), pushed; prints the path
# of work.
repo() {
  local dir
  # Physical: git names worktrees by their real path (/private/var, not /var, on macOS).
  dir=$(cd "$(scratch_dir)" && pwd -P)
  git init -q --bare "$dir/remote.git"
  git -C "$dir/remote.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$dir/remote.git" "$dir/work" 2>/dev/null
  git -C "$dir/work" checkout -q -b main 2>/dev/null
  mkdir -p "$dir/work/docs/milestones" "$dir/work/tasks/backlog"
  milestone_file "$dir/work" m0 "done" 0
  milestone_file "$dir/work" m1 current 1
  milestone_file "$dir/work" m2 open 2
  milestone_file "$dir/work" m3 parked 3
  git -C "$dir/work" add -A
  git -C "$dir/work" commit -q -m root
  git -C "$dir/work" push -q -u origin main 2>/dev/null
  printf '%s\n' "$dir/work"
}

# milestone_file WORK ID STATE ORDER -> WORK/docs/milestones/ID.md.
milestone_file() {
  printf -- '---\nstate: %s\norder: %s\n---\n\n# Milestone %s\n' "$3" "$4" "$2" >"$1/docs/milestones/$2.md"
}

# text [FRONTMATTER-LINE...] -> a task text titled "Title of NNNN" with those lines as
# its frontmatter; TITLE, RAW and OUTCOME from the environment when set.
text() {
  printf -- '---\n'
  [ $# -eq 0 ] || printf '%s\n' "$@"
  printf -- '---\n\n# %s — %s\n\n## Intent\n\nWhy.\n\n## Raw\n\n%s\n\n## Notes\n\n---\n\n## Outcome\n\n%s\n' \
    "${ID:-NNNN}" "${TITLE:-Title of ${ID:-NNNN}}" "${RAW:-the human said so}" "${OUTCOME:-<!-- fill in at close -->}"
}

# put WORK DIR ID SLUG [FRONTMATTER-LINE...] -> the task committed on WORK's main as
# tasks/DIR/ID-SLUG.md and pushed.
put() {
  local work=$1 dir=$2 id=$3 slug=$4
  shift 4
  mkdir -p "$work/tasks/$dir"
  ID=$id text "$@" >"$work/tasks/$dir/$id-$slug.md"
  publish "$work"
}

# publish WORK -> everything in WORK committed on its main and pushed, on top of whatever
# Peal pushed there meanwhile.
publish() {
  git -C "$1" add -A
  git -C "$1" commit -q -m publish
  git -C "$1" pull -q --rebase origin main 2>/dev/null
  git -C "$1" push -q origin main 2>/dev/null
}

# at WORK CMD... -> CMD run in WORK.
at() {
  local work=$1
  shift
  (cd "$work" && "$@")
}

# on_main WORK PATH -> PATH's content on the remote's main branch.
on_main() {
  git -C "$1" fetch -q origin 2>/dev/null
  git -C "$1" show "origin/main:$2" 2>/dev/null
}
