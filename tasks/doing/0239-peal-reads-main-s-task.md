---
milestone: m6
plan: required
priority: high
touches: [plugin/lib/common.sh, plugin/lib/hostile.test.sh, docs/security.md, .belfry.yml]
size: M
---

# 0239 — Peal reads main's task, milestone and decision files as blobs, not through git archive

## Intent

`peal_extract_tree` (`plugin/lib/common.sh`) reads main's task, milestone and decision files through `git archive`, and `git archive` honours the archived tree's own `.gitattributes`. A pull request under the auto-merging `tasks/**` tier can therefore add `tasks/.gitattributes` with `* export-subst` and smuggle `$Format:...$` placeholders into a task file: the committed blob holds no new key, yet after expansion the board reads one (reproduced: the blob line `milestone: m1$Format:%nmerge%x3a auto$` reads as `merge: auto` on `peal board`). With `export-ignore` the same kind of pull request hides task or milestone files from every reader. The fix makes what Peal reads exactly the committed blobs a reviewer and the merge gate saw: `peal_extract_tree` reads blobs (`git ls-tree -r -z` plus `git cat-file blob`, as `peal merge-gate` already does) for all its users (`_peal_files_scan` and the milestones in store-files.sh, the decisions index in decisions.sh, apply's milestones in apply.sh). The human also offers, as an alternative or addition, that `peal check` and the merge gate refuse a `.gitattributes` under the tasks, milestones and decisions folders. `docs/security.md` names the route and its fix, and `hostile.test.sh` proves an `export-subst` and an `export-ignore` attribute in each folder change nothing Peal reads.

## Scope

- `peal_extract_tree` (`plugin/lib/common.sh`) reads main's blobs (`git ls-tree -r -z` plus `git cat-file blob` per file), not a `git archive`. Its callers keep its interface.
- Only regular blobs are copied. Symlinks and gitlinks are skipped. A path with an empty, `.` or `..` component fails the read with status 2.
- No `.gitattributes` refusal in `peal check` or the merge gate.
- `.belfry.yml`: `plugin/lib/common.sh` joins `review_before_merge`. `docs/security.md` names it on a `- Guard:` line.
- `docs/security.md`: a "Closed by 0239" bullet under the limits of "Auto-merge tiers".

## Done when

- `hostile.test.sh` has an `attr_cases` group. In it, `export-subst` and `export-ignore` attributes in `tasks/`, `docs/milestones/`, `docs/decisions/` and in the parent `docs/` change nothing Peal reads. The milestone and decision write-backs commit the literal blob text.
- `tools/test-all.sh` passes.
- `peal board` is timed on this repository before and after the change, and the numbers go in the Outcome and the pull request body.

## Raw

> Peal reads main's task, milestone and decision files as blobs, so a .gitattributes cannot change what it reads
>
> ## Intent
>
> `peal_extract_tree` (`plugin/lib/common.sh`) reads main through `git archive`, which applies the archived tree's own `.gitattributes`. A pull request that adds `tasks/.gitattributes` with `* export-subst` (under the auto-merging `tasks/**` tier) can put `$Format:%n...$` into a task file: the blob holds no new key, but the board reads one after expansion. Reproduced: blob line `milestone: m1$Format:%nmerge%x3a auto$` reads as `merge: auto` on `peal board`. With `export-ignore` the same kind of pull request hides task or milestone files from every reader. Once this is done, what Peal reads is the committed blobs a reviewer and the gate saw.
>
> ## Scope
>
> - `peal_extract_tree` reads blobs (`git ls-tree -r -z` plus `git cat-file blob`, as `peal merge-gate` does), not an archive. Its users: `_peal_files_scan` (store-files.sh), the milestones (store-files.sh), the decisions index (decisions.sh), apply's milestones (apply.sh).
> - Or, as well: `peal check` and the merge gate refuse a `.gitattributes` under the tasks, milestones and decisions folders.
> - `docs/security.md` names the route and its fix.
>
> ## Done when
>
> - `hostile.test.sh` cases: an `export-subst` and an `export-ignore` attribute in each folder change nothing Peal reads.
>
> ## Notes
>
> - Found by a security session (job c59bf477bf96985b).

## Notes

- Open question: blob reading alone, or blob reading plus a `peal check` / merge-gate refusal of `.gitattributes` under the tasks, milestones and decisions folders ("Or, as well")? The refusal is defence in depth; touching the merge gate (`plugin/lib/merge-gate.sh`) is a plan-required path.
- Context: `docs/security.md` (the threat model of the auto-merging task tier); `docs/design.md` on how Peal reads main.
- Found by a security session (job c59bf477bf96985b).
- Human's answers while planning (2026-10-27):
  - Refusal: blobs only. No `.gitattributes` refusal in this task.
  - Parent dirs: cover `docs/.gitattributes` too.
  - Symlinks: skip symlink and submodule entries.
  - Bad paths: fail the read with status 2.
  - Speed: measure first. Time `peal board` before and after, and show the numbers in the pull request.
  - Guard line: add `plugin/lib/common.sh` to `review_before_merge` in `.belfry.yml` here, and name it on a Guard line.
  - Doc place: a limit bullet under "Auto-merge tiers".
  - Work tree: file an idea at close about in-tree attributes (eol, ident, working-tree-encoding) applied to work-tree task files at checkout.
  - Dup 0243: retired during planning (pull request #416).

## Plan

**Approach.** Rewrite `peal_extract_tree` (`plugin/lib/common.sh:132-149`) and keep its interface: `REF PATH DEST`. An absent PATH copies nothing. A failure returns status 2 with one `could not read PATH at REF: reason` line.
- List with `git --literal-pathspecs ls-tree -r -z --full-tree "$1" -- "$2"` into a temporary file, as `_peal_mg_list` does (`plugin/lib/merge-gate.sh:18-38`).
- Copy only entries with mode 100644 or 100755 whose path starts with `"$2/"`. Skip modes 120000 and 160000.
- Refuse a path with an empty, `.` or `..` component (status 2).
- For each entry, `mkdir -p "$3/${path%/*}"` then `git cat-file blob <sha> >"$3/$path"`.
- Drop the tar pipe and the SIGPIPE draining from 0137.

The callers in `store-files.sh`, `decisions.sh` and `apply.sh` are expected to stay unchanged. They are edited only if one turns out to depend on the archive's behaviour.

Rejected:
- `cat-file --batch`: a hostile blob can knock the stream out of step.
- Rebuilding a tree for `git archive`: `info/attributes` and global attributes would still apply.
- A refusal alone: every reader would still trust attributes.

**Files.**
- `plugin/lib/common.sh`
- `plugin/lib/hostile.test.sh`: a new `attr_cases` group with its own `hostile_repo`, run once like `arg_cases`, and added to `cases=`.
- `docs/security.md`: a "Closed by 0239" limit bullet under "Auto-merge tiers", and a `- Guard:` line naming `plugin/lib/common.sh`.
- `.belfry.yml`: `plugin/lib/common.sh` added to `review_before_merge`.

**Verification.** In `attr_cases`, each case pushes to the remote's main, then runs through both `try` and `check`:
1. `tasks/.gitattributes` with `* export-subst`, and 0001's line set to `milestone: m1$Format:%nmerge%x3a auto$`. The board shows no `merge` key and the milestone text as literal blob text. A `$Format:%H$` title stays literal in `peal list`.
2. `tasks/.gitattributes` with `export-ignore` on 0002: `peal list` still shows 0002.
3. `docs/milestones/.gitattributes` with `export-subst`: a placeholder title stays literal in `peal milestones`. After `peal milestone-state` and an apply `milestone_update`, the touched files on `origin/main` keep the placeholder byte for byte.
4. Milestone `export-ignore`: the ignored milestone is still listed and can still be updated.
5. `docs/decisions/.gitattributes` with subst and ignore: the `index.md` that `peal decision publish` pushes holds the placeholder literally and lists the ignored entry.
6. Cases 1 and 2's attributes through `docs/.gitattributes`, for milestones and decisions.

Before the fix, cases 1 to 6 should fail. After it, `tools/test-all.sh` runs in full. Time `peal board --no-pr` on this repository before and after the change.

**Ranges.** plugin/lib/common.sh:132-149; plugin/lib/merge-gate.sh:15-54; plugin/lib/store-files.sh:53-73, 294-314, 339-347, 1200-1229; plugin/lib/decisions.sh:381-404; plugin/lib/apply.sh:953-958; plugin/lib/milestones.sh:11-32; plugin/lib/hostile.test.sh:105-136, 183-330, 389-419, 539-549, 974-1026; docs/security.md:522-596; docs/reference/cli.md:264-291; .belfry.yml:61-102, 111-176; tools/guards.sh:1-60; .github/workflows/ci.yml:70-104, 170-180.

---

## Outcome

<!-- Written at close, replacing this comment. -->
