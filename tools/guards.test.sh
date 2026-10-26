#!/usr/bin/env bash
# Harness for tools/guards.sh:
#
#   bash tools/guards.test.sh
#
# - the repository's own docs/security.md and .belfry.yml agree (exit 0);
# - a Guard path in neither list exits 1 and is named with its line; a path on a
#   continuation line is read; the *never alias and a glob cover a path; a path outside
#   plugin/, tools/ and .peal/ and a non-Guard mention are ignored;
# - no review_before_merge.paths, or no Guard lines, exits 2.
set -uo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../plugin/lib/test-lib.sh
. "$REPO/plugin/lib/test-lib.sh"

dir=$(scratch_dir)
G="$REPO/tools/guards.sh"

out=$(cd "$REPO" && bash "$G" 2>&1); status=$?
check "repository: exit 0" 0 "$status"
check "repository: silent" "" "$out"

cat >"$dir/ok.yml" <<'YML'
x:
  security-pr:
    paths: &never
      # a comment
      - plugin/hooks/**
      - "tools/a.sh"
    prompt: |
      text
policy:
  never_auto_merge: *never
  review_before_merge:
    review: security-pr
    paths:
      - plugin/lib/b.sh
  auto_merge:
    - name: x
      paths: ["tasks/**"]
YML
cat >"$dir/ok.md" <<'MD'
- Guard: `plugin/hooks/x`, `tools/a.sh`
  and `plugin/lib/b.sh`, `.github/workflows/ci.yml`.
MD
out=$(bash "$G" "$dir/ok.md" "$dir/ok.yml" 2>&1); status=$?
check "covered: exit 0" 0 "$status"
check "covered: silent" "" "$out"

cat >"$dir/bad.md" <<'MD'
Prose mentioning Guard: `plugin/lib/prose.sh` inline.
- Guard: `plugin/lib/b.sh`, `plugin/lib/missing.sh`
  (`tools/second.sh`) continues.
- Harness: `plugin/lib/harness.sh`
  - Guard: `.peal/nested.sh`
MD
out=$(bash "$G" "$dir/bad.md" "$dir/ok.yml" 2>&1); status=$?
check "missing: exit 1" 1 "$status"
check "missing: names each, with its line" \
  "guards: .peal/nested.sh ($dir/bad.md:5) is in neither never_auto_merge nor review_before_merge.paths
guards: plugin/lib/missing.sh ($dir/bad.md:2) is in neither never_auto_merge nor review_before_merge.paths
guards: tools/second.sh ($dir/bad.md:3) is in neither never_auto_merge nor review_before_merge.paths" "$out"

sed '/review_before_merge/,/b.sh/d' "$dir/ok.yml" >"$dir/norv.yml"
bash "$G" "$dir/ok.md" "$dir/norv.yml" >/dev/null 2>&1; status=$?
check "no review_before_merge.paths: exit 2" 2 "$status"
printf 'nothing here\n' >"$dir/noguard.md"
bash "$G" "$dir/noguard.md" "$dir/ok.yml" >/dev/null 2>&1; status=$?
check "no Guard lines: exit 2" 2 "$status"
bash "$G" "$dir/ok.md" "$dir/none.yml" >/dev/null 2>&1; status=$?
check "missing yml: exit 2" 2 "$status"
finish
