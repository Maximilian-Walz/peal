# shellcheck shell=bash
# Shared by the *.test.sh harnesses: assertions, a tally, scratch directories, and a run
# of the cases under every awk installed here, since Peal's scripts must work with
# whichever one a machine has (mawk, gawk, BSD awk, busybox).

PEAL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC2034 # used by the harnesses
PEAL="$PEAL_ROOT/bin/peal"
pass=0
fail=0
failed=()
scratch=()

cleanup() {
  [ ${#scratch[@]} -eq 0 ] || rm -rf "${scratch[@]}"
}
trap cleanup EXIT

# scratch_dir -> a new temporary directory, removed when the harness exits.
scratch_dir() {
  local dir
  dir=$(mktemp -d)
  scratch+=("$dir")
  printf '%s\n' "$dir"
}

# check NAME EXPECTED ACTUAL
check() {
  if [ "$2" == "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    failed+=("$1${awk_name:+ [$awk_name]}")
    printf 'FAIL %s%s\n--- expected\n%s\n--- actual\n%s\n' "$1" "${awk_name:+ [$awk_name]}" "$2" "$3"
  fi
}

# check_fails NAME STATUS PATTERN CMD... -> CMD exits STATUS and its stderr matches PATTERN
# (a glob).
check_fails() {
  local name=$1 want=$2 pattern=$3 err status
  shift 3
  err=$("$@" 2>&1 >/dev/null)
  status=$?
  if [ "$status" -eq "$want" ] && [[ "$err" == *$pattern* ]]; then
    pass=$((pass + 1))
  else
    check "$name" "status $want, stderr matching: *$pattern*" "status $status, stderr: $err"
  fi
}

# check_refused NAME PATTERN CMD... -> CMD refuses: status 2, stderr matching PATTERN.
check_refused() {
  local name=$1 pattern=$2
  shift 2
  check_fails "$name" 2 "$pattern" "$@"
}

# for_each_awk FUNCTION -> runs FUNCTION once per awk installed, that awk first on PATH.
for_each_awk() {
  local candidate bin shims saved=$PATH ran=0
  shims=$(scratch_dir)
  for candidate in mawk gawk nawk original-awk "busybox awk"; do
    bin=${candidate%% *}
    command -v "$bin" >/dev/null || continue
    [ "$candidate" != "busybox awk" ] || busybox awk 'BEGIN {}' 2>/dev/null || continue
    mkdir -p "$shims/$bin"
    printf '#!/bin/sh\nexec %s "$@"\n' "$candidate" >"$shims/$bin/awk"
    chmod +x "$shims/$bin/awk"
    awk_name=$candidate
    PATH="$shims/$bin:$saved"
    "$1"
    PATH=$saved
    ran=1
  done
  awk_name=""
  if [ $ran -eq 0 ]; then
    awk_name="awk"
    "$1"
    awk_name=""
  fi
}

# finish -> the tally; status 1 if anything failed.
finish() {
  printf '%s: %d passed, %d failed\n' "$(basename "$0")" "$pass" "$fail"
  [ "$fail" -eq 0 ] || { printf '  %s\n' "${failed[@]}"; return 1; }
}
