#!/usr/bin/env bash
# Harness for tools/pins.sh, and for the pin of Peal in the decisions workflow template:
#
#   bash tools/pins.test.sh
#
# - the guard refuses each unpinned form and accepts a pinned file, under every awk here;
# - it exits 2 when it finds no files;
# - it names lines 37 and 42 of the template as it was before task 0069;
# - the template's Peal tag equals `v` + plugin.json's version (a release bumps both);
#   when that tag exists locally, its commit is the pinned SHA.
set -uo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../plugin/lib/test-lib.sh
. "$REPO/plugin/lib/test-lib.sh"

dir=$(scratch_dir)
SHA=3d3c42e5aac5ba805825da76410c181273ba90b1
PSHA=8927e4644010042329fed4ddb2f8084aa98ebf02
URL=https://github.com/Maximilian-Walz/peal

# fixture NAME LINE -> a workflow file holding LINE.
fixture() {
  printf 'jobs:\n  a:\n    steps:\n%s\n' "$2" >"$dir/$1.yml"
}
# refused NAME LINE -> pins.sh exits 1 and names line 4 of the file.
refused() {
  local out status
  fixture "$1" "$2"
  out=$(bash "$REPO/tools/pins.sh" "$dir/$1.yml" 2>&1)
  status=$?
  check "$1: exit 1" 1 "$status"
  check "$1: names line 4" "$dir/$1.yml:4:" "$(printf '%s' "$out" | cut -d' ' -f1)"
}
accepted() {
  local status
  fixture "$1" "$2"
  bash "$REPO/tools/pins.sh" "$dir/$1.yml" >/dev/null 2>&1
  status=$?
  check "$1: exit 0" 0 "$status"
}

cases() {
  accepted pinned "      - uses: actions/checkout@$SHA # v7.0.1"
  accepted pinned-path "      - uses: github/codeql-action/upload-sarif@$SHA # v4.38.1"
  accepted pinned-fetch "        run: git -C \"\$D\" fetch -q --depth 1 $URL $PSHA # v0.2.0"
  accepted comment-only "      # uses: actions/checkout@v4 and git clone are talked about here"
  refused tag "      - uses: actions/checkout@v4"
  refused short-sha "      - uses: actions/checkout@3d3c42e # v7.0.1"
  refused no-tag-comment "      - uses: actions/checkout@$SHA"
  refused local "      - uses: ./local-action"
  refused docker "      - uses: docker://alpine:3.20"
  refused clone "        run: git clone -q --depth 1 $URL /tmp/peal"
  refused fetch-branch "        run: git -C \"\$D\" fetch -q --depth 1 $URL main"
  refused fetch-no-tag "        run: git -C \"\$D\" fetch -q --depth 1 $URL $PSHA"
  refused fetch-short-tag "        run: git -C \"\$D\" fetch -q --depth 1 $URL $PSHA # v0.2"

  check "the repository is clean" "" "$(bash "$REPO/tools/pins.sh" 2>&1)"
}
for_each_awk cases

# no files: the tool copied to a tree without any workflow
mkdir -p "$dir/bare/tools"
cp "$REPO/tools/pins.sh" "$dir/bare/tools/pins.sh"
check_refused "no files: exit 2" "no files" bash "$dir/bare/tools/pins.sh"

# the template before task 0069, when this checkout has that history
before=e94a6f6
if git -C "$REPO" cat-file -e "$before:plugin/templates/decisions.yml" 2>/dev/null; then
  git -C "$REPO" show "$before:plugin/templates/decisions.yml" >"$dir/before.yml"
  out=$(bash "$REPO/tools/pins.sh" "$dir/before.yml" 2>&1)
  status=$?
  check "the old template: exit 1" 1 "$status"
  check "the old template: lines" "37 42" "$(printf '%s\n' "$out" | sed -E 's/^[^:]*:([0-9]+):.*/\1/' | paste -sd' ' -)"
else
  echo "pins.test: commit $before not in this clone; the old template case is skipped"
fi

# the template's Peal pin follows plugin.json's version
template=$REPO/plugin/templates/decisions.yml
version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$REPO/plugin/.claude-plugin/plugin.json")
pinned_tag() { sed -n 's/.* fetch .*https:\/\/.* [0-9a-f]\{40\} # \(v[0-9.]*\)$/\1/p' "$1"; }
pinned_sha() { sed -n 's/.* fetch .*https:\/\/.* \([0-9a-f]\{40\}\) # v[0-9.]*$/\1/p' "$1"; }
# tag_matches FILE -> a message when the tag differs from plugin.json's version.
tag_matches() {
  local tag
  tag=$(pinned_tag "$1")
  [ "$tag" = "v$version" ] ||
    echo "the template pins Peal $tag but plugin.json is v$version: set the fetch line's SHA (git rev-parse v$version^{commit}) and tag comment in plugin/templates/decisions.yml"
}
check "the template's Peal tag is plugin.json's version" "" "$(tag_matches "$template")"
sed "s/# v$version\$/# v0.3.0/" "$template" >"$dir/bumped.yml"
check "a different tag is reported" \
  "the template pins Peal v0.3.0 but plugin.json is v$version: set the fetch line's SHA (git rev-parse v$version^{commit}) and tag comment in plugin/templates/decisions.yml" \
  "$(tag_matches "$dir/bumped.yml")"
if tag_sha=$(git -C "$REPO" rev-parse -q --verify "v$version^{commit}" 2>/dev/null); then
  check "the pinned SHA is v$version's commit" "$tag_sha" "$(pinned_sha "$template")"
else
  echo "pins.test: tag v$version is not in this clone; the SHA check is skipped"
fi

finish
