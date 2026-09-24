# shellcheck shell=bash
# The storage interface (docs/design.md, "Storage"): where tasks live, kept apart from how
# a session works them. The `storage.kind` setting names the implementation, one file
# lib/store-<name>.sh defining these functions; the commands and the peal CLI call only
# them. `files` keeps tasks as files in the repository (their ids four digits, 0042),
# `issues` as the repository's GitHub issues (their ids the issue numbers, 42).
#
#   peal_store_list [--fetch] [--no-pr]
#       one list record per task, by id, tab-separated (lists joined with commas):
#         id state detail slug title milestone depends part-of size plan needs path ref pr url priority owner touches
#       state and detail as lib/task-state.awk derives them; path is the task's file,
#       url its page on a host (one of the two), ref the task's branch, pr its pull
#       request ("#21") when one is known, priority urgent, high or low (empty: normal),
#       owner human for a human task (empty: ai), touches the paths and globs the task
#       will likely change.
#   peal_store_read ID                     the task's text, from its branch or the main one
#   peal_store_create MODE ORIGIN SLUG...  new tasks from bodies on stdin; MODE plain,
#                                          split (ORIGIN the task split) or batch (ORIGIN
#                                          the task that found them)
#   peal_store_edit ID REASON [--dry-run]  an unclaimed task's text rewritten from stdin
#   peal_store_set_milestone ID [M]        its milestone set, or removed without M
#   peal_store_finish ID done              the task's own branch marks it done
#   peal_store_finish ID retired REASON    an unclaimed task retired
#   peal_store_defer ID REASON TEXT [--dry-run]
#                                          the claim checked out here given back: the
#                                          task's text from the file TEXT, REASON noted,
#                                          written back under the same id; refused while
#                                          the branch holds work
#   peal_store_close_text ID               the file holding the Outcome of task ID, whose
#                                          branch is checked out here (relative to the
#                                          top, or absolute); status 1 if there is none
#   peal_store_comment ID TEXT             a dated line in the task's notes
#   peal_store_milestones                  peal_ms_load's lines, as the storage holds them
#   peal_store_milestone_text ID           the milestone's text: its file, its description
#   peal_store_milestone_state ID STATE REASON REVIEW
#                                          the milestone made STATE (done, parked, open),
#                                          REASON why a parked one waits, the text of the
#                                          file REVIEW (or "") added as its review; for
#                                          files, with none current afterwards, the first
#                                          open one by order made current. A milestone in
#                                          that state already is left as it is.
#   peal_store_claim ID                    the task claimed into a worktree of its own
#                                          (PEAL_CLAIM_PATH), or its parked claim resumed;
#                                          status 3 for a claim that lost the race
#   peal_store_release ID                  the claim's worktree and branch removed, the tip
#                                          kept under refs/reaped/
#   peal_store_branch_task                 the id of the task whose branch is checked out
#                                          here; status 1 on any other branch
#   peal_store_session_task                "id<TAB>file" when this worktree holds its
#                                          task's claim, file a copy of the task's text
#                                          (relative to the top, or absolute); status 1
#                                          otherwise
#   peal_store_claim_worktrees             "id<TAB>branch<TAB>path" per worktree on a task
#                                          branch, its directory there or not
#   peal_store_local_branch ID             the local branch of task ID's claim; status 1
#                                          if there is none
#   peal_store_record ID WHAT FILE         the text of the task this worktree holds, as
#                                          its claim keeps it, replaced by FILE: what the
#                                          human agreed (WHAT: plan, notes) or a
#                                          revision, checked already (peal_record,
#                                          peal_revise)
#
# Everything above the storage (the read model's rules in task-state.awk, the board, the
# overview, the checks on a new task in task-check.awk, what a pool offers and which
# claims may be made or released in claim.sh) is the same for every implementation.

# peal_store_load -> the storage the settings name, its functions defined; status 2 for
# one there is not.
peal_store_load() {
  local storage
  peal_config_load || return 2
  storage=$(peal_config_get storage.kind) || return 2
  case $storage in
    files)
      # shellcheck source=store-files.sh
      . "$PEAL_ROOT/lib/store-files.sh"
      ;;
    issues)
      # shellcheck source=store-issues.sh
      . "$PEAL_ROOT/lib/store-issues.sh"
      ;;
    *)
      peal_err "storage '$storage' is not one Peal has (files, issues)"
      return 2
      ;;
  esac
}
