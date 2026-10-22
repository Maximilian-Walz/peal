---
plan: required
size: M
depends: []
priority: high
touches: [plugin/lib/store-issues.sh, plugin/lib/config-defaults.yml, docs/reference/configuration.md, docs/security.md]
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
  read, claim, work, defer) and in the re-label check; pull requests by those Apps mark an
  issue awaiting merge.
- Only the committed config names an App, so text from outside cannot widen it; an issue
  labelled as from outside (`origin: outsider`) stays an outsider's whoever opened it.
- `docs/reference/configuration.md` and `docs/security.md` (the issues storage's trust
  rule) describe it.

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
