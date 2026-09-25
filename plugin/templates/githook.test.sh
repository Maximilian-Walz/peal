#!/usr/bin/env bash
# Harness for templates/githook in a hostile repository: a clone whose content, and whose
# recorded root and $PEAL_ROOT, try to make Peal's git hooks run something the repository
# ships, driven by real git (commit, amend, checkout, merge, rebase, push):
#
#   bash plugin/templates/githook.test.sh
#
# Claude Code's configuration is a scratch one holding a real copy of the plugin in its
# plugin cache, listed by installed_plugins.json. Every planted script writes a canary;
# none may appear, the gates must still run (with the installed Peal), each refused root
# must be named on stderr, and nothing may reach for the network.
set -uo pipefail
# shellcheck source=../lib/test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/test-lib.sh"
# shellcheck source=../lib/task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

version=$("$PEAL" --version)
canary=$(scratch_dir)
net=$(scratch_dir)
shims=$(scratch_dir)
home=$(cd "$(scratch_dir)" && pwd -P)

# plant FILE NAME -> an executable at FILE that leaves canary NAME behind.
plant() {
  mkdir -p "$(dirname "$1")"
  printf '#!/bin/sh\ntouch "%s/%s"\necho "%s ran" >&2\n' "$canary" "$2" "$2" >"$1"
  chmod +x "$1"
}

# plugin_json DIR NAME VERSION -> DIR/.claude-plugin/plugin.json.
plugin_json() {
  mkdir -p "$1/.claude-plugin"
  printf '{\n  "name": "%s",\n  "version": "%s"\n}\n' "$2" "$3" >"$1/.claude-plugin/plugin.json"
}

# The network: every tool a hook could reach it with logs its call and fails.
for tool in gh curl wget ssh scp rsync nc; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\nexit 1\n' "$tool" "$net" >"$shims/$tool"
  chmod +x "$shims/$tool"
done

# The installed Peal: a real copy in the plugin cache, listed by installed_plugins.json.
cache="$home/plugins/cache"
real="$cache/peal/peal/$version"
mkdir -p "$real"
cp -R "$PEAL_ROOT/." "$real/"
printf '{"version": 2, "plugins": {"peal@peal": [{"scope": "user", "installPath": "%s", "version": "%s"}]}}\n' \
  "$real" "$version" >"$home/plugins/installed_plugins.json"

# Cache entries that fail verification, newer than the installed one.
plant "$cache/evil/peal/9.9.9/bin/peal" cache-unlisted
plugin_json "$cache/evil/peal/9.9.9" peal 9.9.9
plant "$cache/other/peal/$version/bin/peal" cache-not-peal
plugin_json "$cache/other/peal/$version" not-peal "$version"
touch -t 202001010000 "$real"
touch -t 203001010000 "$cache/evil/peal/9.9.9" "$cache/other/peal/$version"

work=$(repo)
(cd "$work" && env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$real/bin/peal" hooks install >/dev/null)

# The repository's content: a Peal of its own, a launcher, a hooks directory, all planted.
plant "$work/plugin/bin/peal" tree-peal
plant "$work/plugin/lib/common.sh" tree-common
plugin_json "$work/plugin" peal "$version"
plant "$work/.peal/peal" tree-launcher
for name in commit-msg pre-push post-checkout post-rewrite; do
  plant "$work/.githooks/$name" "tree-hook-$name"
done
git -C "$work" checkout -q -b task/0001-hostile
git -C "$work" add -A
git -C "$work" commit -q --no-verify -m "feat: the planted content [0001]"
# The root recorded in the git directory points into the work tree.
printf '%s\n' "$work/plugin" >"$work/.git/peal-root"

# g ARGS... -> git ARGS in the clone as a hostile environment would run it: PEAL_ROOT in
# the work tree, the network shims first on PATH, git's own calls traced.
g() {
  (cd "$work" && PEAL_ROOT="$work/plugin" CLAUDE_CONFIG_DIR="$home" PATH="$shims:$PATH" \
    GIT_TRACE="$net/trace" git "$@")
}

refused_roots() {
  local name=$1 err=$2
  check "$name: the PEAL_ROOT refused, named" "yes" \
    "$([[ "$err" == *"skipped the Peal at $work/plugin (PEAL_ROOT): it lies inside this repository"* ]] && echo yes || echo "no: $err")"
  check "$name: the recorded root refused, named" "yes" \
    "$([[ "$err" == *"skipped the Peal at $work/plugin (recorded): it lies inside this repository"* ]] && echo yes || echo "no: $err")"
}

# A bad subject: the installed Peal's gate refuses it.
err=$(g commit -q --allow-empty -m "not a subject" 2>&1)
check "commit, bad subject: refused" "1" "$(g commit -q --allow-empty -m "not a subject" >/dev/null 2>&1; echo $?)"
check "commit, bad subject: by the installed gate" "yes" \
  "$([[ "$err" == *"the subject is not <type>(<area>): <what> [NNNN]"* ]] && echo yes || echo "no: $err")"
refused_roots "commit" "$err"

# A good one passes, and so do amend, checkout, merge and rebase.
err=$(g commit -q --allow-empty -m "feat: a commit [0001]" 2>&1)
check "commit: passed" "feat: a commit [0001]" "$(git -C "$work" log -1 --format=%s)"
err=$(g commit -q --amend --allow-empty -m "feat: amended [0001]" 2>&1)
check "amend: passed" "feat: amended [0001]" "$(git -C "$work" log -1 --format=%s)"
refused_roots "amend" "$err"
g checkout -q -b task/0001-side 2>/dev/null
g commit -q --allow-empty -m "feat: on the side [0001]" 2>/dev/null
g checkout -q task/0001-hostile 2>/dev/null
check "checkout: done" "task/0001-hostile" "$(git -C "$work" rev-parse --abbrev-ref HEAD)"
g merge -q --no-ff --no-edit task/0001-side 2>/dev/null
check "merge: done" "Merge branch 'task/0001-side' into task/0001-hostile" "$(git -C "$work" log -1 --format=%s)"
g rebase -q --onto HEAD~2 HEAD~1 2>/dev/null
check "rebase: done" "feat: on the side [0001]" "$(git -C "$work" log -1 --format=%s)"

# Push: a task branch passes, main is refused by the installed gate.
check "push a task branch: passed" "0" "$(g push -q origin task/0001-hostile >/dev/null 2>&1; echo $?)"
err=$(g push -q origin HEAD:main 2>&1)
check "push to main: refused by the installed gate" "yes" \
  "$([[ "$err" == *"pre-push: "* && "$err" != *"no installed Peal plugin"* ]] && echo yes || echo "no: $err")"
refused_roots "push" "$err"

check "no planted script ran" "" "$(ls "$canary")"
check "no network tool called" "" "$(cat "$net/calls" 2>/dev/null)"
check "no fetch, ls-remote or pull" "" \
  "$(grep -E 'built-in: git (fetch|ls-remote|pull)|git-remote-' "$net/trace" 2>/dev/null)"
check "the trace saw the hooks' git calls" "yes" \
  "$(grep -q 'built-in: git rev-parse --git-common-dir' "$net/trace" && echo yes)"

# The cache's newer, failing entries were named when the recorded root was gone.
rm "$work/.git/peal-root"
err=$(g commit -q --allow-empty -m "feat: from the cache [0001]" 2>&1)
check "cache: passed" "feat: from the cache [0001]" "$(git -C "$work" log -1 --format=%s)"
check "cache: an unlisted entry named" "yes" \
  "$([[ "$err" == *"skipped the Peal at $cache/evil/peal/9.9.9/ (cache): installed_plugins.json lists no peal 9.9.9 there"* ]] && echo yes || echo "no: $err")"
check "cache: an entry of another plugin named" "yes" \
  "$([[ "$err" == *"skipped the Peal at $cache/other/peal/$version/ (cache): its .claude-plugin/plugin.json does not name peal"* ]] && echo yes || echo "no: $err")"

# No root left: refused, with a message.
printf '%s\n' "$work/plugin" >"$work/.git/peal-root"
empty=$(scratch_dir)
check_fails "no root left: refused" 1 "no installed Peal plugin is found" \
  env CLAUDE_CONFIG_DIR="$empty" PEAL_ROOT="$work/plugin" git -C "$work" commit -q --allow-empty -m "feat: x [0001]"
check_fails "no root left: a push refused" 1 "no installed Peal plugin is found" \
  env CLAUDE_CONFIG_DIR="$empty" PEAL_ROOT="$work/plugin" git -C "$work" push -q origin HEAD:refs/heads/task/0001-new

check "still no planted script ran" "" "$(ls "$canary")"
finish
