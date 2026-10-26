---
milestone: m6
plan: required
depends: []
part-of: 0180
size: M
touches: [plugin/lib/issues-text.awk, plugin/lib/issues-lib.awk, plugin/lib/store-issues.sh, plugin/lib/store-issues.test.sh, plugin/lib/fake-gh, plugin/lib/hostile.test.sh, plugin/commands/comment.md, docs/security.md, docs/reference/*.md, docs/milestones/m6.md]
---

# 0250 — An outsider's labelled issue with ## Plan does not read as PLAN agreed

## Intent

On the issues storage `origin` is never set, so `plan` comes from labels and a filled `## Plan` in the body reads as `agreed`; the re-label check covers edits after labelling, not a plan that was already in the body when the maintainer labelled the issue. Under plain Claude Code `/peal:work` then starts the implementer on the stranger's plan. When this is done a stranger's text in an issue does not turn into an agreed plan.

## Scope

- Issues storage only: a stranger's issue (opener not `writer()`) renders with its `## Plan` and `## Outcome` sections emptied, unless the body's last edit was by a non-author writer.
- Absorbs 0122: `peal comment --origin outsider` on the issues storage is refused before posting.
- Not in scope: rendering `origin: outsider` for issues; the `merge: auto agreed` line in a stranger's Notes (filed as an idea).

## Done when

- A stranger's labelled issue with a filled Plan and Outcome: `peal read` shows both headings with empty sections; claim then `peal work` gives `PLAN required`.
- The same issue with `plan: auto` or no plan label gives `PLAN auto`, never `agreed`.
- Edited by the author before labelling: still stripped. Edited by a non-author writer: kept, `PLAN agreed`.
- An OWNER's issue with a filled Plan still gives `PLAN agreed`.
- `peal record N plan` on a stranger's issue, then `peal work`: `PLAN agreed` (the fake gh records the editor).
- A trusted App's issue labelled `origin: outsider` with a Plan is stripped.
- `peal comment --origin outsider` on the issues storage exits 2 and posts nothing; a plain comment still posts.
- `store-issues.test.sh`, `hostile.test.sh`, `work.test.sh` and `commands.test.sh` pass.
- `docs/security.md` says the limit is closed and names the guard and its tests.

## Raw

> - Issues storage: an issue whose `author_association` is not owner, member or collaborator counts as `origin: outsider` in `_peal_issues_text` so `peal work` forces `PLAN required`, or its `## Plan` and `## Outcome` are stripped from the body unless the task is a writer's.
> - A test: an issue by a stranger whose body holds `## Plan` reads as `PLAN required`, not `agreed`.

Split from 0180

## Notes

- The origin's planner proposed this approach, agreed by the human as the direction of the split (the open questions below are still to settle with this piece's planner):
  - A stranger's issue is one whose opener is not `writer()` (`plugin/lib/issues-lib.awk`). `_peal_issues_text` (`plugin/lib/issues-text.awk`) empties its `## Plan` and `## Outcome` unless the body was last edited by a writer other than the author (`edit_writer`); `peal record` with the human's login is such an edit, so a recorded plan survives. The edits row already comes from `_peal_issues_edits_batch` in `_peal_issues_admitted`; keep it rather than a new GraphQL call.
  - Rendering the issue as `origin: outsider` alone does not help: `_peal_work_here` (`plugin/lib/work.sh:63-76`) still promotes a filled Plan to `agreed`. Stripping the Plan unconditionally breaks `peal record`, which writes the agreed plan into the body, and `peal work` re-reads it.
- Absorbs 0122: `peal comment --origin outsider` on the issues storage is dropped silently today (`peal_store_comment` in `plugin/lib/store-issues.sh` ignores `PEAL_COMMENT_0180`); refuse it up front as `create` does since 0094 (`plugin/lib/backlog.sh:157-164`). Retire 0122 into this task when it is claimed.
- Open questions for this piece's planner: IssueProof (does a plan count as agreed when the body was last edited by any writer, or never on a stranger's issue?), IssueOrigin (should the text also render `origin: outsider`, changing `docs/reference/tasks.md:52`?), Take0122 (is the comment still posted when the flag is refused? default: refuse before posting).
- `docs/security.md` should say this limit is closed, with the tests. Size: about 60-70 tool calls, M.
- 2026-10-26, the human's answers on the plan:
  - IssueProof: a stranger's Plan is kept when the body's last edit is by any non-author writer (peal record or a maintainer's UI edit).
  - IssueOrigin: no; the text does not render `origin: outsider`, `docs/reference/tasks.md` stays "files only".
  - Take0122: refuse before posting, nothing written.
  - KeepHeads: empty the sections, keep the headings and any `---` rule.
  - Retire0122: retire 0122 into 0250; `docs/milestones/m6.md` cites 0250 instead of 0122.
  - ReviseDrop: a revise/defer of a stranger's issue may drop the stranger's Plan/Outcome text from the body.
  - FakeEditor: the fake gh records `editor: "peal"` and `last_edited_at` on every body PATCH.
  - CommentDoc: add the new "not added" reason to `plugin/commands/comment.md` step 5.
  - NotesLine: a stranger's Notes line "merge: auto agreed ..." is out of scope; file an idea.

## Plan

Approach:
1. `_peal_issues_admitted` (`plugin/lib/store-issues.sh`): reset a global `PEAL_ADMIT_EDITS` at the start, set it to the issue's line of the edits row it already fetches from `_peal_issues_edits_batch`. No new GraphQL call.
2. `_peal_issues_text`: pass `-v apps="$PEAL_APPS"` and `-v edits="$PEAL_ADMIT_EDITS"` to `issues-text.awk`.
3. `plugin/lib/issues-text.awk`: `trusted = writer($6, $9, $5, apps)`. If not trusted, split the edits row; use it only when its field 1 equals `$1` (fail closed against a stale global); keep the sections only when `edit_writer(e[3], 0, e[5])` (editor non-empty and not the author). Otherwise drop every line under each exact `## Plan` and `## Outcome` heading (every occurrence) up to the next `## ` line, keeping the headings and bare `---` lines. A small helper in `issues-lib.awk` (e.g. `keeps_human_sections`) next to `edit_row_admitted` if it reads better.
4. `peal_store_comment`: at the top, before the login check and any post, refuse `PEAL_COMMENT_ORIGIN=outsider` with exit 2, in the style of `backlog.sh:157-164`: "comment: --origin outsider is not carried by the issues storage (origin is files only); nothing noted".
5. `plugin/lib/fake-gh`: a PATCH carrying `body` sets `editor: "peal"` and `last_edited_at` to now; header comment updated. Run the whole suite to confirm nothing else moves.
6. Docs: `docs/security.md` (the pre-labelling Plan/Outcome limit closed, Guard and Harness entries naming the tests), `docs/reference/storage.md` ("Who is admitted"), `docs/reference/cli.md` (`--origin outsider` refused on issues), `plugin/commands/comment.md` step 5 (new "not added" reason; keep `commands.test.sh:53` counts holding), `docs/milestones/m6.md:29-31` (0122 → 0250).

Rejected: rendering `origin: outsider` alone (`_peal_work_here` still promotes the Plan); stripping unconditionally (breaks `peal record`); a marker line (forgeable).

Verification: a new `stranger_plan` case in `plugin/lib/store-issues.test.sh` (with `issues_repo_label`, `--assoc NONE`) covering each Done when line; optionally one check in `hostile.test.sh` `issues_channels`' labelled half; then the whole `store-issues.test.sh`, `hostile.test.sh`, `work.test.sh` and `commands.test.sh`.

Ranges relied on:
- plugin/lib/issues-text.awk:1-66
- plugin/lib/issues-lib.awk:63-128
- plugin/lib/store-issues.sh:28-31, 237-339, 386-396, 690-769, 807-843, 870-885, 945-952, 1098-1118
- plugin/lib/work.sh:51-83, 143-196
- plugin/lib/task-text.sh:68-124
- plugin/lib/backlog.sh:150-164
- plugin/lib/store-files.sh:901-910
- plugin/bin/peal:564-578
- plugin/lib/fake-gh:10-29, 240-250, 395-434
- plugin/lib/store-issues.test.sh:155-165, 333-450, 723, 1143-1162
- plugin/lib/hostile.test.sh:588-696
- plugin/commands/comment.md:21-41
- plugin/commands/commands.test.sh:53
- docs/security.md:161-191, 336-425
- docs/reference/tasks.md:42,52
- docs/reference/storage.md:42-73
- docs/reference/cli.md:356-362
- docs/design.md:198-205
- docs/milestones/m6.md:1-36
- tasks/backlog/0122-comment-origin-issues-storage.md:1-40

---

## Outcome

On the issues storage, a stranger's issue now renders with its `## Plan` and `## Outcome` sections emptied. A stranger is an opener that is not `writer()`; that includes a trusted App's issue labelled `origin: outsider`. The headings and the `---` rule stay in place.

- **The exception.** The sections are kept when the body's last edit was made by a writer other than the author (`keeps_human_sections()` in `plugin/lib/issues-lib.awk`, which reuses `edit_writer()`). `peal record` is such an edit, so a plan the human agreed survives and reads back as `PLAN agreed`.
- **Where the edits row comes from.** It is the one `_peal_issues_admitted` already fetches, passed on as `PEAL_ADMIT_EDITS`; there is no new GraphQL call. A missing row, or one for another issue, strips (fails closed).
- **0122, absorbed.** `peal comment --origin outsider` on the issues storage now exits 2 before posting anything. Task 0122 was retired into this one on main.
- **Test harness.** The fake gh now records `editor: "peal"` and `last_edited_at` on a PATCH that carries a body, so the record round trip is tested.
- **Tests.** New cases `stranger_plan` and `comment_origin` in `plugin/lib/store-issues.test.sh`.
- **Docs.** `docs/security.md` says the limit is closed and names the guard and its tests. `docs/reference/storage.md`, `docs/reference/cli.md` and `plugin/commands/comment.md` say the same.
- **The milestone file.** `docs/milestones/m6.md` changes only to cite 0250 instead of the retired 0122, which the human agreed in the plan; no milestone content changes.

Decided with the human:
- A stranger's text does not render `origin: outsider`; the plan labels decide `plan`.
- Any writer's edit vouches for the whole body.
- A revise or defer of a stranger's issue may drop the stranger's Plan and Outcome text from the body.

Left for later:
- A stranger's `## Notes` line "merge: auto agreed ..." can still make close ask the reviewer for a merge-auto verdict. It grants nothing; filed as the idea `stranger-notes-merge-auto-line`.

Review: no blocking findings. The one small fix, a test for the no-plan-label case that never actually ran without a label, was made in f1d4a8f.
