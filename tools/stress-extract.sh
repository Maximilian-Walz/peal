#!/usr/bin/env bash
# TEMPORARY (task 0137): counts non-zero statuses of the old extract pipe and the new
# peal_extract_tree over a 2 MiB tasks tree. Reverted before review.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
PEAL_ROOT=$root/plugin
# shellcheck source=../plugin/lib/common.sh
. "$PEAL_ROOT/lib/common.sh"
work=$(mktemp -d)
git init -q "$work/r"
cd "$work/r" || exit 1
git config user.email a@b.c
git config user.name n
mkdir -p tasks/backlog
for i in 1 2 3 4 5; do
  head -c 3500 /dev/urandom | od -An -v -tx1 >"tasks/backlog/pad$i.md"
done
git add -A
git commit -q -m x
n=${STRESS_N:-500}
old=0 new=0
for ((i = 0; i < n; i++)); do
  d=$(mktemp -d "$work/o.XXXXXX")
  git archive HEAD -- tasks | tar -x -C "$d" 2>/dev/null || old=$((old + 1))
  d=$(mktemp -d "$work/n.XXXXXX")
  peal_extract_tree HEAD tasks "$d" 2>/dev/null || new=$((new + 1))
  rm -rf "$work"/o.* "$work"/n.*
  if [ $(((i + 1) % 50)) = 0 ]; then
    echo "stress progress $((i + 1))/$n: old-pipe $old non-zero, new-extract $new non-zero"
  fi
done
echo "stress old-pipe: $old/$n non-zero"
echo "stress new-extract: $new/$n non-zero"
