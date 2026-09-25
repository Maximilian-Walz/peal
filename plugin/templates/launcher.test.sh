#!/usr/bin/env bash
# Harness for how templates/launcher (the .peal/peal a project commits) and
# templates/githook (the git hooks' stub) find Peal, one table run against both:
#
#   bash plugin/templates/launcher.test.sh
#
# Both look at the root recorded in the git directory, then the newest Peal in Claude
# Code's plugin cache, and take a root only once it is verified: a Peal with a plugin.json,
# outside this repository (its worktrees, its git directory), in the plugin cache, and
# listed by installed_plugins.json when that is there. A root refused is named on stderr.
# $PEAL_ROOT comes first; the launcher takes it as it is, the stub verifies it too.
set -uo pipefail
# shellcheck source=../lib/test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/test-lib.sh"
# shellcheck source=../lib/task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

LAUNCHER="$PEAL_ROOT/templates/launcher"
STUB="$PEAL_ROOT/templates/githook"

# The block that verifies a root is the same text in both.
block() { sed -n '/^# --- Finding Peal/,/^# --- end of finding Peal ---$/p' "$1"; }
check "the finding block: present" "yes" "$([ "$(block "$LAUNCHER" | wc -l)" -gt 50 ] && echo yes)"
check "the finding block: the same in launcher and stub" "$(block "$LAUNCHER")" "$(block "$STUB")"

# fake DIR NAME [VERSION [PLUGIN]] -> a stand-in Peal at DIR that prints NAME and its
# arguments, its plugin.json naming PLUGIN (peal) at VERSION (0.1.0); VERSION "-" for no
# plugin.json.
fake() {
  mkdir -p "$1/bin" "$1/.claude-plugin"
  printf '#!/bin/sh\necho "%s $*"\n' "$2" >"$1/bin/peal"
  chmod +x "$1/bin/peal"
  if [ "${3:-0.1.0}" = - ]; then
    rm -f "$1/.claude-plugin/plugin.json"
  else
    printf '{\n  "name": "%s",\n  "version": "%s",\n  "author": {"name": "someone"}\n}\n' \
      "${4:-peal}" "${3:-0.1.0}" >"$1/.claude-plugin/plugin.json"
  fi
}

# installed PATH VERSION... -> installed_plugins.json listing each PATH at its VERSION
# under peal@peal; none: the file removed.
installed() {
  local first=1
  if [ $# -eq 0 ]; then
    rm -f "$home/plugins/installed_plugins.json"
    return
  fi
  {
    printf '{\n  "version": 2,\n  "plugins": {\n    "other@peal": [{"installPath": "%s", "version": "%s"}],\n    "peal@peal": [\n' "$1" "$2"
    while [ $# -ge 2 ]; do
      [ $first = 1 ] || printf ',\n'
      printf '      {\n        "scope": "user",\n        "installPath": "%s",\n        "version": "%s",\n        "nested": {"version": "x"}\n      }' "$1" "$2"
      first=0
      shift 2
    done
    printf '\n    ]\n  }\n}\n'
  } >"$home/plugins/installed_plugins.json"
}

project=$(cd "$(scratch_dir)" && pwd -P)
home=$(cd "$(scratch_dir)" && pwd -P)
stubs=$(scratch_dir)
git -C "$project" init -q
git -C "$project" -c user.name=t -c user.email=t@t commit -q --allow-empty -m root
mkdir -p "$project/.peal" "$home/plugins"
cp "$LAUNCHER" "$project/.peal/peal"
cp "$STUB" "$stubs/commit-msg"
chmod +x "$stubs/commit-msg"
git -C "$project" worktree add -q "$project-wt" 2>/dev/null
scratch+=("$project-wt")
mkdir -p "$project-wt/.peal"
cp "$LAUNCHER" "$project-wt/.peal/peal"
cache="$home/plugins/cache"

inp() { (cd "$project" && env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$@"); }
launch() { inp .peal/peal "$@"; }
stub() { (cd "$project" && env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$stubs/commit-msg" "$@"); }

# both NAME PEAL [STDERR] -> the launcher and the stub both run the fake PEAL ("none": both
# refuse, the launcher with 127, the stub with 1), and both say STDERR (a glob) on stderr.
both() {
  local name=$1 want=$2 pattern=${3-} out err status
  err=$(launch x 2>&1 >/dev/null)
  out=$(launch x 2>/dev/null)
  status=$?
  if [ "$want" = none ]; then
    check "$name: the launcher refuses" "127" "$status"
  else
    check "$name: the launcher" "$want x" "$out"
  fi
  [ -z "$pattern" ] || check "$name: the launcher says so" "yes" "$([[ "$err" == *$pattern* ]] && echo yes || echo "no: $err")"
  err=$(stub x 2>&1 >/dev/null)
  out=$(stub x 2>/dev/null)
  status=$?
  if [ "$want" = none ]; then
    check "$name: the stub refuses" "1" "$status"
    check "$name: the stub says why" "yes" "$([[ "$err" == *"no installed Peal plugin is found"* ]] && echo yes || echo "no: $err")"
  else
    check "$name: the stub" "$want githook commit-msg x" "$out"
  fi
  [ -z "$pattern" ] || check "$name: the stub says so" "yes" "$([[ "$err" == *$pattern* ]] && echo yes || echo "no: $err")"
}

check_fails "nothing installed: an install hint" 127 \
  "claude plugin marketplace add Maximilian-Walz/peal*claude plugin install peal@peal" \
  launch --version
both "nothing installed" none

# The cache: any marketplace's peal, verified, the newest by time.
fake "$cache/peal/peal/0.1.0" old
fake "$cache/other-market/peal/abc123" newer
fake "$cache/peal/unrelated/9.9.9" unrelated
touch -t 202601010000 "$cache/peal/peal/0.1.0"
touch -t 202602010000 "$cache/other-market/peal/abc123"
touch -t 202603010000 "$cache/peal/unrelated/9.9.9"
check "cache: the newest Peal, arguments passed" "newer --version a b" "$(launch --version 'a b')"
both "cache: the newest, any marketplace" newer
touch -t 202604010000 "$cache/peal/peal/0.1.0"
both "cache: the newest by time, not by name" old

fake "$cache/evil/peal/9.9.9" evil 9.9.9 other-plugin
touch -t 202605010000 "$cache/evil/peal/9.9.9"
both "cache: an entry naming another plugin" old "skipped the Peal at $cache/evil/peal/9.9.9/ (cache): its .claude-plugin/plugin.json does not name peal"
fake "$cache/evil/peal/9.9.9" evil -
both "cache: an entry without plugin.json" old "skipped the Peal at $cache/evil/peal/9.9.9/ (cache): its .claude-plugin/plugin.json"
rm -rf "$cache/evil"

# An entry that is a link into the repository is the repository's.
fake "$project/plugin" planted
ln -s "$project/plugin" "$cache/peal/linked"
mkdir -p "$cache/linked/peal"
ln -s "$project/plugin" "$cache/linked/peal/9.9.9"
touch -h -t 202605010000 "$cache/linked/peal/9.9.9" 2>/dev/null
both "cache: a link into the work tree" old "skipped the Peal at $cache/linked/peal/9.9.9/ (cache): it lies inside this repository ($project)"
rm -rf "$cache/linked" "$cache/peal/linked"

# The recorded root, verified, before the cache.
touch -t 202601010000 "$cache/peal/peal/0.1.0"
printf '%s\n' "$cache/peal/peal/0.1.0" >"$project/.git/peal-root"
both "recorded root before the cache" old
check "recorded root, from a worktree" "old x" \
  "$(cd / && env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$project-wt/.peal/peal" x 2>/dev/null)"

printf '%s\n' "$project/plugin" >"$project/.git/peal-root"
both "recorded root in the work tree" newer "skipped the Peal at $project/plugin (recorded): it lies inside this repository ($project)"
fake "$project-wt/plugin" planted
printf '%s\n' "$project-wt/plugin" >"$project/.git/peal-root"
both "recorded root in a linked worktree" newer "skipped the Peal at $project-wt/plugin (recorded): it lies inside this repository ($project-wt)"
fake "$project/.git/planted" planted
printf '%s\n' "$project/.git/planted" >"$project/.git/peal-root"
both "recorded root in the git directory" newer "skipped the Peal at $project/.git/planted (recorded): it lies inside this repository"
fake "$project-outside" outside
scratch+=("$project-outside")
printf '%s\n' "$project-outside" >"$project/.git/peal-root"
both "recorded root outside the cache" newer "skipped the Peal at $project-outside (recorded): it is not in Claude Code's plugin cache"
printf 'plugin\n' >"$project/.git/peal-root"
both "recorded root, relative" newer "skipped the Peal at plugin (recorded): not an absolute path"
printf '%s\n' "$project-gone" >"$project/.git/peal-root"
both "stale recorded root: the cache" newer "skipped the Peal at $project-gone (recorded): it holds no executable bin/peal"

# installed_plugins.json, when there, names the paths and versions to take.
printf '%s\n' "$cache/peal/peal/0.1.0" >"$project/.git/peal-root"
installed "$cache/peal/peal/0.1.0" 0.1.0
both "installed: the recorded root it lists" old
installed "$cache/other-market/peal/abc123" 0.1.0
both "installed: a recorded root it does not list" newer "skipped the Peal at $cache/peal/peal/0.1.0 (recorded): installed_plugins.json lists no peal 0.1.0 there"
installed "$cache/peal/peal/0.1.0" 0.2.0 "$cache/other-market/peal/abc123" 0.1.0
both "installed: listed at another version" newer "skipped the Peal at $cache/peal/peal/0.1.0 (recorded): installed_plugins.json lists no peal 0.1.0 there"
installed "$cache/peal/peal/0.1.0" 0.2.0
both "installed: nothing it lists" none "skipped the Peal at $cache/other-market/peal/abc123/ (cache)"
installed

# $PEAL_ROOT: the launcher takes it as it is; the stub verifies it, the cache aside.
check "PEAL_ROOT before everything" "outside x" "$(inp env PEAL_ROOT="$project-outside" .peal/peal x)"
check "PEAL_ROOT in the repository: the launcher takes it" "planted x" \
  "$(inp env PEAL_ROOT="$project/plugin" .peal/peal x)"
check_fails "PEAL_ROOT without Peal is an error" 127 "holds no bin/peal" \
  inp env PEAL_ROOT="$project-gone" .peal/peal x
check "PEAL_ROOT outside the repository: the stub takes it" "outside githook commit-msg x" \
  "$(inp env PEAL_ROOT="$project-outside" "$stubs/commit-msg" x)"
check "PEAL_ROOT in the repository: the stub goes on" "old githook commit-msg x" \
  "$(inp env PEAL_ROOT="$project/plugin" "$stubs/commit-msg" x 2>/dev/null)"
check_fails "PEAL_ROOT in the repository: the stub says so" 0 \
  "skipped the Peal at $project/plugin (PEAL_ROOT): it lies inside this repository" \
  inp env PEAL_ROOT="$project/plugin" "$stubs/commit-msg" x

# End to end: a real copy of the plugin in the cache, recorded by its own hook, run by
# the launcher.
version=$("$PEAL" --version)
real="$cache/peal/peal/$version-real"
mkdir -p "$real"
cp -R "$PEAL_ROOT/." "$real/"
installed "$real" "$version"
rm -f "$project/.git/peal-root"
(cd "$project" && env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$real/bin/peal" hook session-start </dev/null >/dev/null 2>&1)
check "end to end: the hook recorded the cached root" "$real" "$(cat "$project/.git/peal-root")"
check "end to end: hook, then launcher" "$version" "$(launch --version)"
cp -R "$PEAL_ROOT" "$project/vendored"
check_fails "end to end: a Peal in the repository says it records nothing" 0 \
  "not recording $project/vendored as Peal's root: it lies inside this repository" \
  at "$project" env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$project/vendored/bin/peal" hook session-start </dev/null
check "end to end: a Peal in the repository records nothing" "$real" "$(cat "$project/.git/peal-root")"

finish
