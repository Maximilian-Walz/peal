#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq's $variables, not the shell's
# Harness for releases (lib/ship.sh), through the peal CLI, against throwaway
# repositories with task files and with issues, their GitHub lib/fake-gh:
#
#   bash plugin/lib/ship.test.sh
#
# The version proposal (first, patch, minor, major, nothing), the notes for both storages
# (sections, one line per task from its title and Outcome, links, retired and
# release-note: none tasks left out, feat and fix commits of no task), the tag (annotated,
# pushed; refused when it exists, here or on the remote, or is not above the last
# release), the version files set before the tag (release.version-files: JSON, TOML and
# YAML, directly and through a pull request, and their refusals), the changelog
# (release.changelog: created, each entry above the last, tag refused without it), the
# GitHub release created and updated, the wait for the tag's workflow runs
# and the release.report lines, and the fields breaking and release-note.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

if ! command -v jq >/dev/null; then
  echo "ship.test.sh: no jq here, which the fake gh needs; skipped" >&2
  [ -z "${PEAL_REQUIRE_JQ-}" ] || exit 1
  exit 0
fi

peal() { at "$work" "$PEAL" "$@"; }

# land ID SLUG SUBJECT [FRONTMATTER-LINE...] -> task ID done on the remote's main in one
# commit SUBJECT, as a squash merge of its pull request lands it; OUTCOME its Outcome.
land() {
  local id=$1 slug=$2 subject=$3
  shift 3
  mkdir -p "$work/tasks/done"
  ID=$id OUTCOME=${OUTCOME:-Built it. Then more.} text "$@" >"$work/tasks/done/$id-$slug.md"
  git -C "$work" add -A
  git -C "$work" commit -q -m "$subject"
  git -C "$work" push -q origin main 2>/dev/null
}

# commit SUBJECT -> an empty commit SUBJECT on the remote's main.
commit() {
  git -C "$work" commit -q --allow-empty -m "$1"
  git -C "$work" push -q origin main 2>/dev/null
}

# on_github -> work's remote named as acme/widgets on GitHub, a local rewrite leading
# git to the bare repository.
on_github() {
  local bare
  bare=$(git -C "$work" remote get-url origin)
  git -C "$work" remote set-url origin https://github.com/acme/widgets.git
  git -C "$work" config url."$bare".insteadOf https://github.com/acme/widgets.git
}

files() {
  local work out sha dir
  work=$(repo)
  fake_github "$work"
  on_github
  mkdir -p "$work/.peal"
  printf 'release:\n  report: ["digest: sha256:", "size:"]\n' >"$work/.peal/config.yml"
  git -C "$work" add -A && git -C "$work" commit -q -m config && git -C "$work" push -q origin main 2>/dev/null

  # The first release: every done task.
  OUTCOME=$'<!-- a note -->\n### Escalations\n\n- The board, filtered by milestone. Also sorted.' \
    land 0001 board-view "Board view [0001] (#1)"
  check "propose: the first" "LAST none
ITEM feature 0001 #1 Title of 0001
PROPOSE v0.1.0 first" "$(peal ship propose 2>&1)"
  check "notes: the first" "v0.1.0: the first release, 1 feature.

## Features

- Title of 0001: The board, filtered by milestone. ([0001](https://github.com/acme/widgets/blob/v0.1.0/tasks/done/0001-board-view.md), #1)" \
    "$(peal ship notes 0.1.0 2>&1)"
  check_refused "tag: no version" "'banana' is no version" peal ship tag banana
  check_refused "publish: no tag" "no tag v0.1.0" peal ship publish v0.1.0
  out=$(peal ship tag 0.1.0 2>&1)
  check "tag: made and pushed" "0:tagged v0.1.0 at $(git -C "$work" rev-parse --short origin/main) (origin/main), pushed: v0.1.0: the first release, 1 feature." "$?:$out"
  check "tag: annotated, on the remote" "tag|v0.1.0: the first release, 1 feature.|1" \
    "$(git -C "$work" cat-file -t v0.1.0)|$(git -C "$work" for-each-ref --format='%(contents:subject)' refs/tags/v0.1.0)|$(git -C "$work" ls-remote --tags origin refs/tags/v0.1.0 | wc -l | tr -d ' ')"
  check_refused "tag: exists" "v0.1.0 exists already" peal ship tag v0.1.0
  git -C "$work" tag -d v0.1.0 >/dev/null
  # A tag only the remote has is refused too: the tags are fetched first.
  check_refused "tag: exists on the remote" "v0.1.0 exists already" peal ship tag v0.1.0

  out=$(peal ship publish 0.1.0 2>&1)
  check "publish: created" "0:released v0.1.0: https://github.com/acme/widgets/releases/tag/v0.1.0" "$?:$out"
  check "publish: the notes" "v0.1.0|$(peal ship notes 0.1.0)" "$(gh_get '.[0] | .title + "|" + .notes' releases)"
  out=$(peal ship publish 0.1.0 2>&1)
  check "publish: updated" "0:updated the release v0.1.0: https://github.com/acme/widgets/releases/tag/v0.1.0" "$?:$out"
  check "publish: one release" "1" "$(gh_get 'length' releases)"
  echo "RELEASE create v0.1.0" >"$FAKE_GH/fail"
  gh_save releases '[]'
  check_refused "publish: gh fails" "gh release create failed" peal ship publish 0.1.0
  rm "$FAKE_GH/fail"

  # Fixes only: a patch. Retired tasks, release-note: none, chores and a task done
  # before the last release are left out; a fix commit of no task goes in.
  check "propose: nothing" "LAST v0.1.0
NOTHING since v0.1.0" "$(peal ship propose 2>&1)"
  OUTCOME="Fixed the crash." land 0002 crash-fix "fix: the crash on start [0002] (#2)"
  OUTCOME="Retired: no longer needed." land 0003 old-idea "docs(tasks): retire 0003 old-idea [0003]"
  land 0004 internal-chore "Internal chore [0004] (#3)" "release-note: none"
  commit "chore: tidy the scripts (#4)"
  commit "fix(docs): a typo in the readme (#5)"
  commit "docs(tasks): file 0009 later-thing [0009]"
  check "propose: a patch" "LAST v0.1.0
ITEM fix 0002 #2 Title of 0002
ITEM none 0004 #3 Title of 0004
ITEM fix - #5 a typo in the readme
PROPOSE v0.1.1 patch" "$(peal ship propose 2>&1)"

  # A feature: minor. A breaking task: major, and the sections in their order.
  OUTCOME="Added a filter." land 0005 filter-view "Filter view [0005] (#6)"
  check "propose: a minor" "PROPOSE v0.2.0 minor" "$(peal ship propose 2>&1 | tail -n 1)"
  OUTCOME="Renamed the config keys. Old ones fail." land 0006 rename-keys "Rename the keys [0006] (#7)" "breaking: true"
  commit "feat!: drop the old launcher (#8)"
  check "propose: a major" "PROPOSE v1.0.0 major" "$(peal ship propose 2>&1 | tail -n 1)"
  check "notes: sections" "v1.0.0: 2 breaking changes, 1 feature, 2 fixes since v0.1.0.

## Breaking

- Title of 0006: Renamed the config keys. ([0006](https://github.com/acme/widgets/blob/v1.0.0/tasks/done/0006-rename-keys.md), #7)
- drop the old launcher (#8)

## Features

- Title of 0005: Added a filter. ([0005](https://github.com/acme/widgets/blob/v1.0.0/tasks/done/0005-filter-view.md), #6)

## Fixes

- Title of 0002: Fixed the crash. ([0002](https://github.com/acme/widgets/blob/v1.0.0/tasks/done/0002-crash-fix.md), #2)
- a typo in the readme (#5)" "$(peal ship notes v1.0.0 2>&1)"
  check_refused "tag: not above the last" "v0.0.9 is not above the last release, v0.1.0" peal ship tag 0.0.9
  check_refused "tag: equal to the last" "v0.1.0 exists already" peal ship tag 0.1.0

  # Once tagged, the notes stay those of its range, and nothing is left to propose.
  peal ship tag 1.0.0 >/dev/null 2>&1
  commit "chore: after the release"
  check "notes: a tag's own range" "v1.0.0: 2 breaking changes, 1 feature, 2 fixes since v0.1.0." \
    "$(peal ship notes 1.0.0 2>&1 | head -n 1)"
  check "propose: nothing after" "LAST v1.0.0
NOTHING since v1.0.0" "$(peal ship propose 2>&1)"
  git -C "$work" tag v1.1.0-rc.1 origin/main && git -C "$work" push -q origin v1.1.0-rc.1 2>/dev/null
  check "propose: a pre-release is no release" "LAST v1.0.0" "$(peal ship propose 2>&1 | head -n 1)"

  # The wait: the tag's workflow runs, their verdict, the report from their logs.
  sha=$(git -C "$work" rev-parse 'v1.0.0^{commit}')
  gh_save runs '[{id: 1, head_sha: $s, head_branch: "v1.0.0", status: "in_progress", conclusion: null, name: "release", html_url: "https://github.com/acme/widgets/actions/runs/1"},
      {id: 2, head_sha: $s, head_branch: "main", status: "completed", conclusion: "failure", name: "ci", html_url: "u"}]' --arg s "$sha"
  out=$(PEAL_SHIP_WAIT_BUDGET=0 peal ship wait 1.0.0 2>&1)
  check "wait: running" "3:WAIT:running: release" "$?:$out"
  gh_save runs 'map(if .id == 1 then . + {status: "completed", conclusion: "success"} else . end)'
  gh_save jobs '[{id: 7, run_id: 1}, {id: 8, run_id: 2}]'
  mkdir -p "$FAKE_GH/logs"
  printf '2026-09-24T10:00:00.1234567Z pushing\r\n2026-09-24T10:00:01.1234567Z   digest: sha256:abc123 size: 1234\n' >"$FAKE_GH/logs/7"
  out=$(peal ship wait 1.0.0 2>&1)
  check "wait: ready, reported" "0:RUN release success https://github.com/acme/widgets/actions/runs/1
REPORT digest: sha256:abc123 size: 1234
REPORT digest: sha256:abc123 size: 1234
READY" "$?:$out"
  gh_save runs 'map(if .id == 1 then . + {conclusion: "failure"} else . end)'
  out=$(peal ship wait 1.0.0 2>&1)
  check "wait: failed" "1:FAILED:release https://github.com/acme/widgets/actions/runs/1" "$?:$(tail -n 1 <<<"$out")"
  gh_save runs '[]'
  out=$(PEAL_SHIP_NO_RUN=0 peal ship wait 1.0.0 2>&1)
  check "wait: no run" "1:NONE:no workflow run for v1.0.0; does a workflow run on pushed tags?" "$?:$out"
  check_refused "wait: no tag" "no tag v9.0.0" peal ship wait 9.0.0

  # Another prefix, and a remote not on GitHub: plain ids, no GitHub release.
  work=$(repo)
  mkdir -p "$work/.peal"
  printf 'release:\n  tag-prefix: release-\n' >"$work/.peal/config.yml"
  git -C "$work" add -A && git -C "$work" commit -q -m config && git -C "$work" push -q origin main 2>/dev/null
  OUTCOME="Done." land 0001 first-thing "fix: first thing [0001] (#1)"
  check "notes: no GitHub" "release-0.1.0: the first release, 1 fix.

## Fixes

- Title of 0001: Done. (0001, #1)" "$(peal ship notes 0.1.0 2>&1)"
  peal ship tag release-0.1.0 >/dev/null 2>&1
  check "tag: the prefix" "release-0.1.0" "$(git -C "$work" ls-remote --tags --refs origin | sed 's|.*refs/tags/||')"
  out=$(peal ship publish 0.1.0 2>&1)
  check "publish: not on GitHub" "0:no GitHub release: origin is not on GitHub; the tag release-0.1.0 is the release" "$?:$out"
  OUTCOME="Done." land 0002 second-thing "Second thing [0002] (#2)"
  check "propose: the prefix" "PROPOSE release-0.2.0 minor" "$(peal ship propose 2>&1 | tail -n 1)"

  # The fields: breaking and release-note are Peal's, with their values checked.
  dir=$(peal create another-thing < <(text "breaking: true" "release-note: none") 2>&1)
  check "fields: filed" "0" "$(grep -c refused <<<"$dir")"
  check_refused "fields: breaking" "breaking maybe is not true or false" \
    peal create a-third-thing < <(text "breaking: maybe")
  check_refused "fields: release-note" "release-note short is not none" \
    peal create a-fourth-thing < <(text "release-note: short")
}

# versioned WORK [CONFIG-LINE...] -> WORK given three version files at 0.1.0, a JSON, a
# TOML and a YAML one, listed in release.version-files with those lines, and a task done.
versioned() {
  local work=$1
  shift
  mkdir -p "$work/.peal" "$work/pkg"
  printf '%s\n' "release:" "  version-files:" "    - \"plugin.json: version\"" "    - \"pkg/Cargo.toml: version\"" \
    "    - \"chart.yaml: appVersion\"" "$@" >"$work/.peal/config.yml"
  printf '{\n  "name": "widgets",\n  "deps": {"version": "9.9.9"},\n  "version": "0.1.0",\n  "tags": ["version"]\n}\n' >"$work/plugin.json"
  printf 'name = "widgets"\nversion = "0.1.0" # the crate\n\n[dependencies]\nversion = "1"\n' >"$work/pkg/Cargo.toml"
  printf "name: widgets\nappVersion: '0.1.0'\nimage:\n  appVersion: 3\n" >"$work/chart.yaml"
  git -C "$work" add -A && git -C "$work" commit -q -m "chore: version files" && git -C "$work" push -q origin main 2>/dev/null
  OUTCOME="Built it." land 0001 board-view "Board view [0001] (#1)"
}

# at_version REF -> the three version lines at REF.
at_version() {
  git -C "$work" show "$1:plugin.json" | grep '^  "version"'
  git -C "$work" show "$1:pkg/Cargo.toml" | grep -m 1 '^version'
  git -C "$work" show "$1:chart.yaml" | grep '^appVersion'
}

# bump_refused NAME PATTERN -> peal ship bump 0.4.0 refused with PATTERN, main unchanged.
bump_refused() {
  local before
  before=$(git -C "$work" rev-parse origin/main)
  check_refused "bump: $1" "$2" peal ship bump 0.4.0
  check "bump: $1, main unchanged" "$before" "$(git -C "$(dirname "$work")/remote.git" rev-parse main)"
}

# listing ITEM... -> release.version-files of work's settings those items.
listing() {
  { echo "release:"; echo "  version-files:"; printf '    - "%s"\n' "$@"; } >"$work/.peal/config.yml"
}

bump() {
  local work out main
  work=$(repo)
  versioned "$work"
  main=$(git -C "$work" rev-parse origin/main)

  check_refused "bump: no version" "'banana' is no version" peal ship bump banana
  check_refused "tag: not bumped" "plugin.json on origin/main does not hold 0.2.0; peal ship bump v0.2.0 first" peal ship tag 0.2.0
  out=$(peal ship bump 0.2.0 2>&1)
  check "bump: one commit" "0:bumped plugin.json pkg/Cargo.toml chart.yaml to 0.2.0 on origin/main: $(git -C "$work" rev-parse --short origin/main) chore(release): v0.2.0" "$?:$out"
  check "bump: on main" "$main chore(release): v0.2.0" "$(git -C "$work" log -1 --format='%P %s' origin/main)"
  check "bump: only the version lines" '-appVersion: '"'0.1.0'"'
+appVersion: '"'0.2.0'"'
-version = "0.1.0" # the crate
+version = "0.2.0" # the crate
-  "version": "0.1.0",
+  "version": "0.2.0",' \
    "$(git -C "$work" diff -U0 "$main" origin/main | grep '^[-+][^-+]')"
  out=$(peal ship bump 0.2.0 2>&1)
  check "bump: again, nothing" "0:already at 0.2.0: plugin.json pkg/Cargo.toml chart.yaml" "$?:$out"
  check "bump: again, no commit" "chore(release): v0.2.0" "$(git -C "$work" log -1 --format=%s origin/main)"

  peal ship tag 0.2.0 >/dev/null 2>&1
  check "tag: on the bump, the version in each file" '  "version": "0.2.0",
version = "0.2.0" # the crate
appVersion: '"'0.2.0'"'' "$(at_version v0.2.0)"
  check "tag: the bump commit" "chore(release): v0.2.0" "$(git -C "$work" log -1 --format=%s 'v0.2.0^{commit}')"
  check "notes: the bump left out" "v0.2.0: the first release, 1 feature.

## Features

- Title of 0001: Built it. (0001, #1)" "$(peal ship notes 0.2.0 2>&1)"
  check_refused "bump: the tag exists" "v0.2.0 exists already" peal ship bump 0.2.0
  check_refused "bump: not above the last" "v0.1.5 is not above the last release, v0.2.0" peal ship bump 0.1.5
  out=$(peal ship bump 0.3.0-rc.1 2>&1)
  check "bump: a pre-release" "0|appVersion: '0.3.0-rc.1'" "$?|$(git -C "$work" show origin/main:chart.yaml | grep '^appVersion')"

  # Refusals leave main as it is.
  listing "gone.json: version"
  bump_refused "a missing file" "gone.json is not on origin/main"
  listing "plugin.json: nope"
  bump_refused "a missing field" "plugin.json: no top-level field nope"
  listing "plugin.json: deps"
  bump_refused "a field not a string" "plugin.json: the field deps is not a string"
  git -C "$work" merge -q --ff-only origin/main
  printf '{"name": "x", "deps": {"only": "1.0.0"}}\n' >"$work/nested.json"
  printf 'version: 1.0\n' >"$work/number.yml"
  printf 'x' >"$work/notes.txt"
  git -C "$work" add nested.json number.yml notes.txt && git -C "$work" commit -q -m "chore: more files" \
    && git -C "$work" push -q origin main 2>/dev/null
  listing "nested.json: only"
  bump_refused "a nested field only" "nested.json: no top-level field only"
  listing "number.yml: version"
  bump_refused "a YAML number" "number.yml: the field version is not a string"
  listing "notes.txt: version"
  bump_refused "an unknown extension" "'notes.txt' is not a .json, .toml, .yml or .yaml file"
  listing "plugin.json: deps.version"
  bump_refused "a dotted field" "is not \"PATH: FIELD\""
  listing "plugin.json: version" "number.yml: version"
  bump_refused "one good file, one bad" "number.yml: the field version is not a string"

  # Without version files, a release is as before.
  printf 'release:\n  version-files: []\n' >"$work/.peal/config.yml"
  out=$(peal ship bump 0.4.0 2>&1)
  check "bump: no version files" "0:no release.version-files nor release.changelog: nothing to bump" "$?:$out"
  out=$(peal ship tag 0.4.0 2>&1)
  check "tag: no version files" "0" "$?"
}

# changelog_of REF -> work's CHANGELOG.md at REF, byte for byte, its end marked.
changelog_of() {
  git -C "$work" show "$1:CHANGELOG.md"
  echo "<END>"
}

# publish_main -> work's main pushed to the remote's.
publish_main() {
  git -C "$work" push -q origin main 2>/dev/null
}

changelog() {
  local work out main day
  day=$(date -u +%Y-%m-%d)
  work=$(repo)
  versioned "$work" "  changelog: CHANGELOG.md"
  main=$(git -C "$work" rev-parse origin/main)

  # A file missing on main: created, in the same commit as the version files.
  out=$(peal ship bump 0.2.0 2>&1)
  check "changelog: one commit" "0:bumped plugin.json pkg/Cargo.toml chart.yaml CHANGELOG.md to 0.2.0 on origin/main: $(git -C "$work" rev-parse --short origin/main) chore(release): v0.2.0" "$?:$out"
  check "changelog: on main" "$main chore(release): v0.2.0" "$(git -C "$work" log -1 --format='%P %s' origin/main)"
  check "changelog: the files of the commit" "A	CHANGELOG.md
M	chart.yaml
M	pkg/Cargo.toml
M	plugin.json" "$(git -C "$work" diff --name-status "$main" origin/main)"
  check "changelog: created with the entry under # Changelog" "# Changelog

## v0.2.0 ($day)

v0.2.0: the first release, 1 feature.

### Features

- Title of 0001: Built it. (0001, #1)
<END>" "$(changelog_of origin/main)"
  out=$(peal ship bump 0.2.0 2>&1)
  check "changelog: again, already at" "0:already at 0.2.0: plugin.json pkg/Cargo.toml chart.yaml CHANGELOG.md" "$?:$out"
  check "changelog: again, no commit" "$main" "$(git -C "$work" rev-parse origin/main~1)"
  out=$(peal ship tag 0.2.0 2>&1)
  check "changelog: tagged" "0" "$?"

  # A second release goes above the first, the rest byte for byte.
  git -C "$work" merge -q --ff-only origin/main
  OUTCOME="Fixed it." land 0002 second-thing "fix: second thing [0002] (#2)"
  git -C "$work" show origin/main:CHANGELOG.md >"$(dirname "$work")/old.md"
  out=$(peal ship bump 0.2.1 2>&1)
  check "changelog: a second release" "0" "$?"
  check "changelog: above the first" "# Changelog

## v0.2.1 ($day)

v0.2.1: 1 fix since v0.2.0.

### Fixes

- Title of 0002: Fixed it. (0002, #2)

## v0.2.0 ($day)" "$(git -C "$work" show origin/main:CHANGELOG.md | head -n 11)"
  check "changelog: the rest byte for byte" "0" \
    "$(cmp -s <(tail -c +14 "$(dirname "$work")/old.md") <(git -C "$work" show origin/main:CHANGELOG.md | tail -n +11); echo $?)"
  check "changelog: only lines added" "" "$(git -C "$work" diff -U0 origin/main~1 origin/main -- CHANGELOG.md | grep '^-[^-]')"
  peal ship tag 0.2.1 >/dev/null 2>&1

  # A title-less file: the entry on top, the file's own text after it, untouched.
  git -C "$work" merge -q --ff-only origin/main
  printf 'Older notes, kept by hand.\n' >"$work/CHANGELOG.md"
  git -C "$work" add CHANGELOG.md && git -C "$work" commit -q -m "docs: notes by hand" && publish_main
  out=$(peal ship bump 0.2.2 2>&1)
  check "changelog: title-less, bumped" "0" "$?"
  check "changelog: title-less, the entry on top" "## v0.2.2 ($day)

v0.2.2: no finished task since v0.2.1.

Older notes, kept by hand.
<END>" "$(changelog_of origin/main)"

  # Without version files: the changelog alone is still a bump, and ship tag refuses
  # until it holds the tag's entry.
  printf 'release:\n  changelog: CHANGELOG.md\n' >"$work/.peal/config.yml"
  check_refused "changelog: tag without its entry" "CHANGELOG.md on origin/main has no entry ## v0.3.0; peal ship bump v0.3.0 first" peal ship tag 0.3.0
  main=$(git -C "$work" rev-parse origin/main)
  out=$(peal ship bump 0.3.0 2>&1)
  check "changelog: no version files, still a commit" "0:bumped CHANGELOG.md to 0.3.0 on origin/main: $(git -C "$work" rev-parse --short origin/main) chore(release): v0.3.0" "$?:$out"
  check "changelog: no version files, only the changelog" "M	CHANGELOG.md" "$(git -C "$work" diff --name-status "$main" origin/main)"
  out=$(peal ship tag 0.3.0 2>&1)
  check "changelog: tag with its entry" "0|v0.3.0" "$?|$(git -C "$work" ls-remote --tags --refs origin v0.3.0 | sed 's|.*refs/tags/||')"

  # Not a plain file: refused, main unchanged; not Markdown: refused.
  git -C "$work" merge -q --ff-only origin/main
  git -C "$work" rm -q CHANGELOG.md && mkdir "$work/CHANGELOG.md" && echo x >"$work/CHANGELOG.md/f"
  git -C "$work" add -A && git -C "$work" commit -q -m "chore: a directory" && publish_main
  main=$(git -C "$work" rev-parse origin/main)
  check_refused "changelog: a directory" "CHANGELOG.md on origin/main is not a plain file (release.changelog)" peal ship bump 0.4.0
  check "changelog: a directory, main unchanged" "$main" "$(git -C "$(dirname "$work")/remote.git" rev-parse main)"
  printf 'release:\n  changelog: notes.txt\n' >"$work/.peal/config.yml"
  check_refused "changelog: not Markdown" "release.changelog: 'notes.txt' is not a .md file" peal ship bump 0.4.0
}

# protected WORK -> WORK's remote refusing pushes to main, a fake GitHub acme/widgets
# merging into it; lines of its .peal/config.yml added.
protected() {
  local work=$1
  fake_github "$work"
  ln -s "$(dirname "$work")/remote.git" "$FAKE_GH/remote"
  printf '%s\n' "storage:" "  issues:" "    repo: acme/widgets" >>"$work/.peal/config.yml"
  cat >"$(dirname "$work")/remote.git/hooks/pre-receive" <<'EOF'
#!/bin/sh
while read -r old new ref; do
  if [ "$ref" = refs/heads/main ]; then
    echo "GH013: Repository rule violations found for refs/heads/main: changes must be made through a pull request" >&2
    exit 1
  fi
done
exit 0
EOF
  chmod +x "$(dirname "$work")/remote.git/hooks/pre-receive"
}

bump_protected() {
  local work out main
  work=$(repo)
  versioned "$work" "  changelog: CHANGELOG.md" "main-writes: pr"
  protected "$work"
  touch "$FAKE_GH/no-auto-merge"
  echo 0 >"$FAKE_GH/checks-pending"
  main=$(git -C "$work" rev-parse origin/main)

  # Through a pull request, merged: the tag on the merged commit.
  out=$(PEAL_MAIN_WRITE_INTERVAL=0 peal ship bump 0.2.0 2>&1)
  check "protected: merged" "0:bumped plugin.json pkg/Cargo.toml chart.yaml CHANGELOG.md to 0.2.0: pull request #1 https://github.com/acme/widgets/pull/1, merged" "$?:$(tail -n 1 <<<"$out")"
  check "protected: the squash commit" "$main chore(release): v0.2.0 (#1)" "$(git -C "$work" log -1 --format='%P %s' origin/main)"
  out=$(peal ship tag 0.2.0 2>&1)
  check "protected: tagged" "0" "$?"
  check "protected: the tag on the merge" "$(git -C "$work" rev-parse origin/main)|chore(release): v0.2.0 (#1)" \
    "$(git -C "$work" rev-parse 'v0.2.0^{commit}')|$(git -C "$work" log -1 --format=%s 'v0.2.0^{commit}')"
  check "protected: the version tagged" '  "version": "0.2.0",
version = "0.2.0" # the crate
appVersion: '"'0.2.0'"'' "$(at_version v0.2.0)"
  check "protected: the changelog carried" "## v0.2.0 ($(date -u +%Y-%m-%d))" "$(git -C "$work" show v0.2.0:CHANGELOG.md | grep "^## ")"

  # The budget spent with the checks pending: status 3, no tag; once merged, the rerun
  # finds the files at the version and the tag follows.
  echo 100 >"$FAKE_GH/checks-pending"
  out=$(PEAL_MAIN_WRITE_INTERVAL=1 PEAL_MAIN_WRITE_BUDGET=0 peal ship bump 0.3.0 2>&1)
  check "protected: still open" "3|not merged yet: pull request #2 https://github.com/acme/widgets/pull/2, open, not merged; run peal ship bump v0.3.0 again once it merged, then peal ship tag v0.3.0" \
    "$?|$(tail -n 1 <<<"$out")"
  check_refused "protected: no tag before the merge" "does not hold 0.3.0; peal ship bump v0.3.0 first" peal ship tag 0.3.0

  # A rerun while that pull request is still open finds it (by its title, among the
  # main-write branches) and waits for it instead of opening a second one.
  out=$(PEAL_MAIN_WRITE_INTERVAL=1 PEAL_MAIN_WRITE_BUDGET=0 peal ship bump 0.3.0 2>&1)
  check "protected: rerun before the merge, still open" "3|not merged yet: pull request #2 https://github.com/acme/widgets/pull/2, open, not merged; run peal ship bump v0.3.0 again once it merged, then peal ship tag v0.3.0" \
    "$?|$(tail -n 1 <<<"$out")"
  check "protected: rerun finds the same pull request open already" "1" \
    "$(grep -c 'pull request #2 .*is open already' <<<"$out")"
  check "protected: rerun opens no second pull request" "1|2" \
    "$(gh_get '[.[] | select(.state == "open")] | length' pulls)|$(grep -c '^POST repos/acme/widgets/pulls$' "$FAKE_GH/log")"

  echo '{"merge_method": "squash"}' | at "$work" gh api --method PUT repos/acme/widgets/pulls/2/merge --input - >/dev/null
  out=$(peal ship bump 0.3.0 2>&1)
  check "protected: rerun after the merge" "0:already at 0.3.0: plugin.json pkg/Cargo.toml chart.yaml CHANGELOG.md" "$?:$out"
  out=$(peal ship tag 0.3.0 2>&1)
  check "protected: tagged after the merge" "0|chore(release): v0.3.0 (#2)" "$?|$(git -C "$work" log -1 --format=%s 'v0.3.0^{commit}')"

  # A fork's pull request, even one naming a main-write branch and this bump's own
  # title, is never reused: its branch is not in the repository itself (the same test a
  # rival passes, docs/design.md, "Writes onto main"), so a stranger could not have Peal
  # enable auto-merge, with the maintainer's credentials, by copying a branch name and
  # title.
  echo 0 >"$FAKE_GH/checks-pending"
  gh_save pulls '. + [{number: 99, node_id: "PR_99", title: "chore(release): v0.4.0",
      state: "open", mergeable: true, html_url: "https://github.com/acme/widgets/pull/99",
      head: {ref: "peal/main-write-deadbeef", repo: {full_name: "someone/widgets"}},
      base: {ref: "main", repo: {full_name: "acme/widgets"}}}]'
  out=$(PEAL_MAIN_WRITE_INTERVAL=0 peal ship bump 0.4.0 2>&1)
  check "protected: a fork's pull request is not reused, a real one merged" "0|0" \
    "$?|$(grep -c 'is open already' <<<"$out")"
  check "protected: a fork's pull request is left alone" "99|open" \
    "$(gh_get '.[] | select(.number == 99) | .number' pulls)|$(gh_get '.[] | select(.number == 99) | .state' pulls)"
  check "protected: only the fork's pull request is left open" "1" \
    "$(gh_get '[.[] | select(.state == "open")] | length' pulls)"
}

issues() {
  local work out
  issues_repo
  issue 1 "Board view" --closed
  issue 2 "Crash on start" --closed
  issue 3 "Wrong colours" --closed --label bug
  issue 4 "Internal chore" --closed --label "release-note: none"
  issue 5 "Dropped idea" --not-planned
  issue 6 "Big thing" --label "size: L"
  issue 7 "New config" --closed --label breaking
  pr 10 $'Did it.\n\nFixes #1\n\n## Outcome\n\nBuilt the board. It works.\n\n<details>\n<summary>Commits</summary>\n</details>' --closed
  pr 11 "Fixes #2" --closed
  commit "feat: board view [1] (#10)"
  commit "fix: crash on start [2] (#11)"
  commit "Wrong colours [3] (#12)"
  commit "feat: chore [4] (#13)"
  commit "feat: dropped [5] (#14)"
  commit "feat: first part of the big thing [6] (#15)"
  commit "wip: more [6]"
  commit "docs(tasks): nothing [2]"
  check "issues: propose the first" "LAST none
ITEM feature 1 #10 Board view
ITEM fix 2 #11 Crash on start
ITEM fix 3 #12 Wrong colours
ITEM none 4 #13 Internal chore
ITEM feature - #15 first part of the big thing
PROPOSE v0.1.0 first" "$(peal ship propose 2>&1)"
  check "issues: notes" "v0.1.0: the first release, 2 features, 2 fixes.

## Features

- Board view: Built the board. (#1, #10)
- first part of the big thing (#15)

## Fixes

- Crash on start (#2, #11)
- Wrong colours (#3, #12)" "$(peal ship notes 0.1.0 2>&1)"
  peal ship tag 0.1.0 >/dev/null 2>&1
  out=$(peal ship publish 0.1.0 2>&1)
  check "issues: published" "0:released v0.1.0: https://github.com/acme/widgets/releases/tag/v0.1.0" "$?:$out"
  commit "fix: the loader [2] (#16)"
  check "issues: propose a patch" "ITEM fix 2 #16 Crash on start
PROPOSE v0.1.1 patch" "$(peal ship propose 2>&1 | tail -n 2)"
  commit "New config [7] (#17)"
  check "issues: propose a major" "ITEM breaking 7 #17 New config" "$(peal ship propose 2>&1 | grep '^ITEM breaking')"
  check "issues: major" "PROPOSE v1.0.0 major" "$(peal ship propose 2>&1 | tail -n 1)"

  # The fields become labels on an issue, and back.
  out=$(peal create a-breaking-change < <(TITLE="A breaking change" text "breaking: true" "release-note: none") 2>&1)
  check "issues: fields as labels" "breaking: true,release-note: none" "$(labels 12)"
  check "issues: labels as fields" "breaking: true|release-note: none" \
    "$(peal read 12 | grep -E '^(breaking|release-note):' | paste -s -d '|' -)"

  # ship applies the write-access rule too: an issue the rule no longer admits (never
  # really a claimed task, just a commit that happens to name it) gets the commit's own
  # subject in the notes, not its title; a pull request's Outcome is read only from one
  # opened by the repository itself or by someone with write access.
  issue 20 "Attacker title" --closed --assoc NONE
  pr 21 $'Fixes #20\n\n## Outcome\n\nHostile outcome text.' --fork NONE
  commit "feat: a safe subject [20] (#21)"
  check "issues: an unadmitted issue's own title never used" "1|0" \
    "$(peal ship propose 2>&1 | grep -c 'a safe subject')|$(peal ship propose 2>&1 | grep -c 'Attacker title')"
  check "issues: no title text or fork PR body in the notes" "0|0" \
    "$(peal ship notes 9.9.9 2>&1 | grep -c 'Attacker title')|$(peal ship notes 9.9.9 2>&1 | grep -c 'Hostile outcome text')"
}

# issues_relabel: with a filter label, a labelled closed issue its own author (no write
# access) renamed after the labelling gets the commit's subject, never its title (the
# re-label check, one batched GraphQL call); one renamed before the labelling keeps its
# own; a failed call refuses them all.
issues_relabel() {
  local work
  ISSUES_CONFIG='    label: tasks
' issues_repo
  issue 1 "Renamed afterwards" --closed --label tasks --assoc NONE \
    --labelled-at 2026-02-01T00:00:00Z --renamed-at 2026-03-01T00:00:00Z author
  issue 2 "Renamed before" --closed --label tasks --assoc NONE \
    --renamed-at 2026-01-01T00:00:00Z author --labelled-at 2026-02-01T00:00:00Z
  commit "feat: the safe subject [1] (#10)"
  commit "feat: the second subject [2] (#11)"
  : >"$FAKE_GH/log"
  check "issues, labelled: propose" "ITEM feature 1 #10 the safe subject
ITEM feature 2 #11 Renamed before" "$(peal ship propose 2>&1 | grep '^ITEM')"
  check "issues, labelled: one graphql call" "1" "$(grep -c 'POST graphql' "$FAKE_GH/log")"
  check "issues, labelled: notes" "0|1|1" "$(peal ship notes 9.9.9 2>&1 | grep -c 'Renamed afterwards')|$(peal ship notes 9.9.9 2>&1 | grep -c 'the safe subject')|$(peal ship notes 9.9.9 2>&1 | grep -c 'Renamed before')"
  printf 'POST graphql' >"$FAKE_GH/fail"
  check "issues, labelled: a failed call refuses them all" "ITEM feature 1 #10 the safe subject
ITEM feature 2 #11 the second subject" "$(peal ship propose 2>/dev/null | grep '^ITEM')"
  rm -f "$FAKE_GH/fail"
}

for_each_awk files
for_each_awk bump
for_each_awk changelog
for_each_awk bump_protected
for_each_awk issues
for_each_awk issues_relabel
finish
