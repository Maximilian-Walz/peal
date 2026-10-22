---
plan: required
size: M
depends: []
priority: high
touches: [plugin/lib/store-issues.sh, plugin/lib/issues-lib.awk, plugin/lib/issues-scan.awk, plugin/lib/ship.sh, plugin/lib/config-defaults.yml, plugin/lib/issue-fixtures.sh, plugin/lib/store-issues.test.sh, plugin/lib/ship.test.sh, docs/reference/configuration.md, docs/reference/storage.md, docs/security.md, docs/design.md]
---

# 0172 — The issues storage admits issues opened and edited by a GitHub App the project trusts

## Intent

With `storage.kind: issues` and no label, Peal admits only issues whose
`author_association` is OWNER, MEMBER or COLLABORATOR. Most of the control plane's own
issues are opened by its GitHub App (`belfry-server[bot]`, association `NONE`), so
`peal read 660` answers "refused: issue 660 is no task: opened by someone without write
access", and `/peal:work` would refuse most tasks the control plane starts there. A
filter label does not help: the App later edits its own issues (adding `Depends on`
lines when the human accepts a proposal), and the re-label check refuses an edit after
labelling by an author without write access. The control plane itself trusts issues
opened by someone with write access or by the App it talks as. When this is done, a
project can name the Apps whose issues count as a writer's, in its committed config.

## Scope

- A setting `storage.issues.apps` (App slugs, or bot logins `name[bot]`): issues opened,
  edited or renamed by those Apps count as a writer's on every read path (the listing,
  read, claim, work, defer) and in the re-label check, and in `peal ship`'s release notes; pull requests by those Apps
  mark an issue awaiting merge. A slug matches only the bot login `<slug>[bot]`,
  case-insensitively.
- Only the committed config names an App, so text from outside cannot widen it; an App's issue
  labelled as from outside (`origin: outsider`) gets no App trust.
- `docs/reference/configuration.md`, `docs/reference/storage.md`, `docs/security.md`
  (the issues storage's trust rule) and `docs/design.md` (one clause) describe it.

## Done when

- With `storage.issues.apps: [belfry-server]`, an issue opened and later edited by
  `belfry-server[bot]` is a task; without the setting it is refused as now; a
  store-issues test covers both, and one where the App's issue carries `origin: outsider`.
- The security document lists the setting under the issues storage's trust rule.

## Raw

> What is missing for belfry #42?

## Notes

Found while putting the control plane on Peal (its issue #42), filed from that session's
idea. It is a trust boundary, hence `plan: required`.

Human's answers at planning (2026-10-22), all the planner's defaults:
- OutsiderAll: `origin: outsider` cancels only the App trust; the write-access rule stays.
- OutsiderLbl: in label mode a labelled App issue with `origin: outsider` and no later
  edit stays admitted (the label vouches for it).
- OutsiderMsg: an App issue refused for `origin: outsider` gets a distinct reason naming
  that label, quoting nothing of the issue.
- ShipNotes: `peal ship`'s release notes apply the same App trust.
- ConfigSrc: `storage.issues.apps` is read from the work tree, as `storage.issues.label`;
  moving both to main is 0091's; recorded as a limit in `docs/security.md`.
- Slug/login: a slug matches only the REST login `<slug>[bot]`, never a plain `<slug>`.
- CaseMatch: slugs compare case-insensitively.
- LabelUnlbld: in label mode an App issue without the filter label is refused.
- FlowList: if the parser cannot take `[x[bot]]` unquoted, the docs say to quote it or
  use the slug; the parser stays out of scope.
- SetupList: `plugin/commands/setup.md`'s candidate listing learning the Apps is a
  follow-up idea, not this task.
- DesignWhy: `docs/design.md` gets one clause: "or an App the committed config trusts".
- Touches: widened to the plan's list.

## Plan

Approach: keep `admitted()` the single rule and teach it the Apps.
- `plugin/lib/issues-lib.awk`: new `writer(assoc, login, labels, apps)`: 1 when assoc is
  OWNER/MEMBER/COLLABORATOR, or login is `<slug>[bot]` for a slug in `apps` (comma
  list, case-insensitive) and the labels hold no `origin: outsider` (`label_kv`, key
  `origin`, value `outsider`, any case, trimmed). `admitted(assoc, labels, label, login,
  apps)` uses it with no label; `edit_writer`/`edit_admitted`/`edit_row_admitted` take
  the author's trust as a computed flag in place of the raw assoc. A user login cannot
  contain `[`, so the suffix cannot be forged.
- `plugin/lib/store-issues.sh`: `PEAL_ISSUES_ROW` gains a 9th column `.user.login // ""`;
  `_peal_issues_settings` reads `storage.issues.apps`, validates each entry against
  `^[A-Za-z0-9][A-Za-z0-9-]*(\[bot\])?$`, strips `[bot]`, lower-cases, sets `PEAL_APPS`
  (a bad entry: status 2 naming the setting); `_peal_issues_scan_awk` and
  `_peal_issues_admitted` pass `apps` and `$9`; `_peal_issues_refuse` uses `writer()`
  and gives a distinct reason for `origin: outsider`; `_peal_issues_prs` jq also admits
  listed bots (validated slugs embedded as a JSON array literal; `gh api --jq` has no
  `--arg`).
- `plugin/lib/issues-scan.awk`: pass `$9` and `apps`.
- GraphQL edits query unchanged: it gives bot logins without `[bot]`, so `who == author`
  still holds; the author's trust comes from the REST row.
- `plugin/lib/ship.sh`: release-note path gets the login column and `PEAL_APPS`
  (`_peal_ship_admitted`, `_peal_ship_edits_admitted`, the issue jq, the PR trust).
- `plugin/lib/config-defaults.yml`: `apps: []` under `storage.issues`, commented.
- `plugin/lib/issue-fixtures.sh`: `issue --user LOGIN` (sets `.user.login`, and
  `author_login` without `[bot]`), `pr --user LOGIN`. `plugin/lib/fake-gh` likely
  unchanged; confirm.
- Docs: `docs/reference/configuration.md` (row), `docs/reference/storage.md` (settings
  table, "Who is admitted"), `docs/security.md` ("Only admitted issues reach a
  session": the setting, the `[bot]` reasoning, the `origin: outsider` exception, the
  work-tree config limit), `docs/design.md` (one clause).
- Rejected: rewriting `author_association` in jq (spreads the rule over four jq
  programs); `performed_via_github_app` / `user.type` (not needed).

Verification (`store-issues.test.sh`, new `app_admission` case, through `for_each_awk`):
1. No label, `apps: [belfry-server]`, issue `NONE` by `belfry-server[bot]`: read, list,
   claim, defer --dry-run admit it.
2. Same without the setting: refused with today's message.
3. Label `tasks`, App issue edited and renamed by `belfry-server` after labelling:
   admitted with the setting, refused ("edited after it was labelled") without.
4. `origin: outsider` (also `Origin: Outsider`) on the App issue: refused with no label
   (distinct reason); refused in label mode when edited after labelling; admitted in
   label mode with no later edit.
5. Forgery: `--user belfry-server` (no `[bot]`) refused; `other-app[bot]` refused.
6. A fork PR by `belfry-server[bot]` saying "Fixes #N" makes N awaiting-merge with the
   setting only.
7. Config: `["belfry-server[bot]"]` and a block list work; `[bad slug!]` fails status 2
   naming `storage.issues.apps`; unquoted `[belfry-server[bot]]` tested, docs follow.
8. `ship.test.sh`: an App's closed issue keeps its title in the notes with the setting,
   the commit subject without.
9. `store-issues.test.sh`, `hostile.test.sh`, `ship.test.sh`, `config.test.sh` green;
   shellcheck clean.

Ranges relied on: `plugin/lib/store-issues.sh:1-101`, `plugin/lib/store-issues.sh:209-341`,
`plugin/lib/issues-lib.awk:1-108`, `plugin/lib/issues-scan.awk:1-40`,
`plugin/lib/ship.sh:36-41`, `plugin/lib/ship.sh:419-499`,
`plugin/lib/config-defaults.yml:35-40`, `plugin/lib/config.sh:1-71`,
`plugin/lib/fake-gh:209-227`, `plugin/lib/issue-fixtures.sh:7-25`,
`plugin/lib/issue-fixtures.sh:52-106`, `plugin/lib/store-issues.test.sh:158-228`,
`plugin/lib/store-issues.test.sh:235-334`, `plugin/lib/store-issues.test.sh:971-993`,
`plugin/lib/backlog.sh:153-160`, `docs/security.md:62-73`, `docs/security.md:268-279`,
`docs/security.md:298-340`, `docs/reference/configuration.md:44-46`,
`docs/reference/storage.md:7-16`, `docs/reference/storage.md:41-67`,
`docs/design.md:546-556`, `plugin/commands/setup.md:67-68`.
