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

# ssh_batch_mode_cases -> peal_ssh_batch_mode's own resolution of what git would already
# run: its own GIT_SSH_COMMAND kept and appended to; failing that, this repository's
# core.sshCommand, same treatment; failing that, GIT_SSH (a bare program path) quoted
# into a command and appended to; failing all three, plain ssh. Batch mode and a connect
# timeout are appended only when that program is ssh itself: a non-ssh GIT_SSH_COMMAND or
# GIT_SSH (plink, a wrapper script) is left exactly as it is.
ssh_batch_mode_cases() {
  local dir
  dir=$(scratch_dir)/repo
  git init -q "$dir"
  cd "$dir" || return 2

  unset GIT_SSH_COMMAND GIT_SSH
  peal_ssh_batch_mode
  check "ssh batch mode: nothing set" "ssh -o BatchMode=yes -o ConnectTimeout=10" "$GIT_SSH_COMMAND"

  GIT_SSH_COMMAND="ssh -F /my/config -o ProxyCommand=foo"
  unset GIT_SSH
  peal_ssh_batch_mode
  check "ssh batch mode: its own GIT_SSH_COMMAND kept, the options appended after" \
    "ssh -F /my/config -o ProxyCommand=foo -o BatchMode=yes -o ConnectTimeout=10" "$GIT_SSH_COMMAND"

  unset GIT_SSH_COMMAND GIT_SSH
  git config core.sshCommand "ssh -i /my/key"
  peal_ssh_batch_mode
  check "ssh batch mode: core.sshCommand kept, the options appended after" \
    "ssh -i /my/key -o BatchMode=yes -o ConnectTimeout=10" "$GIT_SSH_COMMAND"
  git config --unset core.sshCommand

  unset GIT_SSH_COMMAND GIT_SSH
  GIT_SSH_COMMAND="plink -batch"
  peal_ssh_batch_mode
  check "ssh batch mode: a non-ssh GIT_SSH_COMMAND left untouched" "plink -batch" "$GIT_SSH_COMMAND"

  unset GIT_SSH_COMMAND GIT_SSH
  GIT_SSH=/usr/bin/ssh
  peal_ssh_batch_mode
  check "ssh batch mode: GIT_SSH, a bare path, quoted and appended to" \
    "/usr/bin/ssh -o BatchMode=yes -o ConnectTimeout=10" "$GIT_SSH_COMMAND"

  unset GIT_SSH_COMMAND GIT_SSH
  GIT_SSH=/usr/bin/plink
  peal_ssh_batch_mode
  check "ssh batch mode: a non-ssh GIT_SSH left GIT_SSH_COMMAND unset" "" "${GIT_SSH_COMMAND-}"

  unset GIT_SSH_COMMAND GIT_SSH
  cd - >/dev/null || return 2
}

# fake_ssh_that_needs_batch_mode DIR -> DIR/ssh, an ssh standing in for one that cannot
# authenticate: it hangs (sleeps well past this harness's own timeout) unless it is run
# with -o BatchMode=yes, so a case that skips peal_ssh_batch_mode, or a fix that does not
# really append the option, does not merely look fast by accident; given BatchMode, it
# fails at once with a message.
fake_ssh_that_needs_batch_mode() {
  cat >"$1/ssh" <<'EOF'
#!/bin/sh
case " $* " in
  *" -o BatchMode=yes "*) ;;
  *) sleep 300 ;;
esac
echo "Permission denied (publickey)." >&2
exit 255
EOF
  chmod +x "$1/ssh"
}

# git_try_ssh_cases -> the scenario the task fixes: a remote that cannot authenticate,
# reached through the GIT_SSH_COMMAND a sandbox already set (no batch mode of its own,
# the way the task's own sandbox sets one with a ProxyCommand) rather than an unset one.
# peal_ssh_batch_mode must append batch mode to that existing command, not leave it
# alone or replace it, for this to fail fast instead of hanging on the fake ssh above.
git_try_ssh_cases() {
  local dir fakebin out start elapsed status reason cmd
  if ! command -v timeout >/dev/null 2>&1; then
    echo "common.test.sh: no timeout here to bound a hang; git_try_ssh_cases skipped" >&2
    return 0
  fi
  dir=$(scratch_dir)
  git init -q "$dir/repo"
  fakebin=$(scratch_dir)
  fake_ssh_that_needs_batch_mode "$fakebin"

  start=$SECONDS
  out=$(
    # shellcheck disable=SC2016 # the inner bash -c's own $1, $2, $3, $?, $PEAL_GIT_ERR and
    # $GIT_SSH_COMMAND (its own, once peal_ssh_batch_mode runs there), not this shell's
    PATH="$fakebin:$PATH" GIT_SSH_COMMAND="ssh -o ProxyCommand=true" GIT_TERMINAL_PROMPT=0 \
      timeout 5 bash -c 'cd "$1" && . "$2/common.sh" && peal_ssh_batch_mode && peal_git_try git fetch -q "$3" main; echo "STATUS:$?"; echo "ERR:$PEAL_GIT_ERR"; echo "CMD:$GIT_SSH_COMMAND"' \
      _ "$dir/repo" "$PEAL_ROOT/lib" "ssh://git@example.invalid/acme/widgets.git" 2>&1
  )
  elapsed=$((SECONDS - start))
  status=$(printf '%s\n' "$out" | sed -n 's/^STATUS://p')
  reason=$(printf '%s\n' "$out" | sed -n 's/^ERR://p')
  cmd=$(printf '%s\n' "$out" | sed -n 's/^CMD://p')
  check "git_try ssh: batch mode appended to the sandbox's own GIT_SSH_COMMAND" \
    "ssh -o ProxyCommand=true -o BatchMode=yes -o ConnectTimeout=10" "$cmd"
  check "git_try ssh: fails, not silently" "1" "$([ -n "$status" ] && [ "$status" != 0 ] && echo 1 || echo 0)"
  check "git_try ssh: fast, never hangs on the fake ssh above" "1" "$([ "$elapsed" -le 3 ] && echo 1 || echo 0)"
  check "git_try ssh: the reason captured" "1" "$(printf '%s' "$reason" | grep -c 'Permission denied')"
}

# status_porcelain_cases -> an untracked regular file counts, as git status always did;
# an untracked symlink to /dev/null, what a sandbox's device mount looks like to git and to
# [ -c ] alike (git lists only regular files, symlinks and directories as untracked, so a
# real mknod device never reaches this code path; the symlink exercises the same [ -c ]
# branch without needing the privilege mknod does), does not, from the repository's top or
# from a subdirectory, and with an explicit pathspec.
status_porcelain_cases() {
  local dir
  dir=$(scratch_dir)/repo
  git init -q "$dir"
  mkdir "$dir/sub"
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

  ln -s /dev/null "$dir/dev-null"
  check "status: raw git lists the link as untracked (the control)" "?? dev-null" \
    "$(cd "$dir" && git status --porcelain | grep dev-null)"
  check "status: an untracked symlink to a device does not count" "" \
    "$(cd "$dir" && peal_status_porcelain | grep '?? dev-null')"
  check "status: everything else still shown alongside it" "1" \
    "$(cd "$dir" && peal_status_porcelain | grep -c '?? untracked.txt')"
  check "status: filtered from a subdirectory too" "" \
    "$(cd "$dir/sub" && peal_status_porcelain | grep dev-null)"
  ln -s /dev/null "$dir/sub/dev-null"
  check "status: raw git lists a link inside a subdirectory too (--untracked-files=all)" "?? sub/dev-null" \
    "$(cd "$dir" && git status --porcelain --untracked-files=all | grep sub/dev-null)"
  check "status: filtered there too, with --untracked-files=all" "" \
    "$(cd "$dir" && peal_status_porcelain --untracked-files=all | grep dev-null)"
  check "status: peal_untracked_devices names both links, no real file" \
    "dev-null
sub/dev-null" "$(cd "$dir" && peal_untracked_devices | sort)"
  rm -f "$dir/dev-null" "$dir/sub/dev-null"
}

git_try_cases
ssh_batch_mode_cases
git_try_ssh_cases
status_porcelain_cases
finish
