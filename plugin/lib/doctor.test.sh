#!/usr/bin/env bash
# Harness for peal doctor (lib/doctor.sh), through the peal CLI:
#
#   bash plugin/lib/doctor.test.sh
#
# Two healthy cases (one per storage), then each broken case doctor finds: bad config
# (a refusal, then its own value checks), a stale or missing launcher, a version
# mismatch or none found, the git gates missing in each way, gh missing or logged out, a
# claim that could be released, landed dirty, or a prunable worktree, and .belfry.yml's
# list/board/offer commands: one that fails, one with a bad shape, and a command that is
# not literally Peal's, never run (a marker file must not appear). Then the structural
# rules: several problems counted, CHECK... selecting one, a bad CHECK or no git
# repository or no .peal/ exiting 2, a broken config making every dependent skip, and
# guardrails not staged skipping hooks alone (exit 0).
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

# newpeal WORK -> WORK/.peal, so doctor does not refuse "no .peal/ here".
newpeal() { mkdir -p "$1/.peal"; }

# d WORK ARGS... -> `peal doctor ARGS...` in WORK, through this checkout's own peal
# (never a launcher or a cache): fine for every check but version's (b) and belfry, which
# need a real, findable Peal.
d() {
  local work=$1
  shift
  (cd "$work" && "$PEAL" doctor "$@")
}

# fake_cache HOME -> a real copy of this Peal in HOME's plugin cache (no
# installed_plugins.json, so any version and path there is taken), for a launcher run
# with CLAUDE_CONFIG_DIR=HOME to find (templates/launcher.test.sh's end-to-end setup).
fake_cache() {
  local home=$1 version real
  version=$("$PEAL" --version)
  real="$home/plugins/cache/peal/peal/$version"
  mkdir -p "$real"
  cp -R "$PEAL_ROOT/." "$real/"
}

# fake_peal DIR VERSION -> a stand-in Peal at DIR whose --version prints VERSION and
# whose board prints one bad line: enough for the version-mismatch and belfry-bad-shape
# cases, which never call anything else of it.
fake_peal() {
  local dir=$1 version=$2
  mkdir -p "$dir/bin" "$dir/.claude-plugin"
  cat >"$dir/bin/peal" <<EOF
#!/bin/sh
case "\$1" in
  --version | version) echo "$version" ;;
  board) echo "not json" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$dir/bin/peal"
  printf '{\n  "name": "peal",\n  "version": "%s"\n}\n' "$version" >"$dir/.claude-plugin/plugin.json"
}

# launcher_doctor WORK HOME ARGS... -> `peal doctor ARGS...` in WORK, PEAL_ROOT unset and
# CLAUDE_CONFIG_DIR=HOME, so .peal/peal (when it matches the template) and doctor's own
# internal calls both resolve through HOME's fake cache exactly as an outside caller would.
launcher_doctor() {
  local work=$1 home=$2
  shift 2
  (cd "$work" && env -u PEAL_ROOT CLAUDE_CONFIG_DIR="$home" "$PEAL" doctor "$@")
}

# no_gh_path -> a PATH with everything on this one but gh (lib/close.test.sh's
# no_gh_path, the same trick: symlink every executable but gh into a fresh directory).
no_gh_path() {
  local dir d f
  dir=$(scratch_dir)
  local IFS=:
  for d in $PATH; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      if [ ! -x "$f" ] || [ -d "$f" ]; then continue; fi
      case ${f##*/} in gh) continue ;; esac
      [ -e "$dir/${f##*/}" ] || ln -s "$f" "$dir/${f##*/}"
    done
  done
  printf '%s\n' "$dir"
}

belfry_commands() {
  cat <<'EOF'
tasks:
  backend: commands
  commands:
    list: .peal/peal list
    offer: .peal/peal offer "{pool}" --top 10
    pool: current,unassigned
    claim: .peal/peal claim {task} --print-path
    board: .peal/peal board
EOF
}

# ---------------------------------------------------------------------------- healthy --

healthy_files() {
  local work home out status
  work=$(repo)
  home=$(scratch_dir)
  fake_cache "$home"
  newpeal "$work"
  cp "$PEAL_ROOT/templates/launcher" "$work/.peal/peal"
  printf 'stages: [tasks, guardrails, milestones, belfry]\n' >"$work/.peal/config.yml"
  (cd "$work" && "$PEAL" hooks install >/dev/null)
  # peal hooks install records this checkout's own PEAL_ROOT as the git directory's
  # recorded root; the fixture wants the launcher to resolve through the fake cache
  # instead, as an outside caller with no such record would.
  rm -f "$work/.git/peal-root"
  belfry_commands >"$work/.belfry.yml"

  out=$(launcher_doctor "$work" "$home")
  status=$?
  check "healthy files: exit 0" "0" "$status"
  check "healthy files: no FAIL line" "" "$(printf '%s\n' "$out" | grep '^FAIL' || true)"
  check "healthy files: the count line" "doctor: 0 problem(s)" "$(printf '%s\n' "$out" | tail -n1)"
  check "healthy files: every check reported ok" "yes" \
    "$(printf '%s\n' "$out" | grep -qc '^ok config' \
      && printf '%s\n' "$out" | grep -q '^ok version' \
      && printf '%s\n' "$out" | grep -q '^ok hooks' \
      && printf '%s\n' "$out" | grep -q '^skip gh' \
      && printf '%s\n' "$out" | grep -q '^ok claims' \
      && printf '%s\n' "$out" | grep -q '^ok belfry' \
      && echo yes)"
}

healthy_issues() {
  local home out status
  ISSUES_CONFIG=$'stages: [tasks, guardrails, belfry]\n' issues_repo
  home=$(scratch_dir)
  fake_cache "$home"
  newpeal "$work"
  cp "$PEAL_ROOT/templates/launcher" "$work/.peal/peal"
  (cd "$work" && "$PEAL" hooks install >/dev/null)
  rm -f "$work/.git/peal-root"
  belfry_commands >"$work/.belfry.yml"

  out=$(launcher_doctor "$work" "$home")
  status=$?
  check "healthy issues: exit 0" "0" "$status"
  check "healthy issues: no FAIL line" "" "$(printf '%s\n' "$out" | grep '^FAIL' || true)"
  check "healthy issues: the count line" "doctor: 0 problem(s)" "$(printf '%s\n' "$out" | tail -n1)"
  check "healthy issues: gh checked, not skipped" "yes" "$(printf '%s\n' "$out" | grep -q '^ok gh' && echo yes)"
}

# ------------------------------------------------------------------------------ config --

config_cases() {
  local work out

  work=$(repo)
  newpeal "$work"
  printf 'bogus: 1\n' >"$work/.peal/config.yml"
  out=$(d "$work" config)
  check "config: unknown key: FAIL" "yes" "$(printf '%s\n' "$out" | grep -q '^FAIL config: unknown setting bogus' && echo yes)"
  check "config: unknown key: the fix names the line" "yes" "$([[ "$out" == *"fix: edit .peal/config.yml line 1"* ]] && echo yes)"
  check "config: unknown key: exit 1" "1" "$(d "$work" config >/dev/null; echo $?)"

  printf 'storage:\n  kind: nope\nmain-writes: never\nsizes:\n  S: x\n' >"$work/.peal/config.yml"
  out=$(d "$work" config)
  check "config: bad storage.kind" "yes" "$([[ "$out" == *"FAIL config: storage.kind is 'nope', not files or issues"* ]] && echo yes)"
  check "config: bad main-writes" "yes" "$([[ "$out" == *"FAIL config: main-writes is 'never', not push, pr or auto"* ]] && echo yes)"
  check "config: bad sizes.S" "yes" "$([[ "$out" == *"FAIL config: sizes.S is 'x', not a positive integer"* ]] && echo yes)"
  check "config: several problems, one count line" "doctor: 3 problem(s)" "$(printf '%s\n' "$out" | tail -n1)"

  printf 'stages: [tasks, bogus-stage]\n' >"$work/.peal/config.yml"
  out=$(d "$work" config)
  check "config: bad stage" "yes" "$([[ "$out" == *"FAIL config: stages has 'bogus-stage'"* ]] && echo yes)"

  printf 'release:\n  wait-ci: sometimes\n' >"$work/.peal/config.yml"
  out=$(d "$work" config)
  check "config: bad release.wait-ci" "yes" "$([[ "$out" == *"FAIL config: release.wait-ci is 'sometimes', not true or false"* ]] && echo yes)"

  printf 'models:\n  reviewer:\n' >"$work/.peal/config.yml"
  out=$(d "$work" config)
  check "config: empty models.reviewer" "yes" "$([[ "$out" == *"FAIL config: models.reviewer is empty"* ]] && echo yes)"

  rm -f "$work/.peal/config.yml"
  out=$(d "$work" config)
  check "config: defaults are valid" "ok config: the effective settings load and are valid
doctor: 0 problem(s)" "$out"
}

# ----------------------------------------------------------------------------- version --

version_cases() {
  local work home out real

  # (a): no launcher at all, tasks not staged: skipped, not a problem.
  work=$(repo)
  newpeal "$work"
  out=$(d "$work" version)
  check "version: no launcher, tasks not staged: skip" "skip version: no .peal/peal here to check
doctor: 0 problem(s)" "$out"

  # (a): no launcher, but tasks is staged: a problem.
  printf 'stages: [tasks]\n' >"$work/.peal/config.yml"
  out=$(d "$work" version)
  check "version: no launcher, tasks staged: FAIL" "yes" \
    "$([[ "$out" == *"FAIL version: no .peal/peal here, though tasks is a stage"* ]] && echo yes)"
  rm -f "$work/.peal/config.yml"

  # (a): a launcher that does not match the template.
  printf '#!/usr/bin/env bash\necho "not the real launcher"\n' >"$work/.peal/peal"
  chmod +x "$work/.peal/peal"
  out=$(d "$work" version)
  check "version: edited launcher: FAIL, no (b) attempted" "FAIL version: .peal/peal does not match the plugin's launcher template
  fix: .peal/peal init --stage tasks, then commit .peal/peal
doctor: 1 problem(s)" "$out"

  # (a) holds, (b): no installed Peal findable at all.
  cp "$PEAL_ROOT/templates/launcher" "$work/.peal/peal"
  home=$(scratch_dir)
  out=$(launcher_doctor "$work" "$home" version)
  check "version: (a) ok, (b) nothing installed" "yes" \
    "$(printf '%s\n' "$out" | grep -q '^ok version: .peal/peal matches' \
      && [[ "$out" == *"FAIL version: env -u PEAL_ROOT .peal/peal --version found no installed Peal"* ]] \
      && echo yes)"

  # (a) holds, (b): a Peal installed, but at another version.
  real="$home/plugins/cache/peal/peal/9.9.9"
  fake_peal "$real" 9.9.9
  out=$(launcher_doctor "$work" "$home" version)
  check "version: (a) ok, (b) another version" "yes" \
    "$([[ "$out" == *"FAIL version: the installed Peal (9.9.9) is not the one running this session ("* ]] && echo yes)"

  # (a) and (b) both hold.
  home=$(scratch_dir)
  fake_cache "$home"
  out=$(launcher_doctor "$work" "$home" version)
  check "version: (a) and (b) both ok" "0" "$(printf '%s\n' "$out" | grep -c '^FAIL')"
}

# ------------------------------------------------------------------------------- hooks --

hooks_cases() {
  local work out dir

  work=$(repo)
  newpeal "$work"
  printf 'stages: [tasks]\n' >"$work/.peal/config.yml"
  out=$(d "$work" hooks)
  check "hooks: guardrails not staged: skip, exit 0" "skip hooks: guardrails is not a stage here
doctor: 0 problem(s)" "$out"

  printf 'stages: [tasks, guardrails]\n' >"$work/.peal/config.yml"
  out=$(d "$work" hooks)
  check "hooks: core.hooksPath unset: FAIL" "yes" \
    "$([[ "$out" == *"FAIL hooks: core.hooksPath is not set; Peal's git gates do not run"* ]] && echo yes)"

  git -C "$work" config core.hooksPath .githooks
  out=$(d "$work" hooks)
  check "hooks: core.hooksPath foreign: FAIL" "yes" \
    "$([[ "$out" == *"FAIL hooks: core.hooksPath is"*".githooks, not Peal's stubs"* ]] && echo yes)"
  git -C "$work" config --unset core.hooksPath

  (cd "$work" && "$PEAL" hooks install >/dev/null)
  dir=$(git -C "$work" config core.hooksPath)
  out=$(d "$work" hooks)
  check "hooks: freshly installed: ok" "ok hooks: Peal's git gates are installed
doctor: 0 problem(s)" "$out"

  rm -f "$dir/commit-msg"
  out=$(d "$work" hooks)
  check "hooks: a missing stub: FAIL" "yes" "$([[ "$out" == *"FAIL hooks: missing or not executable:"*"commit-msg"* ]] && echo yes)"
  (cd "$work" && "$PEAL" hooks install >/dev/null)

  printf '\n# tampered\n' >>"$dir/pre-push"
  out=$(d "$work" hooks)
  check "hooks: a stale stub: FAIL" "yes" "$([[ "$out" == *"FAIL hooks: stale, not the plugin's current stub:"*"pre-push"* ]] && echo yes)"
}

# ----------------------------------------------------------------------------------- gh --

gh_cases() {
  local work out nogh

  work=$(repo)
  newpeal "$work"
  printf 'storage:\n  kind: files\n' >"$work/.peal/config.yml"
  out=$(d "$work" gh)
  check "gh: files storage: skip" "skip gh: storage.kind is files, not issues
doctor: 0 problem(s)" "$out"

  printf 'storage:\n  kind: issues\n  issues:\n    repo: acme/widgets\n' >"$work/.peal/config.yml"
  nogh=$(no_gh_path)
  out=$(cd "$work" && env PATH="$nogh" "$PEAL" doctor gh)
  check "gh: not installed: FAIL" "FAIL gh: gh is not installed
  fix: install the GitHub CLI (https://cli.github.com)
doctor: 1 problem(s)" "$out"

  fake_github "$work"
  : >"$FAKE_GH/no-auth"
  out=$(d "$work" gh)
  check "gh: not logged in: FAIL" "yes" "$([[ "$out" == *"FAIL gh: gh is not logged in:"* ]] && echo yes)"

  rm -f "$FAKE_GH/no-auth"
  out=$(d "$work" gh)
  check "gh: installed and logged in: ok" "ok gh: gh is installed and logged in
doctor: 0 problem(s)" "$out"
}

# ------------------------------------------------------------------------------ claims --

claims_cases() {
  local work dir out

  work=$(repo)
  newpeal "$work"
  dir=$(dirname "$work")/work-wt

  put "$work" backlog 0001 released-one
  put "$work" backlog 0002 dirty-one
  put "$work" backlog 0003 not-landed-one
  (cd "$work" && "$PEAL" claim 0001 >/dev/null 2>&1)
  (cd "$work" && "$PEAL" claim 0002 >/dev/null 2>&1)
  (cd "$work" && "$PEAL" claim 0003 >/dev/null 2>&1)

  # 0001 and 0002 land on main; 0003 does not.
  for slug in 0001-released-one 0002-dirty-one; do
    git -C "$work" pull -q --rebase origin main 2>/dev/null
    mkdir -p "$work/tasks/done"
    git -C "$work" mv "tasks/backlog/$slug.md" tasks/done/
    git -C "$work" commit -q -m "land $slug"
  done
  git -C "$work" push -q origin main 2>/dev/null

  echo x >"$dir/0002-dirty-one/x"
  rm -rf "$dir/0003-not-landed-one"

  out=$(d "$work" claims)
  check "claims: a claim that could be released" "yes" \
    "$([[ "$out" == *"FAIL claims: task 0001's claim could be released (ok)"* ]] && echo yes)"
  check "claims: a landed, dirty claim" "yes" \
    "$([[ "$out" == *"FAIL claims: task 0002 landed, but its worktree holds uncommitted changes"* ]] && echo yes)"
  check "claims: not landed, no such FAIL" "" "$(printf '%s\n' "$out" | grep 'task 0003' || true)"
  check "claims: a prunable worktree" "yes" \
    "$([[ "$out" == *"FAIL claims: the worktree at $dir/0003-not-landed-one is prunable"* ]] && echo yes)"
  check "claims: three problems" "doctor: 3 problem(s)" "$(printf '%s\n' "$out" | tail -n1)"
}

# ----------------------------------------------------------------------------- belfry --

belfry_cases() {
  local work out home real marker

  work=$(repo)
  newpeal "$work"
  out=$(d "$work" belfry)
  check "belfry: no .belfry.yml: skip" "skip belfry: no .belfry.yml here
doctor: 0 problem(s)" "$out"

  printf 'tasks:\n  backend: github-issues\n' >"$work/.belfry.yml"
  out=$(d "$work" belfry)
  check "belfry: not the commands backend: skip" "yes" \
    "$([[ "$out" == *"skip belfry: tasks.backend is 'github-issues', not commands"* ]] && echo yes)"

  # A command that fails: an unknown flag peal_list itself refuses.
  cat >"$work/.belfry.yml" <<'EOF'
tasks:
  backend: commands
  commands:
    list: .peal/peal list --frobnicate
EOF
  out=$(d "$work" belfry)
  check "belfry: a command that fails" "yes" \
    "$([[ "$out" == *"FAIL belfry.list: .peal/peal list --frobnicate failed"* ]] && echo yes)"

  # A non-Peal command: skipped, never run (a marker file must not appear).
  marker="$work/marker"
  cat >"$work/.belfry.yml" <<EOF
tasks:
  backend: commands
  commands:
    list: touch $marker
EOF
  out=$(d "$work" belfry)
  check "belfry: non-Peal command: skip" "yes" \
    "$([[ "$out" == *"skip belfry.list: not Peal's command, not run"* ]] && echo yes)"
  check "belfry: non-Peal command never runs" "0" "$([ -e "$marker" ] && echo 1 || echo 0)"

  # A command whose shape is wrong: board through a fake Peal that prints one bad line.
  cp "$PEAL_ROOT/templates/launcher" "$work/.peal/peal"
  home=$(scratch_dir)
  real="$home/plugins/cache/peal/peal/1.0.0"
  fake_peal "$real" 1.0.0
  cat >"$work/.belfry.yml" <<'EOF'
tasks:
  backend: commands
  commands:
    board: .peal/peal board
EOF
  out=$(launcher_doctor "$work" "$home" belfry)
  check "belfry: a bad shape" "yes" \
    "$([[ "$out" == *"FAIL belfry.board: .peal/peal board did not print the shape Belfry expects"* ]] && echo yes)"
}

# -------------------------------------------------------------------------- structural --

structural_cases() {
  local work out

  work=$(repo)
  newpeal "$work"

  out=$(d "$work" bogus)
  check "doctor: an unknown check exits 2" "2:peal: doctor: no check 'bogus' (config version hooks gh claims belfry)" "$?:$(d "$work" bogus 2>&1 >/dev/null)"

  out=$(cd / && env GIT_CEILING_DIRECTORIES=/ "$PEAL" doctor 2>&1)
  check "doctor: outside a git repository exits 2" "yes" \
    "$([[ "$out" == *"not inside a git repository"* ]] && echo yes)"

  local nopeal
  nopeal=$(scratch_dir)
  git -C "$nopeal" init -q
  check_fails "doctor: no .peal/ exits 2" 2 "no .peal/ here" at "$nopeal" "$PEAL" doctor

  # peal doctor hooks: only hooks is reported.
  printf 'bogus-key: 1\nstages: [tasks, guardrails]\n' >"$work/.peal/config.yml"
  out=$(d "$work" hooks)
  check "doctor hooks: only hooks lines" "yes" \
    "$(printf '%s\n' "$out" | grep -vq '^\(ok\|FAIL\|skip\) hooks\|^  fix:\|^doctor:' && echo no || echo yes)"

  # A broken config makes every dependent check skip.
  printf 'storage:\n  kind: issues\n' >"$work/.peal/config.yml"
  git config -f "$work/.git/config" core.hooksPath >/dev/null 2>&1 || true
  echo 'bogus: 1' >>"$work/.peal/config.yml"
  out=$(d "$work")
  check "doctor: broken config, hooks skips" "yes" "$([[ "$out" == *"skip hooks: the config does not load"* ]] && echo yes)"
  check "doctor: broken config, gh skips" "yes" "$([[ "$out" == *"skip gh: the config does not load"* ]] && echo yes)"
  check "doctor: broken config, claims skips" "yes" "$([[ "$out" == *"skip claims: the config does not load"* ]] && echo yes)"

  rm -f "$work/.peal/config.yml"
}

for_each_awk healthy_files
for_each_awk healthy_issues
for_each_awk config_cases
for_each_awk version_cases
for_each_awk hooks_cases
for_each_awk gh_cases
for_each_awk claims_cases
for_each_awk belfry_cases
for_each_awk structural_cases
finish
