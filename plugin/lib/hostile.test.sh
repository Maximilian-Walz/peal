#!/usr/bin/env bash
# shellcheck disable=SC2016 # the hostile values are literal on purpose
# Harness for hostile input: every command of the peal CLI (each target of main's
# dispatch in bin/peal, hook's included) run with values a stranger could write, through
# every channel of the task-file storage, against throwaway repositories:
#
#   bash plugin/lib/hostile.test.sh
#
# The values: command substitutions, backticks, ; && |, a newline and a command, leading
# - and --option=, ../ and absolute paths, a glob, 64 KiB, invalid UTF-8, awk's escape
# bait. The channels: CLI arguments, task texts on stdin (title and frontmatter), task
# file names and branch names on the remote, milestone files, the hooks' JSON on stdin, a
# pre-push's ref lines and a commit message. After each run: nothing ran (no canary file
# anywhere), nothing was written outside the clone's .git, its tasks, milestones and
# decisions directories, the remote, the worktrees directory (init: the work tree), no
# temporary file was left (TMPDIR is the repository's tmp/), no ref outside the expected
# shapes appeared, the status is 0 to 3 and stderr holds no shell error.
#
# The coverage check fails for a dispatch target of bin/peal no case runs; the self-test
# puts deliberately unsafe commands through the same assertions and expects each caught.
# The full matrix runs under the first awk found, the channels that go through awk (task
# texts, frontmatter, file names) under every awk installed.
#
# KNOWN: findings not fixed here, each with the idea filed for it. Their cases still run;
# a finding listed here is expected, so it fails the harness once it is fixed and not
# taken off the list.
KNOWN=()
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

# The scratch area: BASE/canary, BASE/abs-target; each repository BASE/rN/a/b/{remote.git,
# work, work-wt, tmp}, so that ../../escape from the work tree stays under BASE.
BASE=$(cd "$(scratch_dir)" && pwd -P)
CANARY=$BASE/canary
STUBS=$BASE/stubs
mkdir -p "$CANARY" "$STUBS"
# No real gh: one that fails, so nothing leaves this machine.
printf '#!/bin/sh\necho "gh: not in this harness" >&2\nexit 1\n' >"$STUBS/gh"
chmod +x "$STUBS/gh"
nrepo=0

LONG=$(head -c 65536 /dev/zero | tr '\0' 'a')
# The hostile values, one per line of their names.
H_NAMES=(dollar backtick separators newline dash option upload dotdot absolute glob long utf8 awkbait)
H=(
  "\$(touch $CANARY/dollar)"
  "\`touch $CANARY/backtick\`"
  "x; touch $CANARY/semi && touch $CANARY/and | touch $CANARY/pipe"
  "x"$'\n'"touch $CANARY/newline"
  "-rf"
  "--output=$CANARY/option"
  "--upload-pack=touch $CANARY/upload"
  "../../escape"
  "$BASE/abs-target"
  "*"
  "$LONG"
  $'\xff\xfe'
  'x\n a=b'
)

# hostile_repo -> REPO (BASE/rN/a/b), WORK, its clone on main, with the hooks installed,
# the decisions module on, and on the remote: tasks 0001 (m1), 0002 (m2) and 0003 (m1,
# claimed by a branch with a hostile name), task files with hostile names, a task with a
# hostile title and frontmatter, a milestone file with hostile fields, and task branches
# with hostile names (0040-0045).
hostile_repo() {
  nrepo=$((nrepo + 1))
  REPO=$BASE/r$nrepo/a/b
  WORK=$REPO/work
  mkdir -p "$REPO/tmp"
  git init -q --bare "$REPO/remote.git"
  git -C "$REPO/remote.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$REPO/remote.git" "$WORK" 2>/dev/null
  git -C "$WORK" checkout -q -b main 2>/dev/null
  mkdir -p "$WORK/docs/milestones" "$WORK/tasks/backlog" "$WORK/.peal" "$WORK/docs/decisions"
  milestone_file "$WORK" m0 "done" 0
  milestone_file "$WORK" m1 current 1
  milestone_file "$WORK" m2 open 2
  printf 'decisions: docs/decisions\n' >"$WORK/.peal/config.yml"
  : >"$WORK/docs/decisions/.gitkeep"
  ID=0001 text "milestone: m1" >"$WORK/tasks/backlog/0001-plain-task.md"
  ID=0002 text "milestone: m2" >"$WORK/tasks/backlog/0002-other-task.md"
  ID=0003 text "milestone: m1" >"$WORK/tasks/backlog/0003-third-task.md"
  seed_hostile_names "$WORK/tasks/backlog"
  seed_hostile_text "$WORK/tasks/backlog/0030-hostile-text.md"
  seed_hostile_milestone "$WORK/docs/milestones/m9.md"
  git -C "$WORK" add -A
  git -C "$WORK" commit -q -m root
  git -C "$WORK" push -q -u origin main 2>/dev/null
  seed_hostile_branches
  (cd "$WORK" && PATH="$STUBS:$PATH" "$PEAL" hooks install >/dev/null 2>&1)
}

# seed_hostile_names DIR -> task files 0010-0023 whose names break the slug rule (but
# 0023's, 200 characters). No / fits in a file name, so their commands make a relative
# canary (any file named pwned*); those without a space fit in a ref too.
seed_hostile_names() {
  local name n=10
  for name in '$(touch pwned-fname)' '`touch pwned-tick`' 'a;touch pwned-semi' '-rf' \
      '$(>pwned-fnamer)' '`>pwned-tickr`' 'a;>pwned-semir' '--upload-pack=>pwned-up' \
      'a b' "x"$'\n'"touch pwned-nl" $'\xff\xfe' '..' 'UPPER' "$(head -c 200 /dev/zero | tr '\0' 'a')"; do
    ID=00$n text "milestone: m1" >"$1/00$n-$name.md"
    n=$((n + 1))
  done
}

# seed_hostile_text FILE -> task 0030, its title and frontmatter hostile.
seed_hostile_text() {
  ID=0030 TITLE="\$(touch $CANARY/title) \`touch $CANARY/title2\`; touch $CANARY/title3" text \
    "milestone: m1" \
    "size: \$(touch $CANARY/size)" \
    "priority: '\`touch $CANARY/priority\`'" \
    "depends: ['\$(touch $CANARY/depends)', '../../escape']" \
    "touches: ['../../escape', '/etc/passwd', '-rf', '\$(touch $CANARY/touches)']" \
    "needs: ['\$(touch $CANARY/needs)']" \
    "owner: '; touch $CANARY/owner'" \
    "merge: '| touch $CANARY/merge'" >"$1"
}

# seed_hostile_milestone FILE -> an open milestone whose title and heading are hostile.
seed_hostile_milestone() {
  printf -- '---\nstate: open\norder: 9\ntitle: "$(touch %s/mtitle) `touch %s/mtick`"\n---\n\n# $(touch %s/mhead)\n' \
    "$CANARY" "$CANARY" "$CANARY" >"$1"
}

# seed_hostile_branches -> task branches with hostile names on the remote, and one local.
seed_hostile_branches() {
  local name
  for name in 'task/0040-$(>pwned-branch)' 'task/0041-a;>pwned-semi' 'task/0042--rf' \
      'task/0043-`>pwned-tickb`' 'task/0003-$(>pwned-claimed)' 'task/0044-a|>pwned-pipe'; do
    git -C "$WORK" push -q origin "main:refs/heads/$name" 2>/dev/null
  done
  git -C "$WORK" fetch -q origin 2>/dev/null
  git -C "$WORK" branch -q 'task/0045-$(>pwned-local)' main 2>/dev/null
}

# snapshot -> every path under BASE with its checksum, but where writes belong.
snapshot() {
  local prune=() extra
  for extra in ${ALLOW[@]+"${ALLOW[@]}"}; do prune+=(-path "$extra" -prune -o); done
  (cd "$BASE" && find . -path ./canary -prune -o -path '*/a/b/remote.git' -prune -o \
    -path '*/a/b/work/.git' -prune -o -path '*/a/b/work/tasks' -prune -o \
    -path '*/a/b/work/docs/milestones' -prune -o -path '*/a/b/work/docs/decisions' -prune -o \
    -path '*/a/b/work-wt' -prune -o -path '*/a/b/tmp' -prune -o ${prune[@]+"${prune[@]}"} -print 2>/dev/null \
    | LC_ALL=C sort)
  (cd "$BASE" && find . -path ./canary -prune -o -path '*/a/b/remote.git' -prune -o \
    -path '*/a/b/work/.git' -prune -o -path '*/a/b/work/tasks' -prune -o \
    -path '*/a/b/work/docs/milestones' -prune -o -path '*/a/b/work/docs/decisions' -prune -o \
    -path '*/a/b/work-wt' -prune -o -path '*/a/b/tmp' -prune -o ${prune[@]+"${prune[@]}"} -type f -exec cksum {} + 2>/dev/null \
    | LC_ALL=C sort)
}
ALLOW=()

# refs -> every ref of the clone and the remote, one per line.
refs() {
  git -C "$WORK" for-each-ref --format='clone %(refname)'
  git -C "$REPO/remote.git" for-each-ref --format='remote %(refname)'
}

# ref_ok REF -> status 0 for a ref of an expected shape.
ref_ok() {
  local slug='[a-z0-9]+(-[a-z0-9]+)*'
  [[ "$1" =~ ^refs/heads/main$ ]] || [[ "$1" =~ ^refs/remotes/origin/(HEAD|main)$ ]] \
    || [[ "$1" =~ ^refs/(heads/|remotes/origin/)task/[0-9]{4}-$slug$ ]] \
    || [[ "$1" =~ ^refs/reaped/[0-9]{4}-$slug$ ]] || [[ "$1" =~ ^refs/decisions/[0-9]{4}$ ]] \
    || [[ "$1" =~ ^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# assess CWD INPUT CMD... -> CMD run in CWD with the file INPUT on stdin; prints each
# problem found, nothing for a safe run. CMD is the peal CLI unless it names another.
assess() {
  local cwd=$1 input=$2 before after rbefore rafter err status line leaked
  shift 2
  before=$(snapshot)
  rbefore=$(refs)
  err=$(cd "$cwd" && TMPDIR=$REPO/tmp PATH="$STUBS:$PATH" "$@" <"$input" 2>&1 >/dev/null)
  status=$?
  if [ -n "$(ls -A "$CANARY")" ] || [ -n "$(find "$BASE" -name 'pwned*' 2>/dev/null | head -n 1)" ]; then
    printf 'executed: %s\n' "$(ls -A "$CANARY"; find "$BASE" -name 'pwned*' 2>/dev/null)" | tr '\n' ' '
    echo
    rm -rf "${CANARY:?}"/* && find "$BASE" -name 'pwned*' -exec rm -rf {} + 2>/dev/null
  fi
  after=$(snapshot)
  if [ "$before" != "$after" ]; then
    printf 'wrote outside: %s\n' "$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep '^[<>]' | head -n 5 | tr '\n' ' ')"
  fi
  leaked=$(ls -A "$REPO/tmp")
  if [ -n "$leaked" ]; then
    printf 'temp files left: %s\n' "$(printf '%s' "$leaked" | head -n 5 | tr '\n' ' ')"
    rm -rf "${REPO:?}/tmp"/* "$REPO"/tmp/.[!.]* 2>/dev/null
  fi
  rafter=$(refs)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    ref_ok "${line#* }" || printf 'new ref: %s\n' "$line"
  done < <(comm -13 <(printf '%s\n' "$rbefore" | LC_ALL=C sort) <(printf '%s\n' "$rafter" | LC_ALL=C sort))
  if [ "$status" -gt 3 ]; then
    printf 'status %s: %s\n' "$status" "$(printf '%s' "$err" | tail -n 3 | cut -c1-200 | tr '\n' ' ')"
  fi
  case $err in
    *"syntax error"* | *"command not found"* | *"unbound variable"* | *"bad substitution"* | *"unexpected EOF"* | *"ambiguous redirect"*)
      printf 'shell error: %s\n' "$(printf '%s' "$err" | grep -m 3 -e 'syntax error' -e 'command not found' \
        -e 'unbound variable' -e 'bad substitution' -e 'unexpected EOF' -e 'ambiguous redirect' | cut -c1-200 | tr '\n' ' ')" ;;
  esac
  return 0
}

COVERED=" "
NOINPUT=$BASE/empty
: >"$NOINPUT"
INPUT=$NOINPUT

# cover TARGET -> TARGET (a dispatch target of bin/peal: "claim", "hook stop") has a case.
cover() { COVERED="$COVERED$1 "; }

# try LABEL CWD ARG... -> peal ARG... run in CWD with INPUT on stdin, judged; a problem
# fails the check, unless KNOWN lists "LABEL: problem kind".
try() {
  local label=$1 cwd=$2 problems kind known
  shift 2
  problems=$(assess "$cwd" "$INPUT" "$PEAL" "$@")
  if [ -n "$problems" ]; then
    kind=${problems%%:*}
    for known in ${KNOWN[@]+"${KNOWN[@]}"}; do
      if [ "${known%% *}" = "$label:$kind" ]; then KNOWN_HIT="$KNOWN_HIT$known"$'\n'; problems=""; fi
    done
  fi
  check "$label" "" "$problems"
}
KNOWN_HIT=""

# each LABEL CWD ARG... -> try once per hostile value, the value in place of every @ among
# the ARGs.
each() {
  local label=$1 cwd=$2 i a args
  shift 2
  for ((i = 0; i < ${#H[@]}; i++)); do
    args=()
    for a in "$@"; do
      if [ "$a" = @ ]; then args+=("${H[i]}"); else args+=("$a"); fi
    done
    try "$label [${H_NAMES[i]}]" "$cwd" "${args[@]}"
  done
}

# with_input TEXT FUNCTION ARGS... -> FUNCTION run with TEXT on stdin.
with_input() {
  local text=$1
  shift
  INPUT=$BASE/input
  printf '%s' "$text" >"$INPUT"
  "$@"
  INPUT=$NOINPUT
}

# each_input LABEL CWD TEMPLATE ARG... -> try once per hostile value, the value in place
# of every @ in TEMPLATE, which is stdin.
each_input() {
  local label=$1 cwd=$2 template=$3 i
  shift 3
  for ((i = 0; i < ${#H[@]}; i++)); do
    INPUT=$BASE/input
    printf '%s' "${template//@/${H[i]}}" >"$INPUT"
    try "$label [${H_NAMES[i]}]" "$cwd" "$@"
  done
  INPUT=$NOINPUT
}

# claim_wt ID -> WT, a claim of task ID made in the current repository.
claim_wt() {
  WT=$(cd "$WORK" && PATH="$STUBS:$PATH" TMPDIR=$REPO/tmp "$PEAL" claim "$1" --print-path 2>/dev/null | tail -n 1)
  rm -rf "${REPO:?}/tmp"/*
}

# A task text whose heading, frontmatter and Raw are hostile, for create, idea, revise.
hostile_text() {
  printf -- '---\nmilestone: m1\nsize: S\ntouches: [%s]\n---\n\n# %s — %s\n\n## Intent\n\n%s\n\n## Raw\n\n%s\n\n## Notes\n\n---\n\n## Outcome\n\n<!-- fill in at close -->\n' \
    "'@'" NNNN "@" "@" "@"
}

# --- the channels read through awk: under every awk --------------------------------------

awk_channels() {
  local wt
  hostile_repo
  for target in list board overview check milestones; do cover "$target"; done
  try "list, hostile names and text" "$WORK" list --no-pr
  try "list --fetch, hostile names" "$WORK" list --fetch --no-pr
  try "board, hostile names and text" "$WORK" board --no-pr
  try "overview, hostile names and text" "$WORK" overview
  try "milestones, hostile fields" "$WORK" milestones
  try "milestones --json, hostile fields" "$WORK" milestones --json
  try "check, hostile names in the work tree" "$WORK" check
  local id
  for id in 0003 0010 0011 0012 0013 0014 0015 0016 0017 0018 0019 0020 0021 0022 0023 0030 \
      0040 0041 0042 0043 0044 0045; do
    try "read $id, hostile name" "$WORK" read "$id"
  done
  cover read
  try "claim 0030, hostile text" "$WORK" claim 0030
  for id in 0003 0010 0011 0012 0013 0014 0017 0018 0019 0020 0021 0023; do
    try "claim $id, hostile name" "$WORK" claim "$id"
  done
  cover create
  each_input "create, hostile text" "$WORK" "$(hostile_text)" create hostile-text-task
  each_input "create --batch, hostile text" "$WORK" "$(hostile_text)" create --batch 0001 found-hostile-text
  claim_wt 0001
  wt=$WT
  if [ -z "$wt" ] || [ ! -d "$wt" ]; then
    check "claim 0001 for the channels of a claim" "a worktree" "${wt:-nothing}"
    return
  fi
  cover idea
  each_input "idea queued, hostile text" "$wt" "$(hostile_text)" idea queued-hostile-idea
  cover ideas
  try "ideas, hostile queue" "$wt" ideas
  try "ideas --flush, hostile queue" "$wt" ideas --flush
  cover record
  each_input "record notes, hostile text" "$wt" "$(ID=0001 RAW="the human said so" text "milestone: m1" "size: S")
@" record 0001 notes
  cover revise
  each_input "revise, hostile text" "$WORK" "$(ID=0002 RAW="the human said so" text "milestone: m2" "touches: ['@']")
@" revise 0002 --reason why --dry-run
}

# --- CLI arguments, once --------------------------------------------------------------------

arg_cases() {
  local wt msg
  hostile_repo
  cover --version; each "--version, extra argument" "$WORK" --version @
  cover -h; each "help, extra argument" "$WORK" help @
  cover config; each "config KEY" "$WORK" config @
  each "check ARG" "$WORK" check @
  each "milestones ARG" "$WORK" milestones @
  each "list ARG" "$WORK" list --no-pr @
  each "list --state S" "$WORK" list --no-pr --state @
  cover board; each "board ARG" "$WORK" board --no-pr @
  cover overview; each "overview ARG" "$WORK" overview @
  each "read ID" "$WORK" read @

  cover frontmatter
  local fm=tasks/backlog/0001-plain-task.md
  each "frontmatter check FILE" "$WORK" frontmatter check @
  each "frontmatter keys FILE" "$WORK" frontmatter keys @
  each "frontmatter get FILE" "$WORK" frontmatter get @ milestone
  each "frontmatter get KEY" "$WORK" frontmatter get "$fm" @
  each "frontmatter set FILE" "$WORK" frontmatter set @ size S
  each "frontmatter set KEY" "$WORK" frontmatter set "$fm" @ S
  each "frontmatter set VALUE" "$WORK" frontmatter set "$fm" size @
  each "frontmatter set-list ITEM" "$WORK" frontmatter set-list "$fm" touches a @ b
  each "frontmatter unset KEY" "$WORK" frontmatter unset "$fm" @
  git -C "$WORK" checkout -q -- "$fm"

  cover hooks; each "hooks ARG" "$WORK" hooks @
  cover init
  ALLOW=('*/a/b/work')
  each "init --stage STAGE" "$WORK" init --stage @
  each "init --remove STAGE" "$WORK" init --remove @
  each "init --storage KIND" "$WORK" init --stage tasks --storage @
  each "init --label LABEL" "$WORK" init --stage tasks --storage issues --label @
  each "init --title TITLE" "$WORK" init --stage milestones --title @
  each "init --survey ARG" "$WORK" init --survey @
  ALLOW=()
  git -C "$WORK" checkout -q -- . 2>/dev/null
  git -C "$WORK" clean -q -fd -- .peal .claude .belfry.yml 2>/dev/null

  cover create
  with_input "$(ID=NNNN text "milestone: m1" "size: S")" each "create SLUG" "$WORK" create @
  with_input "$(ID=NNNN text "milestone: m1" "size: S")" each "create --part-of ID" "$WORK" create --part-of @ some-piece
  with_input "$(ID=NNNN text "milestone: m1" "size: S")" each "create --batch SLUG" "$WORK" create --batch 0001 @
  with_input "$(ID=NNNN text "milestone: m1" "size: S")" each "idea SLUG on main" "$WORK" idea @
  with_input "$(ID=NNNN text "milestone: m1" "size: S")" each "idea --now ARG" "$WORK" idea some-idea-here @
  each "ideas ARG" "$WORK" ideas @

  cover retire
  each "retire ID" "$WORK" retire @ --reason why
  each "retire --reason R" "$WORK" retire 0002 --reason @
  with_input "$(ID=0001 text "milestone: m1")" each "revise ID" "$WORK" revise @ --reason why
  with_input "$(ID=0001 text "milestone: m1" "size: S")" each "revise --reason R" "$WORK" revise 0001 --reason @ --dry-run
  cover comment
  each "comment ID" "$WORK" comment @ text
  each "comment TEXT" "$WORK" comment 0001 @
  cover set-milestone
  each "set-milestone ID" "$WORK" set-milestone @ m1
  each "set-milestone M" "$WORK" set-milestone 0001 @
  cover finish; each "finish ID" "$WORK" finish @

  cover offer
  each "offer POOL" "$WORK" offer @
  each "offer --top N" "$WORK" offer current --top @
  cover claim
  each "claim ID" "$WORK" claim @
  each "claim --next POOL" "$WORK" claim --next @
  cover release; each "release ID" "$WORK" release @
  cover work; each "work ARG" "$WORK" work @
  cover brief; each "brief ROLE" "$WORK" brief @

  cover milestone-review; each "milestone-review ID" "$WORK" milestone-review @
  cover milestone-state
  each "milestone-state ID" "$WORK" milestone-state @ parked
  each "milestone-state STATE" "$WORK" milestone-state m2 @
  each "milestone-state --reason R" "$WORK" milestone-state m2 parked --reason @
  each "milestone-state --review FILE" "$WORK" milestone-state m9 "done" --review @

  cover ship
  each "ship SUB" "$WORK" ship @
  each "ship notes VERSION" "$WORK" ship notes @
  each "ship tag VERSION" "$WORK" ship tag @
  each "ship publish VERSION" "$WORK" ship publish @
  each "ship wait VERSION" "$WORK" ship wait @

  cover decision
  each "decision SUB" "$WORK" decision @
  each "decision brief --task FILE" "$WORK" decision brief --task @
  each "decision brief --diff BASE" "$WORK" decision brief --diff @

  cover githook
  each "githook NAME" "$WORK" githook @
  each "githook commit-msg FILE" "$WORK" githook commit-msg @

  # In a claim's worktree.
  claim_wt 0001
  wt=$WT
  if [ -z "$wt" ] || [ ! -d "$wt" ]; then
    check "claim 0001 for the arguments in a claim" "a worktree" "${wt:-nothing}"
    return
  fi
  each "decision reserve SLUG" "$wt" decision reserve @
  each "work ID in a claim" "$wt" work @
  each "brief ROLE in a claim" "$wt" brief @
  with_input "$(ID=0001 text "milestone: m1")" each "record ID" "$wt" record @ notes
  with_input "$(ID=0001 text "milestone: m1")" each "record WHAT" "$wt" record 0001 @
  msg=$BASE/msg
  local i
  for ((i = 0; i < ${#H[@]}; i++)); do
    printf 'feat: %s [0001]\n\n%s\n' "${H[i]}" "${H[i]}" >"$msg"
    try "githook commit-msg, hostile message [${H_NAMES[i]}]" "$wt" githook commit-msg "$msg"
  done
  each_input "githook pre-push, hostile ref lines" "$wt" "@ @ @ @
refs/heads/@ 0000000000000000000000000000000000000000 refs/heads/@ 0000000000000000000000000000000000000000
" githook pre-push origin "$REPO/remote.git"
  cover commit
  echo change >>"$wt/tasks/doing/0001-plain-task.md"
  each "commit SUBJECT" "$wt" commit @ tasks/doing/0001-plain-task.md
  each "commit PATH" "$wt" commit "docs(tasks): x [0001]" @
  each "commit --body TEXT" "$wt" commit "docs(tasks): x [0001]" --body @ tasks/doing/0001-plain-task.md
  each "commit --body-file FILE" "$wt" commit "docs(tasks): x [0001]" --body-file @
  cover close
  each "close SUB" "$wt" close @
  each "close body --summary" "$wt" close body --summary @
  each "close body --section" "$wt" close body --summary s --section @ @
  each "close body --summary-file" "$wt" close body --summary-file @
  each "close body --review-file" "$wt" close body --summary s --review-file @
  each "close abort REASON" "$wt" close abort @
  each "close verify ARG" "$wt" close verify @
  each "close finish --summary" "$wt" close finish --summary @
  cover defer
  with_input "$(ID=0001 text "milestone: m1")" each "defer --reason R" "$wt" defer --reason @ --dry-run
  with_input "$(ID=0001 text "milestone: m1")" each "defer ARG" "$wt" defer @
}

# --- the hooks' JSON on stdin ----------------------------------------------------------------

hook_cases() {
  local wt hook json
  hostile_repo
  claim_wt 0001
  wt=$WT
  [ -n "$wt" ] || wt=$WORK
  cover hook
  json='{"session_id":"@","source":"@","cwd":"@","transcript_path":"@","tool_name":"Bash","tool_input":{"command":"git commit -m @; git push origin @ --force","file_path":"@"},"stop_hook_active":"@"}'
  for hook in session-start post-tool-use session-end stop git-guard decisions; do
    cover "hook $hook"
    each_input "hook $hook, hostile JSON" "$wt" "$json" hook "$hook"
    each_input "hook $hook, hostile JSON on main" "$WORK" "$json" hook "$hook"
  done
  each "hook NAME" "$WORK" hook @
}

# --- the self-test: unsafe commands are caught --------------------------------------------

self_test() {
  local unsafe=$BASE/unsafe problems
  hostile_repo
  printf '#!/usr/bin/env bash\neval "echo $1" >/dev/null\n' >"$unsafe.eval"
  printf '#!/usr/bin/env bash\nprintf x >"$1"\n' >"$unsafe.write"
  printf '#!/usr/bin/env bash\nmktemp >/dev/null\n' >"$unsafe.temp"
  printf '#!/usr/bin/env bash\ngit update-ref "refs/heads/$1" HEAD\n' >"$unsafe.ref"
  printf '#!/usr/bin/env bash\nbash -c "if then"\n' >"$unsafe.syntax"
  chmod +x "$unsafe".*
  problems=$(assess "$WORK" "$NOINPUT" "$unsafe.eval" "${H[0]}")
  check "self-test: an eval is caught" "executed" "${problems%%:*}"
  problems=$(assess "$WORK" "$NOINPUT" "$unsafe.write" "${H[7]}")
  check "self-test: a write outside is caught" "wrote outside" "${problems%%:*}"
  problems=$(assess "$WORK" "$NOINPUT" "$unsafe.temp")
  check "self-test: a temp file left is caught" "temp files left" "${problems%%:*}"
  problems=$(assess "$WORK" "$NOINPUT" "$unsafe.ref" 'task/x;y')
  check "self-test: a ref of no expected shape is caught" "new ref" "${problems%%:*}"
  problems=$(assess "$WORK" "$NOINPUT" "$unsafe.syntax")
  check "self-test: a shell error is caught" "shell error" "${problems%%:*}"
}

# --- coverage: every dispatch target of bin/peal has a case ----------------------------------

# targets -> the dispatch targets of bin/peal: the first name of each pattern in main's
# case, and "hook NAME" for each of cmd_hook's.
targets() {
  awk '
    /^main\(\) \{/ { fn = "main" } /^cmd_hook\(\) \{/ { fn = "hook" } /^}/ { fn = "" }
    fn != "" && /^    [^ ()*][^()]*\) / {
      t = $0; sub(/^ +/, "", t); sub(/[ |)].*/, "", t)
      print (fn == "hook" ? "hook " t : t)
    }' "$PEAL"
}

coverage() {
  local target missing="" all
  all=$(targets)
  check "coverage: targets found in bin/peal" "yes" "$([ "$(printf '%s\n' "$all" | wc -l)" -gt 30 ] && echo yes || echo "no: $all")"
  while IFS= read -r target; do
    [[ "$COVERED" == *" $target "* ]] || missing="$missing $target"
  done <<<"$all"
  check "coverage: every dispatch target of bin/peal has a hostile case" "" "$missing"
}

# PEAL_HOSTILE_CASES: the groups to run (self_test awk_channels arg_cases hook_cases), all
# by default; the coverage check runs with all of them only.
cases=${PEAL_HOSTILE_CASES:-self_test awk_channels arg_cases hook_cases}
# run_group NAME CMD... -> CMD, if NAME is one of the groups to run.
run_group() {
  local name=$1
  shift
  [[ " $cases " != *" $name "* ]] || "$@"
}
run_group self_test self_test
run_group awk_channels for_each_awk awk_channels
# The rest under the first awk only: their values never reach awk as a task text.
first_awk=""
for candidate in mawk gawk nawk original-awk; do
  command -v "$candidate" >/dev/null && { first_awk=$candidate; break; }
done
if [ -n "$first_awk" ] && [ -z "${PEAL_TEST_AWK-}" ]; then
  PEAL_TEST_AWK=$first_awk run_group arg_cases for_each_awk arg_cases
  PEAL_TEST_AWK=$first_awk run_group hook_cases for_each_awk hook_cases
else
  run_group arg_cases for_each_awk arg_cases
  run_group hook_cases for_each_awk hook_cases
fi
[ -n "${PEAL_HOSTILE_CASES-}" ] || coverage
for known in ${KNOWN[@]+"${KNOWN[@]}"}; do
  case $KNOWN_HIT in
    *"$known"*) ;;
    *) check "KNOWN still found: $known" "found" "fixed, or no longer run: take it off KNOWN" ;;
  esac
done
finish
