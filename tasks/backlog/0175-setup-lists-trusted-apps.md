---
plan: required
touches: [plugin/commands/setup.md]
---

# 0175 — /peal:setup's candidate issues include those of trusted Apps

## Intent

Task 0172 lets the issues storage treat issues opened by an App named in
`storage.issues.apps` as a writer's. `/peal:setup`'s candidate-issue listing still
filters on `author_association` (OWNER, MEMBER, COLLABORATOR) alone, so such issues are
not offered as candidate tasks. The listing should apply the same writer rule: the App's
bot login `<slug>[bot]`, unless the issue is labelled `origin: outsider`.

## Scope

## Done when

## Raw

> /peal:setup's candidate-issue listing (plugin/commands/setup.md, around line 67) filters issues on author_association OWNER/MEMBER/COLLABORATOR only, so issues opened by an App listed in storage.issues.apps (task 0172) are not offered as candidate tasks. It should apply the same writer rule (the App's bot login `<slug>[bot]`, unless labelled origin: outsider). Agreed with the human as a follow-up while planning 0172.

## Notes

- Open: at setup time `storage.issues.apps` may not be set yet; should setup ask
  which Apps to trust, or only honour a setting already present?
- `docs/security.md` ("Only admitted issues reach a session") states the rule this
  listing should mirror.

---

## Outcome

<!-- Written at close, replacing this comment. -->
