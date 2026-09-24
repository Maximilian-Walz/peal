#!/usr/bin/env bash
# Harness for the plugin as installed: adds this repository as a marketplace to a
# throwaway Claude Code configuration, installs peal into a scratch project the way a
# project does (project scope), and runs `peal --version` through the installed plugin's
# root (what ${CLAUDE_PLUGIN_ROOT} names in a session) and through the launcher, after
# the installed SessionStart hook recorded that root; runs the installed git guard, and
# the git hooks finding the plugin in the cache.
#
#   bash tools/install.test.sh
#
# Needs the `claude` CLI; without it the harness skips, unless PEAL_REQUIRE_CLAUDE=1 (CI).
set -uo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../plugin/lib/test-lib.sh
. "$REPO/plugin/lib/test-lib.sh"

if ! command -v claude >/dev/null; then
  if [ "${PEAL_REQUIRE_CLAUDE:-}" = 1 ]; then
    echo "install.test.sh: the claude CLI is not installed" >&2
    exit 1
  fi
  echo "install.test.sh: skipped, the claude CLI is not installed"
  exit 0
fi

CLAUDE_CONFIG_DIR=$(scratch_dir)
export CLAUDE_CONFIG_DIR
project=$(scratch_dir)
git -C "$project" init -q
cd "$project" || exit 1

check "validate the marketplace" "0" "$(claude plugin validate --strict "$REPO" >/dev/null 2>&1; echo $?)"
check "validate the plugin" "0" "$(claude plugin validate --strict "$REPO/plugin" >/dev/null 2>&1; echo $?)"
check "add the marketplace" "0" "$(claude plugin marketplace add "$REPO" >/dev/null 2>&1; echo $?)"
check "install into the project" "0" "$(claude plugin install peal@peal --scope project >/dev/null 2>&1; echo $?)"

root=$(claude plugin list --json 2>/dev/null | sed -n 's/^ *"installPath": *"\([^"]*\)".*/\1/p' | head -n1)
version=$("$REPO/plugin/bin/peal" --version)
check "installed under the plugin cache" "$CLAUDE_CONFIG_DIR/plugins/cache/peal/peal/" "${root%/*}/"
check "peal --version through the plugin root" "$version" "$("$root/bin/peal" --version 2>&1)"

# The SessionStart hook, as Claude Code runs it: its command with the root substituted.
mkdir -p .peal
cp "$root/templates/launcher" .peal/peal
hooks=$(sed -n 's/^ *"command": *"\(.*\)" *$/\1/p' "$root/hooks/hooks.json" | sed 's/\\"/"/g')
# shellcheck disable=SC2016 # the commands as written, unexpanded
check "the hooks are peal's" '"${CLAUDE_PLUGIN_ROOT}/bin/peal" hook session-start
"${CLAUDE_PLUGIN_ROOT}/bin/peal" hook git-guard
"${CLAUDE_PLUGIN_ROOT}/bin/peal" hook post-tool-use
"${CLAUDE_PLUGIN_ROOT}/bin/peal" hook stop
"${CLAUDE_PLUGIN_ROOT}/bin/peal" hook session-end' "$hooks"
hook=$(printf '%s\n' "$hooks" | sed -n 1p)
CLAUDE_PLUGIN_ROOT=$root CLAUDE_PROJECT_DIR=$project bash -c "$hook" </dev/null >/dev/null
check "the hook recorded the root" "$root" "$(cat .git/peal-root)"
check "peal --version through the launcher" "$version" "$(env -u PEAL_ROOT .peal/peal --version 2>&1)"

# The git guard, as Claude Code runs it: a push to main refused, a harmless call passed.
guard=$(printf '%s\n' "$hooks" | sed -n 2p)
check "the git guard refuses a push to main" "2" \
  "$(printf '{"tool_input":{"command":"git push origin HEAD:main"},"cwd":"%s"}' "$project" \
    | CLAUDE_PLUGIN_ROOT=$root bash -c "$guard" 2>/dev/null; echo $?)"
check "the git guard passes git status" "0" \
  "$(printf '{"tool_input":{"command":"git status"},"cwd":"%s"}' "$project" \
    | CLAUDE_PLUGIN_ROOT=$root bash -c "$guard" 2>/dev/null; echo $?)"

rm .git/peal-root
check "peal --version through the launcher, from the cache" "$version" "$(env -u PEAL_ROOT .peal/peal --version 2>&1)"

# The git hooks find the plugin in the cache too, with nothing recorded.
"$root/bin/peal" hooks install >/dev/null
rm .git/peal-root
export GIT_AUTHOR_NAME=peal GIT_AUTHOR_EMAIL=peal@example.com
export GIT_COMMITTER_NAME=peal GIT_COMMITTER_EMAIL=peal@example.com
check "the commit-msg gate runs from the cache: refused" "1" \
  "$(git commit -q --allow-empty -m "no grammar" >/dev/null 2>&1; echo $?)"
check "the commit-msg gate runs from the cache: passed" "0" \
  "$(git commit -q --allow-empty -m "wip: fine" >/dev/null 2>&1; echo $?)"

finish
