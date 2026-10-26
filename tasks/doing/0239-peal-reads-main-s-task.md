---
milestone: m6
plan: required
priority: high
touches: [plugin/lib/common.sh, plugin/lib/store-files.sh, plugin/lib/decisions.sh, plugin/lib/apply.sh, plugin/lib/hostile.test.sh, docs/security.md]
---

# 0239 — Peal reads main's task, milestone and decision files as blobs, not through git archive

## Intent

`peal_extract_tree` (`plugin/lib/common.sh`) reads main's task, milestone and decision files through `git archive`, and `git archive` honours the archived tree's own `.gitattributes`. A pull request under the auto-merging `tasks/**` tier can therefore add `tasks/.gitattributes` with `* export-subst` and smuggle `$Format:...$` placeholders into a task file: the committed blob holds no new key, yet after expansion the board reads one (reproduced: the blob line `milestone: m1$Format:%nmerge%x3a auto$` reads as `merge: auto` on `peal board`). With `export-ignore` the same kind of pull request hides task or milestone files from every reader. The fix makes what Peal reads exactly the committed blobs a reviewer and the merge gate saw: `peal_extract_tree` reads blobs (`git ls-tree -r -z` plus `git cat-file blob`, as `peal merge-gate` already does) for all its users (`_peal_files_scan` and the milestones in store-files.sh, the decisions index in decisions.sh, apply's milestones in apply.sh). The human also offers, as an alternative or addition, that `peal check` and the merge gate refuse a `.gitattributes` under the tasks, milestones and decisions folders. `docs/security.md` names the route and its fix, and `hostile.test.sh` proves an `export-subst` and an `export-ignore` attribute in each folder change nothing Peal reads.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
