# shellcheck shell=bash
# Ideas found while working a task: on a task branch they wait in a queue of that
# worktree, in its git directory (never the work tree, so no commit or dirty check sees
# it), and the task's close files them all in one push; anywhere else they are filed at
# once. A queued idea is checked when queued, offline, and again against the main branch
# when it is filed.

PEAL_IDEA_QUEUE=peal-ideas
PEAL_IDEAS_FILED=peal-ideas-filed

# peal_idea_queue -> the path of this worktree's queue.
peal_idea_queue() {
  printf '%s/%s\n' "$(git rev-parse --git-dir)" "$PEAL_IDEA_QUEUE"
}

# peal_idea_task -> the task id of the branch checked out here; status 1 on no task branch.
peal_idea_task() {
  peal_store_branch_task
}

# peal_idea SLUG [--now] -> the task text on stdin queued on a task branch, else (or with
# --now) filed at once through the storage. "queued SLUG — milestone: M, plan: P, size: S
# — "Title"" or the storage's "filed ..." line.
peal_idea() {
  local hint=$1 now=${2-} slug tmp summary status=0
  case $now in "" | --now) ;; *) peal_err "idea: unknown option $now"; return 2 ;; esac
  slug=$(peal_slugify "$hint") || return 2
  if [ "$now" = --now ] || ! peal_idea_task >/dev/null; then
    peal_store_create plain "" "$hint"
    return
  fi
  tmp=$(mktemp -d) || return 2
  cat >"$tmp/text"
  if grep -q -e "^$PEAL_TASK_DELIMITER\$" -e '^-----IDEA ' "$tmp/text"; then
    peal_err "idea: a line '$PEAL_TASK_DELIMITER' or '-----IDEA ...' would split the queue; reword it"
    status=2
  elif [ ! -s "$tmp/text" ]; then
    peal_err "idea: no text on stdin"
    status=2
  fi
  if [ $status = 0 ]; then
    peal_check_context >"$tmp/context"
    if summary=$(PEAL_CHECK_OFFLINE=1 peal_task_check "$tmp/text" plain "$slug" "$tmp/context"); then
      { printf -- '-----IDEA %s-----\n' "$slug"; cat "$tmp/text"; } >>"$(peal_idea_queue)"
      PEAL_TITLE=$(peal_text_title NNNN <"$tmp/text") awk -F '\t' -v slug="$slug" '
        function f(v) { return v == "" ? "-" : v }
        { printf "queued %s — milestone: %s, plan: %s, size: %s — \"%s\"\n", slug, f($1), f($2), f($3), ENVIRON["PEAL_TITLE"] }' <<<"$summary"
    else
      status=2
    fi
  fi
  rm -rf "$tmp"
  return $status
}

# peal_ideas [--flush | --export | --drop N|--all] -> the queued ideas, "slug<TAB>title"
# each; --export prints the queue as Markdown, the ideas' own texts in full, ready to be
# read or quoted by hand when filing is not possible; --drop N (its 1-based position in
# this listing) or --drop --all removes ideas from the queue, each announced as "dropped
# slug — "title""; --flush files them all as found in this branch's task, in one push
# where the storage can (a failure files none), and takes off the queue exactly those
# filed; the storage's "filed ..." lines are kept in the worktree's git directory too
# (peal-ideas-filed), for the pull request.
peal_ideas() {
  local queue task slugs out status filed which total
  queue=$(peal_idea_queue)
  case ${1-} in
    "")
      [ -s "$queue" ] || return 0
      awk '
        /^-----IDEA .*-----$/ { slug = substr($0, 11, length($0) - 15); want = 1; next }
        want && /^# / { t = $0; sub(/^# NNNN — /, "", t); print slug "\t" t; want = 0 }' "$queue"
      ;;
    --export)
      [ -s "$queue" ] || return 0
      awk '
        /^-----IDEA .*-----$/ { if (n++) print ""; next }
        { print }' "$queue"
      ;;
    --drop)
      which=${2-}
      case $which in
        --all) ;;
        '' | *[!0-9]* | 0) peal_err "ideas: --drop needs a number (1-based) or --all"; return 2 ;;
      esac
      if [ ! -s "$queue" ]; then
        echo "no queued ideas"
        return 0
      fi
      if [ "$which" != --all ]; then
        total=$(grep -c '^-----IDEA .*-----$' "$queue")
        if [ "$which" -gt "$total" ]; then
          peal_err "ideas: no idea $which queued ($total queued)"
          return 2
        fi
        awk -v which="$which" -v tmp="$queue.$$" '
          function say() { if (drop) printf "dropped %s — \"%s\"\n", slug, title }
          /^-----IDEA .*-----$/ {
            say()
            idx++; slug = substr($0, 11, length($0) - 15); title = ""
            drop = (idx == which + 0)
            if (!drop) print > tmp
            next
          }
          { if (title == "" && /^# /) { title = $0; sub(/^# NNNN — /, "", title) }
            if (!drop) print > tmp }
          END { say() }' "$queue"
        if [ -e "$queue.$$" ]; then mv -f "$queue.$$" "$queue"; else rm -f "$queue"; fi
      else
        awk '
          function say() { if (slug != "") printf "dropped %s — \"%s\"\n", slug, title }
          /^-----IDEA .*-----$/ { say(); slug = substr($0, 11, length($0) - 15); title = ""; next }
          title == "" && /^# / { title = $0; sub(/^# NNNN — /, "", title) }
          END { say() }' "$queue"
        rm -f "$queue"
      fi
      ;;
    --flush)
      if [ ! -s "$queue" ]; then
        echo "no queued ideas"
        return 0
      fi
      task=$(peal_idea_task) || { peal_err "ideas: not on a task branch"; return 2; }
      slugs=$(sed -n 's/^-----IDEA \(.*\)-----$/\1/p' "$queue")
      # shellcheck disable=SC2086 # slugs are kebab-case words
      out=$(awk -v delim="$PEAL_TASK_DELIMITER" '
        /^-----IDEA .*-----$/ { if (n++) print delim; next }
        { print }' "$queue" | peal_store_create batch "$task" $slugs)
      status=$?
      [ -z "$out" ] || printf '%s\n' "$out"
      filed=$(printf '%s\n' "$out" | grep -c '^filed ')
      [ "$filed" = 0 ] || printf '%s\n' "$out" | grep '^filed ' >>"$(git rev-parse --git-dir)/$PEAL_IDEAS_FILED"
      if [ $status = 0 ]; then
        rm -f "$queue"
      elif [ "$filed" != 0 ]; then
        # Filed one by one and stopped: the ones filed leave the queue, in their order.
        awk -v k="$filed" '/^-----IDEA .*-----$/ { n++ } n > k' "$queue" >"$queue.$$" && mv -f "$queue.$$" "$queue"
      fi
      return $status
      ;;
    *) peal_err "ideas: unknown option $1"; return 2 ;;
  esac
}
