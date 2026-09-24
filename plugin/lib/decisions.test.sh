#!/usr/bin/env bash
# shellcheck disable=SC2016 # backticks and jq's $variables, not the shell's
# Harness for the decisions module (lib/decisions.sh): peal decision reserve (a race
# included), check and peal check, the PostToolUse guard, index and publish, brief and
# the subagents' briefs, the close's commit of an entry and the git gates' part, on each
# storage (task files, and issues; both on lib/fake-gh, so only when jq is here), in a
# task's worktree of a throwaway repository with a bare remote:
#
#   bash plugin/lib/decisions.test.sh
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

if ! command -v jq >/dev/null; then
  echo "decisions.test.sh: no jq here, which the fake gh needs; skipped" >&2
  [ -z "${PEAL_REQUIRE_JQ-}" ] || exit 1
  exit 0
fi
# This harness may run inside a Claude Code session, or a workflow, whose variables
# would leak in.
unset CLAUDE_CODE_SESSION_ID CLAUDE_PROJECT_DIR GITHUB_HEAD_REF

# The storage the cases run on: files or issues.
kind=files
DEC=docs/decisions

# new_repo [CONFIG-LINE...] -> work, a new repository on the storage of kind with a fake
# GitHub, the decisions module on (unless a line says otherwise) and those lines in its
# .peal/config.yml.
new_repo() {
  if [ $kind = files ]; then
    work=$(repo)
    fake_github "$work"
    mkdir "$work/.peal"
    printf '%s\n' "remote: origin" >"$work/.peal/config.yml"
  else
    ISSUES_CONFIG="" issues_repo
    printf '\n' >>"$work/.peal/config.yml"
  fi
  if [ $# -eq 0 ]; then
    echo "decisions: $DEC" >>"$work/.peal/config.yml"
  else
    printf '%s\n' "$@" >>"$work/.peal/config.yml"
  fi
  publish "$work"
}

# id N -> task N's id on this storage: 0001 as a file, 1 as an issue.
id() {
  if [ $kind = files ]; then printf '%04d\n' "$1"; else printf '%s\n' "$1"; fi
}

# ready [SCOPE] -> task 1 put on the storage (its Scope SCOPE, else `a.txt`), the hooks
# installed, the task claimed; wt its worktree, branch its branch.
ready() {
  local body
  body=$'Why, with lib/intent/only/here.sh.\n\n## Scope\n\n'"${1-\`a.txt\`}"$'\n\n## Done when\n\n- a.txt says built\n\n## Raw\n\nthe human said so\n\n## Notes\n'
  if [ $kind = files ]; then
    printf -- '---\n---\n\n# 0001 — Title of 0001\n\n## Intent\n\n%s\n---\n\n## Outcome\n\n<!-- fill in at close -->\n' \
      "$body" >"$work/tasks/backlog/0001-first-task.md"
    publish "$work"
  else
    issue 1 "Title of 1" --body "## Intent"$'\n\n'"$body"
  fi
  at "$work" "$PEAL" hooks install >/dev/null
  wt=$(at "$work" "$PEAL" claim "$(id 1)" --print-path 2>/dev/null | tail -n 1)
  branch=$(git -C "$wt" symbolic-ref --short HEAD)
}

# entry DIR NUM SLUG [STATUS [EXTRA]] -> a filled-in entry DIR/docs/decisions/NUM-SLUG.md,
# titled "Title of NUM", its Status STATUS (accepted), EXTRA a paragraph after its own.
entry() {
  mkdir -p "$1/$DEC"
  printf '# %s — Title of %s\nDate: 2026-01-01\nStatus: %s\n\n**Decision.** Decided %s.\n\n**Why.** Because.\n\n**Rules out.** Nothing.\n%s' \
    "$2" "$2" "${4:-accepted}" "$2" "${5:+$'\n'$5$'\n'}" >"$1/$DEC/$2-$3.md"
}

# on_remote NUM -> the subject of the marker refs/decisions/NUM holds on the remote.
on_remote() {
  git -C "$work" fetch -q origin "refs/decisions/$1" 2>/dev/null && git -C "$work" log -1 --format=%s FETCH_HEAD
}

# rival NUM BRANCH -> NUM reserved on the remote by another clone, for BRANCH.
rival() {
  local sha
  sha=$(git -C "$work" commit-tree "$(git -C "$work" hash-object -w -t tree /dev/null)" \
    -m "reserve decision $1: other-call (branch $2, $today)")
  git -C "$work" push -q origin "$sha:refs/decisions/$1" 2>/dev/null
}

# fill FILE -> the scaffold's placeholders filled in.
fill() {
  sed 's/<!--.*-->/Filled in./' "$1" >"$1.new" && mv "$1.new" "$1"
}

dcheck() { at "$wt" "$PEAL" decision check; }

off_cases() {
  new_repo "decisions: false"
  ready
  check_refused "off: reserve refused" "the decisions module is off" at "$wt" "$PEAL" decision reserve some-call
  check_refused "off: check refused" "the decisions module is off" dcheck
  entry "$wt" 0001 hand-made "not a status"
  check "off: peal check leaves entries alone" "0" "$(at "$wt" "$PEAL" check >/dev/null 2>&1; echo $?)"
  check "off: the guard is silent" "0|" \
    "$(printf '{"tool_input":{"file_path":"%s"}}' "$wt/$DEC/0001-hand-made.md" | at "$wt" "$PEAL" hook decisions 2>&1; echo "$?|")"
  check "off: the brief has no decisions" "" "$(at "$wt" "$PEAL" brief planner | grep 'Decisions in')"
  new_repo "decisions: true"
  check_refused "off: a setting that is no directory" "not 'true'" at "$work" "$PEAL" decision index
}

reserve_cases() {
  local out file
  new_repo
  entry "$work" 0004 on-main
  publish "$work"
  ready
  check_refused "reserve: no slug" "decision reserve: SLUG" at "$wt" "$PEAL" decision reserve
  check_refused "reserve: a flag" "decision reserve: SLUG" at "$wt" "$PEAL" decision reserve --help
  check_refused "reserve: one word" "2 to 5 kebab-case words" at "$wt" "$PEAL" decision reserve call
  check_refused "reserve: on main" "this is main" at "$work" "$PEAL" decision reserve some-call
  git -C "$wt" checkout -q --detach
  check_refused "reserve: detached" "HEAD is detached" at "$wt" "$PEAL" decision reserve some-call
  git -C "$wt" checkout -q "$branch"

  # The number: past main's entries, the remote's reservations and the entries here.
  out=$(at "$wt" "$PEAL" decision reserve "Plain Bash only" 2>&1)
  check "reserve: past main's entries" "reserved decision 0005 for $branch (refs/decisions/0005 on origin)" \
    "$(printf '%s\n' "$out" | head -n 1)"
  check "reserve: the marker" "reserve decision 0005: plain-bash-only (branch $branch, $today)" "$(on_remote 0005)"
  file=$wt/$DEC/0005-plain-bash-only.md
  check "reserve: the scaffold" "# 0005 — Plain bash only
Date: $today
Status: accepted

**Decision.** <!-- what is decided, in a sentence or two -->" "$(head -n 5 "$file")"
  check "reserve: nothing committed" "?? $DEC/0005-plain-bash-only.md" "$(git -C "$wt" status --porcelain --untracked-files=all)"
  rival 0006 someone/else
  entry "$wt" 0008 local-only
  check "reserve: past the reservations and the entries here" "reserved decision 0009 for $branch (refs/decisions/0009 on origin)" \
    "$(at "$wt" "$PEAL" decision reserve second-call 2>&1 | head -n 1)"
  rm "$wt/$DEC/0008-local-only.md"

  # The race: another reservation of the same number lands between the count and the push.
  local shims real
  shims=$(scratch_dir)
  real=$(command -v git)
  cat >"$shims/git" <<EOF
#!/bin/sh
case "\$*" in
  *push*:refs/decisions/*)
    if [ ! -e "$shims/raced" ]; then
      : >"$shims/raced"
      ref=\${*##*:}
      sha=\$("$real" -C "$work" commit-tree "\$("$real" -C "$work" hash-object -w -t tree /dev/null)" -m "reserve decision \${ref##*/}: rival (branch rival, $today)")
      "$real" -C "$work" push -q origin "\$sha:\$ref" 2>/dev/null
    fi
    ;;
esac
exec "$real" "\$@"
EOF
  chmod +x "$shims/git"
  out=$(at "$wt" env PATH="$shims:$PATH" "$PEAL" decision reserve raced-call 2>&1)
  check "race: lost, then the next number" "0|peal: decision reserve: 0010 was reserved meanwhile (1 of 5); again with the next number
reserved decision 0011 for $branch (refs/decisions/0011 on origin)" "$?|$(printf '%s\n' "$out" | head -n 2)"
  check "race: the rival keeps its number" "reserve decision 0010: rival (branch rival, $today)" "$(on_remote 0010)"
  check "race: ours holds the next" "reserve decision 0011: raced-call (branch $branch, $today)" "$(on_remote 0011)"
  check "race: the scaffold has the next number" "0011-raced-call.md" "$(cd "$wt/$DEC" && echo *raced*)"
  rm "$shims/raced"
  out=$(at "$wt" env PATH="$shims:$PATH" PEAL_PUSH_ATTEMPTS=1 "$PEAL" decision reserve lost-call 2>&1)
  check "race: gives up" "1|peal: decision reserve: gave up after 1 pushes, each losing a race; nothing reserved|" \
    "$?|$(printf '%s\n' "$out" | tail -n 1)|$(cd "$wt/$DEC" && find . -name "*lost*")"

  # A push refused for another reason is no race.
  printf '#!/bin/sh\necho no reservations here >&2\nexit 1\n' >"$(dirname "$work")/remote.git/hooks/pre-receive"
  chmod +x "$(dirname "$work")/remote.git/hooks/pre-receive"
  out=$(at "$wt" "$PEAL" decision reserve refused-call 2>&1)
  check "reserve: a refused push" "1|peal: decision reserve: the push of refs/decisions/0013 failed, and not from a race; nothing reserved:" \
    "$?|$(printf '%s\n' "$out" | grep 'not from a race')"
  rm "$(dirname "$work")/remote.git/hooks/pre-receive"
}

check_cases() {
  local out sha link
  new_repo
  entry "$work" 0001 first-call
  entry "$work" 0002 second-call
  entry "$work" 0003 third-call "superseded by 0002" "**Supersedes** decision 0001."
  publish "$work"
  ready
  out=$(dcheck 2>&1)
  check "check: nothing added, in order" "0|decisions: in order" "$?|$out"

  # Well-formed, every entry.
  printf '# 0004 — Title\n' >"$wt/$DEC/4-short-name.md"
  : >"$wt/$DEC/0005-empty-entry.md"
  printf '# Title\nStatus: accepted\n' >"$wt/$DEC/0006-no-heading.md"
  printf '# 0008 — Title\nStatus: accepted\n' >"$wt/$DEC/0007-wrong-number.md"
  printf '# 0009 — Title\n\n**Decision.** x\n' >"$wt/$DEC/0009-no-status.md"
  printf '# 0010 — Title\nStatus: proposed\n' >"$wt/$DEC/0010-bad-status.md"
  printf '# 0011 — Title\nStatus: superseded by 0099\n' >"$wt/$DEC/0011-unknown-successor.md"
  printf '# 0012 — Title\nStatus: superseded by 0012\n' >"$wt/$DEC/0012-own-successor.md"
  printf '# 0013 — Title\nStatus: accepted\n\n**Why.** <!-- later -->\n' >"$wt/$DEC/0013-a-placeholder.md"
  printf '# 0013 — Twice\nStatus: accepted\n' >"$wt/$DEC/0013-number-twice.md"
  printf '# 0014 —  \nStatus: accepted\n' >"$wt/$DEC/0014-no-title.md"
  out=$(dcheck 2>&1)
  check "check: refused" "2" "$(dcheck >/dev/null 2>&1; echo $?)"
  check "well-formed: a bad name" "1" "$(printf '%s\n' "$out" | grep -c '4-short-name.md: its name is not NNNN-slug.md')"
  check "well-formed: empty" "1" "$(printf '%s\n' "$out" | grep -c '0005-empty-entry.md: is empty')"
  check "well-formed: no heading" "1" "$(printf '%s\n' "$out" | grep -c '0006-no-heading.md: its first line is not the heading "# 0006 — Title"')"
  check "well-formed: another number" "1" "$(printf '%s\n' "$out" | grep -c '0007-wrong-number.md: its heading says 0008, its file name 0007')"
  check "well-formed: no Status" "1" "$(printf '%s\n' "$out" | grep -c '0009-no-status.md: has no "Status: " line')"
  check "well-formed: a bad Status" "1" "$(printf '%s\n' "$out" | grep -c '0010-bad-status.md: its Status is "proposed"')"
  check "well-formed: an unknown successor" "1" "$(printf '%s\n' "$out" | grep -c '0011-unknown-successor.md: is superseded by 0099, which is no entry here')"
  check "well-formed: its own successor" "1" "$(printf '%s\n' "$out" | grep -c '0012-own-successor.md: says it is superseded by itself')"
  check "well-formed: a placeholder" "1" "$(printf '%s\n' "$out" | grep -c '0013-a-placeholder.md: still holds a placeholder')"
  check "well-formed: a number twice" "1" "$(printf '%s\n' "$out" | grep -c 'shares its number with another entry: 0013-a-placeholder.md 0013-number-twice.md')"
  check "well-formed: no title" "1" "$(printf '%s\n' "$out" | grep -c '0014-no-title.md: its heading has no title')"
  check "check: peal check says so too" "2|1" \
    "$(at "$wt" "$PEAL" check >/dev/null 2>&1; echo "$?|$(at "$wt" "$PEAL" check 2>&1 | grep -c '0005-empty-entry.md: is empty')")"
  git -C "$wt" clean -q -f -- "$DEC"

  # Reservations: an added entry holds one of this branch's own.
  entry "$wt" 0004 unreserved-call
  check_refused "reservation: none" "0004 is reserved by no one (refs/decisions/0004 is not on origin)" dcheck
  rival 0004 someone/else
  check_refused "reservation: another branch's" "0004 is reserved by the branch someone/else, not by $branch" dcheck
  check "reservation: in a pull request's workflow, the head branch" "0" \
    "$(at "$wt" env GITHUB_HEAD_REF=someone/else "$PEAL" decision check >/dev/null 2>&1; echo $?)"
  git -C "$work" push -q origin :refs/decisions/0004 2>/dev/null
  sha=$(git -C "$work" commit-tree "$(git -C "$work" hash-object -w -t tree /dev/null)" -m "made by hand")
  git -C "$work" push -q origin "$sha:refs/decisions/0004" 2>/dev/null
  check_refused "reservation: no marker of Peal's" 'refs/decisions/0004 holds no reservation Peal made ("made by hand")' dcheck
  git -C "$work" push -q origin :refs/decisions/0004 2>/dev/null
  rm "$wt/$DEC/0004-unreserved-call.md"
  at "$wt" "$PEAL" decision reserve fourth-call >/dev/null 2>&1
  fill "$wt/$DEC/0004-fourth-call.md"
  check "reservation: its own" "0" "$(dcheck >/dev/null 2>&1; echo $?)"
  git -C "$wt" add -A && git -C "$wt" commit -q -m "docs(decisions): record 0004 [$(id 1)]" >/dev/null 2>&1
  check "reservation: committed, still its own" "0" "$(dcheck >/dev/null 2>&1; echo $?)"
  git -C "$wt" checkout -q --detach
  check_refused "reservation: a detached HEAD" "not by this detached HEAD" dcheck
  git -C "$wt" checkout -q "$branch"
  local url
  url=$(git -C "$wt" remote get-url origin)
  git -C "$wt" remote set-url origin "$url.gone"
  check_refused "reservation: the remote unreachable" "could not ask origin for refs/decisions/0004" dcheck
  out=$(printf '{"tool_input":{"file_path":"%s"}}' "$wt/$DEC/0004-fourth-call.md" | at "$wt" "$PEAL" hook decisions 2>&1)
  check "guard: the remote unreachable only warns" "0|Peal: warning, a decision reservation could not be verified:" \
    "$?|$(printf '%s\n' "$out" | head -n 1)"
  git -C "$wt" remote set-url origin "$url"

  # The index is main's.
  printf '# Decisions\n' >"$wt/$DEC/index.md"
  check_refused "index: new on the branch" "$DEC/index.md is changed on this branch" dcheck
  rm "$wt/$DEC/index.md"

  # No entry is deleted.
  git -C "$wt" rm -q "$DEC/0002-second-call.md"
  check_refused "append-only: deleted" "0002-second-call.md: is deleted" dcheck
  git -C "$wt" checkout -q HEAD -- "$DEC/0002-second-call.md"

  # Supersessions pair: the old entry's Status and the new entry's **Supersedes**.
  sed 's/^Status: accepted/Status: superseded by 0004/' "$wt/$DEC/0001-first-call.md" >"$wt/x" && mv "$wt/x" "$wt/$DEC/0001-first-call.md"
  check_refused "supersedes: the new entry does not say so" "0001-first-call.md: says it is superseded by 0004, but 0004-fourth-call.md has no **Supersedes** paragraph naming 0001" dcheck
  sed 's/^Status: superseded by 0004/Status: superseded by 0002/' "$wt/$DEC/0001-first-call.md" >"$wt/x" && mv "$wt/x" "$wt/$DEC/0001-first-call.md"
  check_refused "supersedes: by an entry the branch does not add" "0001-first-call.md: says it is superseded by 0002, which this branch does not add" dcheck
  git -C "$wt" checkout -q HEAD -- "$DEC/0001-first-call.md"
  printf '\n**Supersedes** decision 0001, in full.\n' >>"$wt/$DEC/0004-fourth-call.md"
  check_refused "supersedes: the old entry's Status unchanged" "0004-fourth-call.md: supersedes 0001, whose Status still reads \"accepted\": make it \"superseded by 0004\" on this branch too" dcheck
  sed 's/^Status: accepted/Status: superseded by 0004 (in full)/' "$wt/$DEC/0001-first-call.md" >"$wt/x" && mv "$wt/x" "$wt/$DEC/0001-first-call.md"
  check "supersedes: paired" "0" "$(dcheck >/dev/null 2>&1; echo $?)"
  printf '\n**Supersedes** decisions 0002 and 0003 in part.\n' >>"$wt/$DEC/0004-fourth-call.md"
  out=$(dcheck 2>&1)
  check "supersedes: a second, not paired" "1" "$(printf '%s\n' "$out" | grep -c 'supersedes 0002, whose Status still reads "accepted"')"
  check "supersedes: one superseded already" "1" "$(printf '%s\n' "$out" | grep -c 'supersedes 0003, which is superseded by 0002 already')"
  git -C "$wt" checkout -q HEAD -- "$DEC/0004-fourth-call.md"
  printf '\n**Supersedes** task 0001.\n' >>"$wt/$DEC/0004-fourth-call.md"
  check_refused "supersedes: no number after the verb" "0004-fourth-call.md: has a **Supersedes** paragraph naming no entry right after its verb" dcheck
  git -C "$wt" checkout -q HEAD -- "$DEC/0004-fourth-call.md"
  printf '\n**Supersedes (in part).** [0001](0001-first-call.md), its first clause.\n' >>"$wt/$DEC/0004-fourth-call.md"
  check "supersedes: a link, in part" "0" "$(dcheck >/dev/null 2>&1; echo $?)"
  git -C "$wt" checkout -q HEAD -- "$DEC/0001-first-call.md" "$DEC/0004-fourth-call.md"
  sed 's/^\*\*Why\.\*\* Because\./**Why.** Because, reworded./' "$wt/$DEC/0003-third-call.md" >"$wt/x" && mv "$wt/x" "$wt/$DEC/0003-third-call.md"
  check "supersedes: a superseded entry edited, its Status as it was" "0" "$(dcheck >/dev/null 2>&1; echo $?)"
  git -C "$wt" checkout -q HEAD -- "$DEC/0003-third-call.md"

  # The guard: after an entry is written, the checks; anything else, silence.
  entry "$wt" 0020 hand-numbered
  out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$wt/$DEC/0020-hand-numbered.md" | at "$wt" "$PEAL" hook decisions 2>&1)
  check "guard: a problem" "2|Peal: the decision entries are not in order:
  - $DEC/0020-hand-numbered.md: 0020 is reserved by no one (refs/decisions/0020 is not on origin). Numbers come from peal decision reserve SLUG: reserve one and rename the entry." \
    "$?|$out"
  link=$(scratch_dir)/link
  ln -s "$wt" "$link"
  check "guard: through a symbolic link" "2" \
    "$(printf '{"tool_input":{"file_path":"%s"}}' "$link/$DEC/0020-hand-numbered.md" | at "$wt" "$PEAL" hook decisions >/dev/null 2>&1; echo $?)"
  check "guard: another file" "0|" \
    "$(printf '{"tool_input":{"file_path":"%s"}}' "$wt/a.txt" | at "$wt" "$PEAL" hook decisions 2>&1; echo "$?|")"
  check "guard: an entry-like file elsewhere" "0|" \
    "$(printf '{"tool_input":{"file_path":"%s"}}' "$wt/docs/0020-hand-numbered.md" | at "$wt" "$PEAL" hook decisions 2>&1; echo "$?|")"
  rm "$wt/$DEC/0020-hand-numbered.md"
  check "guard: in order" "0|" \
    "$(printf '{"tool_input":{"file_path":"%s"}}' "$wt/$DEC/0004-fourth-call.md" | at "$wt" "$PEAL" hook decisions 2>&1; echo "$?|")"
}

index_cases() {
  local out
  new_repo
  entry "$work" 0002 second-call
  entry "$work" 0001 first-call "superseded by 0003"
  entry "$work" 0003 third-call accepted "**Supersedes** decision 0001."
  publish "$work"
  ready
  out=$(at "$wt" "$PEAL" decision index)
  check "index: accepted, then superseded" "| # | Title |
|---|---|
| [0002](0002-second-call.md) | Title of 0002 |
| [0003](0003-third-call.md) | Title of 0003 |

## Superseded

| # | Title | Superseded by |
|---|---|---|
| [0001](0001-first-call.md) | Title of 0001 | [0003](0003-third-call.md) |" "$(printf '%s\n' "$out" | sed -n '/^| # | Title |$/,$p')"
  check "index: its heading" "# Decisions" "$(printf '%s\n' "$out" | head -n 1)"
  : >"$wt/$DEC/0004-empty-entry.md"
  check_refused "index: a malformed entry" "0004-empty-entry.md: is empty" at "$wt" "$PEAL" decision index
  rm "$wt/$DEC/0004-empty-entry.md"

  # Publish: onto the remote's main, from anywhere, touching no worktree.
  out=$(at "$wt" "$PEAL" decision publish 2>&1)
  check "publish: published" "0|published $DEC/index.md to origin/main" "$?|$out"
  check "publish: the index on main" "$(at "$wt" "$PEAL" decision index)" "$(on_main "$work" "$DEC/index.md")"
  check "publish: its commit" "docs(decisions): regenerate the index" "$(git -C "$work" log -1 --format=%s origin/main)"
  check "publish: the worktree untouched" "" "$(git -C "$wt" status --porcelain)"
  out=$(at "$wt" "$PEAL" decision publish 2>&1)
  check "publish: again, nothing to do" "0|$DEC/index.md on origin/main is up to date|1" \
    "$?|$out|$(git -C "$work" rev-list --count origin/main --grep 'regenerate the index')"
  other=$(scratch_dir)/other
  git clone -q "$(dirname "$work")/remote.git" "$other" 2>/dev/null
  entry "$other" 0004 fourth-call
  git -C "$other" add -A && git -C "$other" commit -q -m "a merge's entry" && git -C "$other" push -q origin main 2>/dev/null
  check "publish: after a merge, the new entry" "0|| [0004](0004-fourth-call.md) | Title of 0004 |" \
    "$(at "$wt" "$PEAL" decision publish >/dev/null 2>&1; echo "$?|$(on_main "$work" "$DEC/index.md" | grep 0004)")"
  entry "$other" 0005 fifth-call "not a status"
  git -C "$other" add -A && git -C "$other" commit -q -m "a bad entry" && git -C "$other" pull -q --rebase origin main 2>/dev/null
  git -C "$other" push -q origin main 2>/dev/null
  check_refused "publish: a malformed entry on main" "an entry on main is malformed" at "$wt" "$PEAL" decision publish

  # The pre-push gate lets the index through onto main, and nothing else with it.
  git -C "$other" pull -q --rebase origin main 2>/dev/null
  git -C "$other" rm -q "$DEC/0005-fifth-call.md"
  git -C "$other" commit -q -m "fix it"
  git -C "$other" push -q origin main 2>/dev/null
  at "$work" "$PEAL" hooks install >/dev/null
  git -C "$work" pull -q --rebase origin main 2>/dev/null
  check "pre-push: the index published through the gate" "0" "$(at "$work" "$PEAL" decision publish >/dev/null 2>&1; echo $?)"
  git -C "$work" pull -q --rebase origin main 2>/dev/null
  echo "# stale" >"$work/$DEC/index.md"
  echo x >"$work/x.txt"
  git -C "$work" add -A
  git -C "$work" -c core.hooksPath=/dev/null commit -q -m "docs(decisions): regenerate the index"
  check_fails "pre-push: the index and more" 1 "its diff is not the index alone" git -C "$work" push -q origin main
  git -C "$work" reset -q --hard origin/main
}

brief_cases() {
  local out
  new_repo
  entry "$work" 0001 names-the-file accepted 'It governs `lib/a/b/c.sh`.'
  entry "$work" 0002 names-the-dir accepted "Everything under lib/a/b/ follows it."
  entry "$work" 0003 names-nothing
  entry "$work" 0004 superseded-one "superseded by 0005" "It governed lib/a/b/c.sh too."
  entry "$work" 0005 names-a-readme accepted "**Supersedes** decision 0004. See README.md."
  entry "$work" 0006 names-intent accepted "About lib/intent/only/here.sh."
  publish "$work"
  ready '- `lib/a/b/c.sh`, and the README.md.'
  out=$(at "$wt" "$PEAL" decision brief --task "$(peal_task_file)")
  check "brief: from the Scope" "Decisions in $DEC/ that name a path of the task (its ## Scope); read each that bears on the work:
paths: lib/a/b/c.sh README.md
0001 — Title of 0001 (matched: lib/a/b/c.sh)
  Decided 0001.
0002 — Title of 0002 (matched: lib/a/b)
  Decided 0002.
0005 — Title of 0005 (matched: README.md)
  Decided 0005.
(1 superseded entry matched too, left out)" "$out"
  check_refused "brief: no mode" "--task FILE | --diff" at "$wt" "$PEAL" decision brief
  check_refused "brief: no task file" "no task file nowhere.md" at "$wt" "$PEAL" decision brief --task nowhere.md
  printf -- '---\n---\n\n# 0009 — T\n\n## Intent\n\nSee lib/intent/only/here.sh.\n\n## Scope\n\n## Notes\n\nnothing\n' >"$wt/../t.md"
  check "brief: an empty Scope, from the Intent" "Decisions in $DEC/ that name a path of the task (its ## Intent and ## Notes, the Scope being empty); read each that bears on the work:
paths: lib/intent/only/here.sh
0006 — Title of 0006 (matched: lib/intent/only/here.sh)
  Decided 0006." "$(at "$wt" "$PEAL" decision brief --task ../t.md)"
  printf -- '---\n---\n\n# 0009 — T\n\n## Scope\n\nJust words, e.g. this.\n' >"$wt/../t.md"
  check "brief: no path" "paths: none: no path in it to look for" \
    "$(at "$wt" "$PEAL" decision brief --task ../t.md | sed -n 2p | sed 's/^no path/paths: none: no path/')"

  mkdir -p "$wt/lib/a/b"
  echo x >"$wt/lib/a/b/d.sh"
  git -C "$wt" add -A && git -C "$wt" commit -q -m "feat: d [$(id 1)]"
  out=$(at "$wt" "$PEAL" decision brief --diff)
  check "brief: the diff's paths" "lib/a/b/d.sh" "$(printf '%s\n' "$out" | sed -n 's/^paths: //p' | tr ' ' '\n' | grep lib/)"
  check "brief: the diff" "0001 — Title of 0001 (matched: lib/a/b)
  Decided 0001.
0002 — Title of 0002 (matched: lib/a/b)
  Decided 0002.
(1 superseded entry matched too, left out)" "$(printf '%s\n' "$out" | sed 1,2d)"
  check "brief: a diff since a base given" "paths: lib/a/b/d.sh" "$(at "$wt" "$PEAL" decision brief --diff HEAD~1 | sed -n 2p)"

  # The subagents' briefs carry it: the planner the task's, the reviewer the diff's.
  out=$(at "$wt" "$PEAL" brief planner)
  check "brief planner: the task's decisions" "0001 — Title of 0001 (matched: lib/a/b/c.sh)" "$(printf '%s\n' "$out" | grep '^0001')"
  out=$(at "$wt" "$PEAL" brief reviewer)
  check "brief reviewer: the diff's decisions" "0002 — Title of 0002 (matched: lib/a/b)" "$(printf '%s\n' "$out" | grep '^0002')"
  check "brief implementer: none" "" "$(at "$wt" "$PEAL" brief implementer | grep 'Decisions in')"
}

# peal_task_file -> the file the worktree's task is read from (the brief's Task: line).
peal_task_file() {
  at "$wt" "$PEAL" brief implementer | sed -n 's/^Task: \(.*\)\. It is the whole scope: read it first\.$/\1/p'
}

close_cases() {
  local text out
  new_repo "decisions: $DEC" "commit:" "  areas: [core]"
  ready
  echo built >"$wt/a.txt"
  git -C "$wt" add -A && git -C "$wt" commit -q -m "feat(core): build a.txt [$(id 1)]" && git -C "$wt" push -q -u origin HEAD 2>/dev/null
  out=$(at "$wt" "$PEAL" close begin 2>&1)
  text=$(printf '%s\n' "$out" | sed -n 's/^Outcome: write it in \(.*\), under ## Outcome\.$/\1/p')
  case $text in /*) ;; *) text=$wt/$text ;; esac
  awk '$0 == "## Outcome" { print; print ""; print "Built a.txt; decided 0001."; exit } { print }' "$text" >"$text.new" && mv "$text.new" "$text"
  at "$wt" "$PEAL" decision reserve built-a-txt >/dev/null 2>&1
  check_refused "close: an unfilled entry refused" "0001-built-a-txt.md: still holds a placeholder" \
    at "$wt" "$PEAL" close finish --summary "- built a.txt"
  check "close: nothing moved by the refusal" "feat(core): build a.txt [$(id 1)]" "$(git -C "$wt" log -1 --format=%s)"
  fill "$wt/$DEC/0001-built-a-txt.md"
  echo stray >"$wt/stray.txt"
  check_refused "close: another path still refused" "?? stray.txt" at "$wt" "$PEAL" close finish --summary "- built a.txt"
  rm "$wt/stray.txt"
  out=$(at "$wt" "$PEAL" close finish --summary "- built a.txt" 2>&1)
  check "close: finished" "0" "$?"
  check "close: the entry committed on its own" "committed decision(s) 0001" "$(printf '%s\n' "$out" | grep '^committed decision')"
  if [ $kind = files ]; then
    check "close: right before the task's move" "docs(tasks): close 0001 [0001]
docs(decisions): record 0001 [0001]" "$(git -C "$wt" log -2 --format=%s)"
  else
    check "close: the last commit" "docs(decisions): record 0001 [1]" "$(git -C "$wt" log -1 --format=%s)"
  fi
  check "close: the entry alone in it" "$DEC/0001-built-a-txt.md" \
    "$(git -C "$wt" log -1 --format= --name-only --grep '^docs(decisions)')"
  check "close: clean and pushed" "|0" "$(git -C "$wt" status --porcelain)|$(git -C "$wt" rev-list --count '@{upstream}..HEAD')"

  # The commit gate: a (decisions) commit is always allowed, and holds only entries.
  entry "$wt" 0002 another-call
  echo more >"$wt/a.txt"
  git -C "$wt" add -A
  check_fails "commit-msg: (decisions) with more" 1 "a (decisions) commit touches only $DEC/; this one also" \
    git -C "$wt" commit -q -m "docs(decisions): record 0002 [$(id 1)]"
  git -C "$wt" reset -q -- a.txt
  check "commit-msg: (decisions) with entries only" "0" \
    "$(git -C "$wt" commit -q -m "docs(decisions): record 0002 [$(id 1)]" >/dev/null 2>&1; echo $?)"
}

cases() {
  off_cases
  reserve_cases
  check_cases
  index_cases
  brief_cases
  close_cases
}

# run -> the cases on task files, then on issues.
run() {
  local saved=$awk_name
  kind=files
  cases
  kind=issues awk_name="$saved, issues"
  cases
  awk_name=$saved
}

for_each_awk run
finish
