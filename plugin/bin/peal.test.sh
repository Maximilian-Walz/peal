#!/usr/bin/env bash
# Harness for bin/peal's dispatch and its SessionStart hook (lib/session.sh):
#
#   bash plugin/bin/peal.test.sh
set -uo pipefail
# shellcheck source=../lib/test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/test-lib.sh"

version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$PEAL_ROOT/.claude-plugin/plugin.json")
check "the manifest has a version" "1" "$([ -n "$version" ] && echo 1)"
check "--version" "$version" "$("$PEAL" --version)"
check "version" "$version" "$("$PEAL" version)"
check "--version from elsewhere" "$version" "$(cd / && "$PEAL" --version)"
check "help" "usage: peal <command> [args]" "$("$PEAL" help | head -n1)"
check_refused "no command" "usage: peal" "$PEAL"
check_refused "unknown command" "unknown command 'nope'" "$PEAL" nope
check_refused "frontmatter without a file" "usage: peal" "$PEAL" frontmatter get
check_refused "unknown hook" "usage: peal" "$PEAL" hook nope

# The SessionStart hook records the plugin root in the git directory shared by every
# worktree, only for a repository that uses Peal, and stays silent either way.
project=$(scratch_dir)
git -C "$project" init -q
git -C "$project" -c user.name=t -c user.email=t@t commit -q --allow-empty -m root
out=$(cd "$project" && "$PEAL" hook session-start </dev/null 2>&1)
check "hook: silent" "" "$out"
check "hook: nothing recorded without .peal/" "0" "$([ -e "$project/.git/peal-root" ] && echo 1 || echo 0)"

mkdir "$project/.peal"
(cd "$project" && "$PEAL" hook session-start </dev/null >/dev/null)
check "hook: recorded" "$PEAL_ROOT" "$(cat "$project/.git/peal-root")"

rm "$project/.git/peal-root"
git -C "$project" worktree add -q "$project-wt" 2>/dev/null
scratch+=("$project-wt")
mkdir -p "$project-wt/.peal"
out=$(cd / && CLAUDE_PROJECT_DIR="$project-wt" "$PEAL" hook session-start </dev/null 2>&1)
check "hook: from a worktree, into the common git directory" "$PEAL_ROOT" "$(cat "$project/.git/peal-root")"
check "hook: in a Peal worktree, the orientation" "Peal:" "$(printf '%s\n' "$out" | head -n 1)"

# fake_cached CONFIG VERSION -> a stand-in Peal in CONFIG's plugin cache at VERSION, listed
# by CONFIG's installed_plugins.json (when LIST is not set to no); prints its root.
fake_cached() {
  local root=$1/plugins/cache/m/peal/$2
  mkdir -p "$root/bin" "$root/.claude-plugin"
  printf '#!/bin/sh\n' >"$root/bin/peal"
  chmod +x "$root/bin/peal"
  printf '{\n  "name": "peal",\n  "version": "%s"\n}\n' "$2" >"$root/.claude-plugin/plugin.json"
  if [ "${LIST:-yes}" = yes ]; then
    printf '{"plugins": {"peal@m": [{"installPath": "%s", "version": "%s"}]}}\n' "$root" "$2" \
      >"$1/plugins/installed_plugins.json"
  fi
  printf '%s\n' "$root"
}

# The record never goes back to an older Peal: a verified record of a higher version than
# the running plugin stays; one that is unlisted, gone or invalid is overwritten.
cfg=$(cd "$(scratch_dir)" && pwd -P)
mkdir -p "$cfg/plugins"
rec() { (cd "$project" && CLAUDE_CONFIG_DIR="$cfg" "$PEAL" hook session-start </dev/null >/dev/null 2>&1); }
newer=$(fake_cached "$cfg" 99.0.0)
printf '%s\n' "$newer" >"$project/.git/peal-root"
rec
check "hook: a verified newer record stays" "$newer" "$(cat "$project/.git/peal-root")"
older=$(fake_cached "$cfg" 0.0.1)
printf '%s\n' "$older" >"$project/.git/peal-root"
rec
check "hook: a running plugin newer than the record overwrites it" "$PEAL_ROOT" "$(cat "$project/.git/peal-root")"
newer=$(LIST=no fake_cached "$cfg" 99.0.0)
printf '{"plugins": {"peal@m": [{"installPath": "/elsewhere", "version": "99.0.0"}]}}\n' >"$cfg/plugins/installed_plugins.json"
printf '%s\n' "$newer" >"$project/.git/peal-root"
rec
check "hook: an unlisted newer record is overwritten" "$PEAL_ROOT" "$(cat "$project/.git/peal-root")"
rm -f "$cfg/plugins/installed_plugins.json"
printf '%s\n' "$newer" >"$project/.git/peal-root"
rec
check "hook: with no installed_plugins.json, the cached newer record stays" "$newer" "$(cat "$project/.git/peal-root")"
printf '%s\n' "$cfg/plugins/cache/m/peal/gone" >"$project/.git/peal-root"
rec
check "hook: a gone newer record is overwritten" "$PEAL_ROOT" "$(cat "$project/.git/peal-root")"
printf '{\n  "name": "other",\n  "version": "99.0.0"\n}\n' >"$newer/.claude-plugin/plugin.json"
printf '%s\n' "$newer" >"$project/.git/peal-root"
rec
check "hook: an invalid newer record is overwritten" "$PEAL_ROOT" "$(cat "$project/.git/peal-root")"

outside=$(scratch_dir)
out=$(cd "$outside" && GIT_CEILING_DIRECTORIES=$outside "$PEAL" hook session-start </dev/null 2>&1)
check "hook: outside a repository, silent and fine" "0:" "$?:$out"

# The hook keeps gh's telemetry off for the session's own Bash commands, through
# CLAUDE_ENV_FILE: one literal line, appended once, never failing the hook.
envf=$(scratch_dir)/env
printf 'export KEEP=1\n' >"$envf"
(cd "$outside" && GIT_CEILING_DIRECTORIES=$outside CLAUDE_ENV_FILE="$envf" "$PEAL" hook session-start </dev/null >/dev/null 2>&1)
(cd "$outside" && GIT_CEILING_DIRECTORIES=$outside CLAUDE_ENV_FILE="$envf" "$PEAL" hook session-start </dev/null >/dev/null 2>&1)
# shellcheck disable=SC2016 # the literal line, as the hook writes it
check "env file: the line once, outside a repository" "1" "$(grep -cxF 'export GH_TELEMETRY="${GH_TELEMETRY:-0}"' "$envf")"
check "env file: what was there stays" "1" "$(grep -cxF 'export KEEP=1' "$envf")"
check "env file: unset gives 0" "0" "$(env -u GH_TELEMETRY bash -c ". '$envf'; printf %s \"\$GH_TELEMETRY\"")"
check "env file: empty gives 0" "0" "$(GH_TELEMETRY='' bash -c ". '$envf'; printf %s \"\$GH_TELEMETRY\"")"
check "env file: the user's value stays" "log" "$(GH_TELEMETRY=log bash -c ". '$envf'; printf %s \"\$GH_TELEMETRY\"")"
out=$(cd "$outside" && GIT_CEILING_DIRECTORIES=$outside env -u CLAUDE_ENV_FILE "$PEAL" hook session-start </dev/null 2>&1)
check "env file: none set, fine" "0:" "$?:$out"
out=$(cd "$outside" && GIT_CEILING_DIRECTORIES=$outside CLAUDE_ENV_FILE="$outside/no/such/dir/env" "$PEAL" hook session-start </dev/null 2>&1)
check "env file: unwritable, fine" "0:" "$?:$out"
check "env file: unwritable, nothing created" "0" "$([ -e "$outside/no" ] && echo 1 || echo 0)"

finish
