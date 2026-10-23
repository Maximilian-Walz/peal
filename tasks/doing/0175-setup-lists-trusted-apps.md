---
plan: required
touches: [plugin/commands/setup.md, plugin/commands/commands.test.sh, plugin/lib/setup.test.sh, docs/security.md]
milestone: m6
size: S
---

# 0175 — /peal:setup's candidate issues include those of trusted Apps

## Intent

Task 0172 lets the issues storage treat issues opened by an App named in
`storage.issues.apps` as a writer's. `/peal:setup`'s candidate-issue listing still
filters on `author_association` (OWNER, MEMBER, COLLABORATOR) alone, so such issues are
not offered as candidate tasks. The listing should apply the same writer rule: the App's
bot login `<slug>[bot]`, unless the issue is labelled `origin: outsider`.

## Scope

- `/peal:setup`'s issue sample (tasks stage) applies the issues storage's writer rule: write access, or an App named in an `storage.issues.apps` setting already present (`<slug>[bot]`, case-insensitive), unless labelled `origin: outsider`.
- Setup does not ask which Apps to trust in this task (follow-up idea).

## Done when

- With `storage.issues.apps` naming an App, setup's sample lists that App's open issues next to the writers' issues.
- An App issue labelled `origin: outsider`, an untrusted bot's issue and a stranger's issue are not listed.
- Without the setting, the sample is the same as today.
- `docs/security.md` states that setup's sample applies the same rule, with its test.

## Raw

> /peal:setup's candidate-issue listing (plugin/commands/setup.md, around line 67) filters issues on author_association OWNER/MEMBER/COLLABORATOR only, so issues opened by an App listed in storage.issues.apps (task 0172) are not offered as candidate tasks. It should apply the same writer rule (the App's bot login `<slug>[bot]`, unless labelled origin: outsider). Agreed with the human as a follow-up while planning 0172.

## Notes

- Open: at setup time `storage.issues.apps` may not be set yet; should setup ask
  which Apps to trust, or only honour a setting already present?
- `docs/security.md` ("Only admitted issues reach a session") states the rule this
  listing should mirror.
- Human, 2026-10-23: setup honours only a `storage.issues.apps` already present; it does
  not ask which Apps to trust here.
- Human, 2026-10-23, on untrusted `[bot]` issues in the sample: trusting such Apps "should
  at least be part of the stuff peal asks to set eventually", but not offered over and
  over again. Taken as a follow-up idea (offer once), not this task's scope; the sample
  says nothing about them here.
- Plan agreed by the human 2026-10-23: size S, default model, merge default.
- Planner's decisions (shown to the human, not overruled): the jq rule lives in the prompt,
  mirroring `writer()`, so setup needs no jq; an `apps` entry failing the slug check is
  named and left out; the listing is a one-line fenced command so a test runs its exact
  text; the `storage.issues.label` branch is not mirrored (setup never sets a label).

## Plan

- `plugin/commands/setup.md`, step 3 `tasks` item 1: first run `peal config
  storage.issues.apps`; keep each entry matching `^[A-Za-z0-9][A-Za-z0-9-]*(\[bot\])?$`
  (as `_peal_issues_apps`), lower-cased, `[bot]` dropped; name failing entries to the
  human and leave them out. Put the kept slugs into the jq as a JSON array literal (`[]`
  when none). The listing becomes a one-line `gh api --jq` command in an indented fenced
  block:

      gh api 'repos/<github>/issues?state=open&per_page=100' --jq '<apps> as $apps | [.[] | select(.pull_request == null) | select((.author_association | IN("OWNER", "MEMBER", "COLLABORATOR")) or (((.user.login // "") | ascii_downcase) as $l | ($l | endswith("[bot]")) and ($l[:-5] | IN($apps[])) and ([.labels[].name | test("^\\s*origin\\s*:\\s*outsider\\s*$"; "i")] | any | not)))] | .[0:20] | .[] | {number, title}'

  matching `writer()` in `plugin/lib/issues-lib.awk` (write access always; App trust needs
  `[bot]` + slug in list; `origin: outsider` drops only the App's trust).
- Item 4: "opened by someone with write access" gains "or by an App named in
  `storage.issues.apps`".
- `docs/security.md`, "Only admitted issues reach a session": one sentence that setup's
  sample applies the same writer rule, naming its test.
- Tests: new `issues_candidates` case in `plugin/lib/setup.test.sh` (under the jq guard),
  fixtures via `issue` from `plugin/lib/issue-fixtures.sh`: OWNER; `--assoc NONE --user
  stranger`; `--user belfry-server[bot]`; same App with `--label "origin: outsider"`;
  `--user other-app[bot]`; `--user Belfry-Server[bot]`. Lift the `gh api
  'repos/<github>/issues` line from setup.md, substitute `acme/widgets` and `<apps>`, run
  against fake-gh: `[]` → issue 1; `["belfry-server"]` → 1, 3, 6. Update
  `plugin/commands/commands.test.sh` "setup: the issue sample is filtered to write access"
  to the new form, also requiring `[bot]` and `origin`. Full suite with
  `PEAL_ROOT=$PWD/plugin`.
- gojq caveat: only constructs gojq and jq share; check once with real `gh api --jq` if a
  login is available, else say so in the PR.

Ranges: tasks/doing/0175-setup-lists-trusted-apps.md:1-37, docs/milestones/m6.md:10-35,
plugin/commands/setup.md:28-35, plugin/commands/setup.md:59-92,
plugin/commands/setup.md:160-161, plugin/commands/commands.test.sh:37-47,
plugin/lib/issues-lib.awk:43-57, plugin/lib/issues-lib.awk:63-93,
plugin/lib/store-issues.sh:52-69, plugin/lib/init.sh:521-530,
plugin/lib/setup.test.sh:1-30, plugin/lib/setup.test.sh:126-161,
plugin/lib/issue-fixtures.sh:60-90, docs/security.md:298-318,
docs/reference/storage.md:56-73, docs/reference/configuration.md:47

---

## Outcome

<!-- Written at close, replacing this comment. -->
