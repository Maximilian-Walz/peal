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
# release), the GitHub release created and updated, the wait for the tag's workflow runs
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

for_each_awk files
for_each_awk issues
finish
