#!/usr/bin/env bash
# Harness for tools/pins.sh, and for the pin of Peal in the workflow templates:
#
#   bash tools/pins.test.sh
#
# - the guard refuses each unpinned form and accepts a pinned file, under every awk here;
# - it exits 2 when it finds no files;
# - it names lines 37 and 42 of the template as it was before task 0069;
# - each template that fetches Peal (plugin/templates/*.yml) pins the tag `v` +
#   plugin.json's version (a release bumps both), and is listed in release.version-files
#   and release.commit-files; when that tag exists locally, its commit is the pinned SHA.
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

# Each template's Peal pin follows plugin.json's version: every plugin/templates/*.yml
# with a fetch of Peal.
version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$REPO/plugin/.claude-plugin/plugin.json")
pinned_tag() { sed -n 's/.* fetch .*https:\/\/.* [0-9a-f]\{40\} # \(v[0-9.]*\)$/\1/p' "$1"; }
pinned_sha() { sed -n 's/.* fetch .*https:\/\/.* \([0-9a-f]\{40\}\) # v[0-9.]*$/\1/p' "$1"; }
# tag_matches FILE NAME -> a message when the tag differs from plugin.json's version.
tag_matches() {
  local tag
  tag=$(pinned_tag "$1")
  [ "$tag" = "v$version" ] ||
    echo "the template pins Peal $tag but plugin.json is v$version: set the tag comment in $2 (peal ship bump) and the fetch line's SHA (peal ship pin v$version)"
}
tag_sha=$(git -C "$REPO" rev-parse -q --verify "v$version^{commit}" 2>/dev/null) ||
  echo "pins.test: tag v$version is not in this clone; the SHA checks are skipped"
templates=0
for template in "$REPO"/plugin/templates/*.yml; do
  grep -q 'fetch .*https://github.com/Maximilian-Walz/peal' "$template" || continue
  templates=$((templates + 1))
  name=plugin/templates/${template##*/}
  check "$name: the Peal tag is plugin.json's version" "" "$(tag_matches "$template" "$name")"
  [ -z "$tag_sha" ] || check "$name: the pinned SHA is v$version's commit" "$tag_sha" "$(pinned_sha "$template")"
  # Each template is set by the release: listed in release.version-files and commit-files.
  check "$name: in release.version-files and commit-files" 2 \
    "$(grep -c "^ *- \"$name: \\\\\"fetch -q --depth 1 https://github.com/Maximilian-Walz/peal" "$REPO/.peal/config.yml")"
done
check "the templates that fetch Peal: decisions.yml and merge-gate.yml at least" yes \
  "$([ "$templates" -ge 2 ] && echo yes || echo "no: $templates")"
template=$REPO/plugin/templates/decisions.yml
sed "s/# v$version\$/# v99.0.0/" "$template" >"$dir/bumped.yml"
check "a different tag is reported" \
  "the template pins Peal v99.0.0 but plugin.json is v$version: set the tag comment in plugin/templates/decisions.yml (peal ship bump) and the fetch line's SHA (peal ship pin v$version)" \
  "$(tag_matches "$dir/bumped.yml" plugin/templates/decisions.yml)"

finish
