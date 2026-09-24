# shellcheck shell=bash
# The storage interface (docs/design.md, "Storage"): where tasks live, kept apart from how
# a session works them. The `storage` setting names the implementation, one file
# lib/store-<name>.sh defining these functions; the commands and the peal CLI call only
# them. `files`, task files in the repository, is the one there is.
#
#   peal_store_list [--fetch] [--no-pr]
#       one list record per task, by id, tab-separated (lists joined with commas):
#         id state detail slug title milestone depends part-of size plan needs path ref pr
#       state and detail as lib/task-state.awk derives them; ref is the task's branch,
#       pr its pull request ("#21") when one is known.
#   peal_store_read ID                     the task's text, from its branch or the main one
#   peal_store_create MODE ORIGIN SLUG...  new tasks from bodies on stdin; MODE plain,
#                                          split (ORIGIN the task split) or batch (ORIGIN
#                                          the task that found them)
#   peal_store_edit ID REASON [--dry-run]  an unclaimed task's text rewritten from stdin
#   peal_store_set_milestone ID [M]        its milestone set, or removed without M
#   peal_store_finish ID done              the task's own branch marks it done
#   peal_store_finish ID retired REASON    an unclaimed task retired
#   peal_store_comment ID TEXT             a dated line in the task's notes
#   peal_store_milestones                  peal_ms_load's lines, as the storage holds them
#   peal_store_claim ID                    the task claimed into a worktree of its own
#                                          (PEAL_CLAIM_PATH), or its parked claim resumed;
#                                          status 3 for a claim that lost the race
#   peal_store_release ID                  the claim's worktree and branch removed, the tip
#                                          kept under refs/reaped/
#
# Everything above the storage (the read model's rules in task-state.awk, the board, the
# overview, the checks on a new task in task-check.awk, what a pool offers and which
# claims may be made or released in claim.sh) is the same for every implementation.

# peal_store_load -> the storage the settings name, its functions defined; status 2 for
# one there is not.
peal_store_load() {
  local storage
  peal_config_load || return 2
  storage=$(peal_config_get storage) || return 2
  case $storage in
    files)
      # shellcheck source=store-files.sh
      . "$PEAL_ROOT/lib/store-files.sh"
      ;;
    *)
      peal_err "storage '$storage' is not one Peal has (files)"
      return 2
      ;;
  esac
}
