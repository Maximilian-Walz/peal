#!/usr/bin/env bash
# shellcheck disable=SC2016 # literal text, patterns and sed scripts with backticks and $
# Harness for the documentation a newcomer reads: README.md, CONTRIBUTING.md and docs/
# (not docs/milestones/, docs/decisions/, which are records):
#
#   bash tools/docs.test.sh
#
# What it checks, so an example copied from a document works:
# - every `peal <sub>` in a code span, and every line of a fenced block that starts with
#   `$ peal <sub>`, `peal <sub>` or `.peal/peal <sub>`, names a subcommand of `peal --help`;
# - every `/peal:<cmd>` has a plugin/commands/<cmd>.md;
# - every relative Markdown link resolves, and so does its #anchor;
# - a fenced block right after a marker comment is exercised:
#     <!-- docs-check: config -->   loads through `peal config` in a scratch repository
#     <!-- docs-check: run -->      its `$ ` lines run there, and the output lines quoted
#                                   under each appear in its output (a line ending in " …"
#                                   matches by its start)
#     <!-- docs-check: shape -->    its `filed`, `claimed` and `closed` lines have the shape
#                                   the commands print
#     <!-- docs-check: install -->  its `/plugin` lines match the marketplace
# Then negative cases on scratch copies: each mistake must be reported.
# No network. bash and awk only.
set -uo pipefail
# shellcheck source=../plugin/lib/test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../plugin/lib/test-lib.sh"

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
peal_bin=$REPO/plugin/bin/peal

# A directory with a `peal` that runs this checkout's CLI, for the blocks that run it.
bindir=$(scratch_dir)
printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$peal_bin" >"$bindir/peal"
chmod +x "$bindir/peal"

known=$("$peal_bin" --help | awk '/^  [a-z]/ { print $1 }' | sort -u)

# scratch_repo -> a git repository with one commit, cd-able.
scratch_repo() {
  local dir
  dir=$(scratch_dir)
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email docs@example.invalid
  git -C "$dir" config user.name docs
  git -C "$dir" commit -q --allow-empty -m init
  printf '%s\n' "$dir"
}

# doc_files ROOT -> the documents checked, relative to ROOT.
doc_files() {
  (cd "$1" && {
    ls README.md CONTRIBUTING.md 2>/dev/null
    find docs -name '*.md' -not -path 'docs/milestones/*' -not -path 'docs/decisions/*' | sort
  })
}

# facts FILE -> lines "kind<TAB>line<TAB>text": sub (a peal subcommand named), slash (a
# /peal: command), link (a relative link target), head (a heading's anchor).
facts() {
  awk '
    function slug(h) {
      h = tolower(h)
      gsub(/`/, "", h)
      gsub(/[^a-z0-9 _-]/, "", h)
      gsub(/ /, "-", h)
      return h
    }
    function cmdword(s,   w) {
      if (s ~ /^(\.peal\/)?peal [a-z]/) {
        sub(/^(\.peal\/)?peal /, "", s)
        split(s, w, /[^a-z-]/)
        print "sub\t" NR "\t" w[1]
      }
    }
    function scan(s,   rest, t) {
      rest = s
      while (match(rest, /\/peal:[a-z]+(-[a-z]+)*/)) {
        t = substr(rest, RSTART + 6, RLENGTH - 6)
        print "slash\t" NR "\t" t
        rest = substr(rest, RSTART + RLENGTH)
      }
    }
    /^```/ { fence = !fence; next }
    fence {
      scan($0)
      t = $0
      sub(/^\$ /, "", t)
      cmdword(t)
      next
    }
    {
      scan($0)
      n = split($0, parts, "`")
      for (i = 2; i <= n; i += 2) cmdword(parts[i])
      if ($0 ~ /^#+ /) {
        h = $0
        sub(/^#+ /, "", h)
        print "head\t" NR "\t" slug(h)
      }
      rest = ""
      for (i = 1; i <= n; i += 2) rest = rest parts[i] " "
      while (match(rest, /\]\([^)]*\)/)) {
        t = substr(rest, RSTART + 2, RLENGTH - 3)
        print "link\t" NR "\t" t
        rest = substr(rest, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

# blocks FILE OUTDIR -> each fenced block after a docs-check marker, written as
# OUTDIR/<line>.<kind>.
blocks() {
  awk -v out="$2" '
    /^<!-- docs-check: [a-z]+ -->$/ { kind = $3; pending = 1; next }
    /^```/ {
      if (open) { close(path); open = 0; next }
      if (pending) { path = out "/" NR "." kind; printf "" > path; open = 1; pending = 0 }
      next
    }
    open { print > path; next }
    NF { pending = 0 }
  ' "$1"
}

# expect_output BLOCK -> runs a block's $ lines in the current directory, prints a
# problem for each quoted line missing from the output of its command.
run_block() {
  local block=$1 cmd='' out='' line want
  flush() {
    [ -n "$cmd" ] || return 0
    out=$(PATH="$bindir:$PATH" PEAL_ROOT=$REPO/plugin bash -c "$cmd" 2>&1)
    while IFS= read -r want; do
      [ -n "$want" ] || continue
      if [[ "$want" == *" …" ]]; then
        grep -q -F -- "${want% …}" <<<"$out" || printf 'run: '%s' did not print a line starting %s\n' "$cmd" "$want"
      else
        grep -q -x -F -- "$want" <<<"$out" || printf 'run: '%s' did not print the line %s\n' "$cmd" "$want"
      fi
    done <<<"$expected"
  }
  expected=''
  while IFS= read -r line; do
    if [[ "$line" == '$ '* ]]; then
      flush
      cmd=${line#\$ }
      expected=''
    else
      expected+="$line"$'\n'
    fi
  done <"$block"
  flush
}

# shape_block BLOCK -> problems for the filed, claimed and closed lines that are not what
# the commands print. Real lines come from a repository with a remote, made here.
shape_block() {
  local block=$1 dir remote real line
  dir=$(scratch_repo)
  remote=$(scratch_dir)
  (
    cd "$dir" || exit 1
    export PATH="$bindir:$PATH" PEAL_ROOT=$REPO/plugin
    peal init --stage tasks >/dev/null
    git add -A && git commit -qm "chore(peal): set up"
    git clone -q --bare . "$remote"
    git remote add origin "$remote"
    git update-ref refs/remotes/origin/main HEAD
    git branch -q -u origin/main
    printf -- '---\nsize: S\n---\n\n# NNNN — Add a health check\n\nIntent.\n\n## Raw\n\n> a health check\n' |
      peal idea health-check >"$dir/.idea-out" 2>&1
    peal claim 0001 >"$dir/.claim-out" 2>&1
  )
  while IFS= read -r line; do
    case $line in
      filed\ *)
        real=$(cat "$dir/.idea-out")
        [ "$line" == "$real" ] || printf 'shape: the filed line is\n  %s\nbut peal idea prints\n  %s\n' "$line" "$real"
        ;;
      claimed\ *)
        real=$(cat "$dir/.claim-out")
        [ "$(cut -d' ' -f1-3 <<<"$line")" == "$(cut -d' ' -f1-3 <<<"$real")" ] &&
          [ "$(basename "$(cut -d' ' -f4 <<<"$line")")" == "$(basename "$(cut -d' ' -f4 <<<"$real")")" ] ||
          printf 'shape: the claimed line is\n  %s\nbut peal claim prints\n  %s\n' "$line" "$real"
        ;;
      closed\ *)
        grep -q -E '^closed [0-9]{4}: pull request #[0-9]+ https?://[^ ]+$' <<<"$line" ||
          printf 'shape: the closed line is not "closed NNNN: pull request #N URL": %s\n' "$line"
        grep -q -F 'closed $PEAL_ID: pull request #$pr $url' "$REPO/plugin/lib/close.sh" ||
          printf 'shape: peal close no longer prints "closed ID: pull request #N URL"\n'
        ;;
    esac
  done <"$block"
}

# install_block BLOCK ROOT -> problems for /plugin lines that do not match the marketplace.
install_block() {
  local block=$1 root=$2 want_repo name market line
  market=$root/.claude-plugin/marketplace.json
  want_repo=$(sed -n 's|.*"homepage": *"https://github.com/\([^"]*\)".*|\1|p' "$market")
  name=$(sed -n 's/^  "name": *"\([^"]*\)".*/\1/p' "$market")
  while IFS= read -r line; do
    case $line in
      '/plugin marketplace add '*)
        [ "${line#/plugin marketplace add }" == "$want_repo" ] ||
          printf 'install: %s, but the marketplace is %s\n' "$line" "$want_repo"
        ;;
      '/plugin install '*)
        [ "${line#/plugin install }" == "peal@$name" ] ||
          printf 'install: %s, but the plugin is peal@%s\n' "$line" "$name"
        grep -q -F 'install peal@peal' "$root/tools/install.test.sh" ||
          printf 'install: tools/install.test.sh no longer installs peal@peal\n'
        ;;
    esac
  done <"$block"
}

# anchors FILE -> the heading anchors of a Markdown file.
anchors() { facts "$1" | awk -F'\t' '$1 == "head" { print $3 }'; }

# docs_problems ROOT -> one line per problem in the documents under ROOT.
docs_problems() {
  local root=$1 file kind ln text target path anchor tmp b
  tmp=$(scratch_dir)
  while IFS= read -r file; do
    while IFS=$'\t' read -r kind ln text; do
      case $kind in
        sub)
          grep -q -x -F -- "$text" <<<"$known" || printf '%s:%s: peal %s is not a subcommand\n' "$file" "$ln" "$text"
          ;;
        slash)
          [ -f "$root/plugin/commands/$text.md" ] || printf '%s:%s: /peal:%s has no plugin/commands/%s.md\n' "$file" "$ln" "$text" "$text"
          ;;
        link)
          case $text in http*:// | mailto:* | https://* | http://*) continue ;; esac
          target=${text%%#*}
          anchor=
          [[ "$text" == *'#'* ]] && anchor=${text#*#}
          if [ -z "$target" ]; then
            path=$root/$file
          else
            path=$root/$(dirname "$file")/$target
          fi
          if [ ! -e "$path" ]; then
            printf '%s:%s: the link %s does not resolve\n' "$file" "$ln" "$text"
          elif [ -n "$anchor" ]; then
            anchors "$path" | grep -q -x -F -- "$anchor" || printf '%s:%s: the anchor of %s does not exist\n' "$file" "$ln" "$text"
          fi
          ;;
      esac
    done < <(facts "$root/$file")

    mkdir -p "$tmp/$file"
    blocks "$root/$file" "$tmp/$file"
    for b in "$tmp/$file"/*; do
      [ -e "$b" ] || continue
      ln=$(basename "$b")
      kind=${ln##*.}
      ln=${ln%.*}
      case $kind in
        config)
          local repo
          repo=$(scratch_repo)
          mkdir -p "$repo/.peal"
          cp "$b" "$repo/.peal/config.yml"
          (cd "$repo" && PEAL_ROOT=$REPO/plugin "$peal_bin" config >/dev/null 2>"$repo/.err") ||
            printf '%s:%s: the config block does not load: %s\n' "$file" "$ln" "$(cat "$repo/.err")"
          ;;
        run)
          (cd "$(scratch_repo)" && run_block "$b") | sed "s|^|$file:$ln: |"
          ;;
        shape) shape_block "$b" | sed "s|^|$file:$ln: |" ;;
        install) install_block "$b" "$root" | sed "s|^|$file:$ln: |" ;;
        *) printf '%s:%s: unknown docs-check marker %s\n' "$file" "$ln" "$kind" ;;
      esac
    done
  done < <(doc_files "$root")
}

# The documents as they are.
check "the documents pass their checks" "" "$(docs_problems "$REPO")"
files=$(doc_files "$REPO")
check "the documents are checked" "CONTRIBUTING.md README.md docs/getting-started.md" \
  "$(grep -x -F -e README.md -e CONTRIBUTING.md -e docs/getting-started.md <<<"$files" | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
check "no milestone or decision record is checked" "0" "$(grep -c -E '^docs/(milestones|decisions)/' <<<"$files")"
check "every marker kind is used" "config install run shape" \
  "$(grep -h -o -E 'docs-check: [a-z]+' "$REPO/README.md" "$REPO/CONTRIBUTING.md" "$REPO"/docs/*.md | sed 's/docs-check: //' | sort -u | tr '\n' ' ' | sed 's/ $//')"

# Negative cases, on a copy of the documents.
mutant() { # mutant FILE SED-SCRIPT -> problems of a copy with FILE edited
  local copy
  copy=$(scratch_dir)
  cp -R "$REPO/README.md" "$REPO/CONTRIBUTING.md" "$REPO/LICENSE" "$REPO/SECURITY.md" "$REPO/docs" "$copy/"
  mkdir -p "$copy/.claude-plugin" "$copy/tools"
  cp "$REPO/.claude-plugin/marketplace.json" "$copy/.claude-plugin/"
  cp "$REPO/tools/install.test.sh" "$copy/tools/"
  ln -s "$REPO/plugin" "$copy/plugin"
  sed -i -E "$2" "$copy/$1"
  docs_problems "$copy"
}
has() { # has NAME OUTPUT PATTERN
  if grep -q -F -- "$3" <<<"$2"; then check "$1" ok ok; else check "$1" "a problem containing: $3" "$2"; fi
}

has "a renamed subcommand is reported" "$(mutant CONTRIBUTING.md 's/`peal check`/`peal nosuchsub`/')" "peal nosuchsub is not a subcommand"
has "a subcommand in a fenced block is reported" "$(mutant docs/getting-started.md 's/^\$ peal next$/$ peal nosuchsub/')" "peal nosuchsub is not a subcommand"
has "an unknown command is reported" "$(mutant README.md 's|`/peal:setup`|`/peal:nosuch`|')" "/peal:nosuch has no"
has "a broken link is reported" "$(mutant README.md 's|\(docs/getting-started.md\)|(docs/nowhere.md)|')" "docs/nowhere.md does not resolve"
has "a broken anchor is reported" "$(mutant README.md 's|\(docs/getting-started.md\)|(docs/getting-started.md#nowhere)|')" "the anchor"
has "an unknown config key is reported" "$(mutant docs/getting-started.md 's/^stages: \[tasks, guardrails\]$/nosuchkey: 1/')" "the config block does not load"
has "a quoted output that changed is reported" "$(mutant docs/getting-started.md 's/^created .peal\/peal$/created .peal\/launcher/')" "did not print the line created .peal/launcher"
has "a wrong filed line is reported" "$(mutant README.md 's/size: S/size: L/')" "the filed line is"
has "a wrong install line is reported" "$(mutant README.md 's|install peal@peal|install peal@other|')" "the plugin is peal@peal"

finish
