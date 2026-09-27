#!/usr/bin/env bash
# Harness for lib/common.sh's git helpers (0075): peal_git_try (a fetch, push or
# ls-remote run quietly, its reason captured on failure instead of swallowed) and
# peal_status_porcelain (git status --porcelain with an untracked character device, what
# a sandbox's /dev/null mounted over a protected path looks like, left out):
#
#   bash plugin/lib/common.test.sh
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=common.sh
. "$PEAL_ROOT/lib/common.sh"

export GIT_AUTHOR_NAME=peal GIT_AUTHOR_EMAIL=peal@example.com
export GIT_COMMITTER_NAME=peal GIT_COMMITTER_EMAIL=peal@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# git_try_cases -> peal_git_try's own behaviour: quiet and PEAL_GIT_ERR empty on success,
# its status passed through, and the reason captured (not left on the real stderr) on
# failure.
git_try_cases() {
  # A command substitution runs peal_git_try in a subshell, where its PEAL_GIT_ERR
  # would not reach here: stdout goes to a file instead, so peal_git_try itself runs in
  # this shell and PEAL_GIT_ERR is the real one.
  local dir out status tmp
  dir=$(scratch_dir)
  git init -q "$dir/repo"
  tmp=$(scratch_dir)/out

  PEAL_GIT_ERR=leftover
  peal_git_try git -C "$dir/repo" rev-parse --show-toplevel >"$tmp" 2>&1
  status=$?
  out=$(cat "$tmp")
  check "git_try: success status" "0" "$status"
  check "git_try: success stdout kept" "$(cd "$dir/repo" && pwd -P)" "$out"
  check "git_try: success clears PEAL_GIT_ERR" "" "$PEAL_GIT_ERR"

  peal_git_try git -C "$dir/repo" fetch -q "$dir/does-not-exist.git" main >"$tmp" 2>&1
  status=$?
  out=$(cat "$tmp")
  check "git_try: failure status passed through, not swallowed to 0" "1" "$([ "$status" -ne 0 ] && echo 1 || echo 0)"
  check "git_try: failure keeps the real stderr off the caller's" "" "$out"
  check "git_try: failure fills PEAL_GIT_ERR" "1" "$([ -n "$PEAL_GIT_ERR" ] && echo 1 || echo 0)"
  check "git_try: failure's reason on one line" "1" "$([[ "$PEAL_GIT_ERR" != *$'\n'* ]] && echo 1 || echo 0)"
}

# git_try_ssh_cases -> the scenario the task fixes: a remote that cannot authenticate.
# GIT_SSH_COMMAND set as bin/peal sets it (a batch-mode ssh with a connect timeout, never
# a real one under test: a fake ssh on PATH stands in for "cannot authenticate") fails
# fast, its reason (what the fake ssh wrote to stderr) landing in PEAL_GIT_ERR, never
# hanging on a prompt no one is there to answer.
git_try_ssh_cases() {
  local dir fakebin out status start elapsed reason
  dir=$(scratch_dir)
  git init -q "$dir/repo"
  fakebin=$(scratch_dir)
  cat >"$fakebin/ssh" <<'EOF'
#!/bin/sh
echo "Permission denied (publickey)." >&2
exit 255
EOF
  chmod +x "$fakebin/ssh"

  start=$SECONDS
  out=$(
    PATH="$fakebin:$PATH" GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10" GIT_TERMINAL_PROMPT=0 \
      bash -c 'cd "$1" && . "$2/common.sh" && peal_git_try git fetch -q "$3" main; echo "STATUS:$?"; echo "ERR:$PEAL_GIT_ERR"' \
      _ "$dir/repo" "$PEAL_ROOT/lib" "ssh://git@example.invalid/acme/widgets.git" 2>&1
  )
  elapsed=$((SECONDS - start))
  status=$(printf '%s\n' "$out" | sed -n 's/^STATUS://p')
  reason=$(printf '%s\n' "$out" | sed -n 's/^ERR://p')
  check "git_try ssh: fails, not silently" "1" "$([ "$status" != 0 ] && echo 1 || echo 0)"
  check "git_try ssh: fast, never hangs on a prompt" "1" "$([ "$elapsed" -le 5 ] && echo 1 || echo 0)"
  check "git_try ssh: the reason captured" "1" "$(printf '%s' "$reason" | grep -c 'Permission denied')"
}

# status_porcelain_cases -> an untracked regular file counts, as git status always did;
# an untracked character device does not.
status_porcelain_cases() {
  local dir
  dir=$(scratch_dir)/repo
  git init -q "$dir"
  echo one >"$dir/tracked.txt"
  git -C "$dir" add tracked.txt
  git -C "$dir" commit -q -m first
  echo two >"$dir/tracked.txt"
  echo new >"$dir/untracked.txt"
  check "status: a real untracked file counts" "1" \
    "$(cd "$dir" && peal_status_porcelain | grep -c '?? untracked.txt')"
  check "status: a modified tracked file counts" "1" \
    "$(cd "$dir" && peal_status_porcelain | grep -c '^ M tracked.txt')"
  check "status: pathspecs pass through" "" \
    "$(cd "$dir" && peal_status_porcelain -- ":(exclude)untracked.txt" ":(exclude)tracked.txt")"

  if mknod "$dir/dev-null" c 1 3 2>/dev/null; then
    check "status: an untracked character device does not count" "" \
      "$(cd "$dir" && peal_status_porcelain | grep '?? dev-null')"
    check "status: everything else still shown alongside it" "1" \
      "$(cd "$dir" && peal_status_porcelain | grep -c '?? untracked.txt')"
    rm -f "$dir/dev-null"
  else
    echo "common.test.sh: mknod needs a privilege this machine will not give; the character-device case skipped" >&2
  fi
}

git_try_cases
git_try_ssh_cases
status_porcelain_cases
finish
