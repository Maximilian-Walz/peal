---
plan: auto
size: S
depends: []
priority: high
touches: [plugin/commands/idea.md, plugin/lib/store-issues.sh]
---

# 0173 — /peal:idea under a control plane on the issues storage files its fields as labels and a milestone

## Intent

Off a task branch under the control plane, `/peal:idea` calls its `task_create` with
the whole composed text as `body`, frontmatter and the `# 0173 — Title` heading
included. That is what `peal create` needs for task files, but on `storage.kind: issues`
the control plane opens the issue with that body as it is: the YAML block and the
`0173` heading end up in the issue text, and the fields `peal create` would turn into
labels and a milestone (priority, needs, owner, plan, size, the depends lines) are lost
as such. When this is done, an idea filed that way opens the same issue `peal create`
would.

## Scope

- On the issues storage, `/peal:idea` (through a `peal` helper, so the mapping stays the
  storage's own, `_peal_issues_from_text`) turns the composed text into the body without
  frontmatter and heading, with its `Depends on`, `After deploy of` and `Part of` lines,
  plus the labels (`priority: …`, `needs: …`, `plan: …`, `size: …`) for task_create's
  `labels` and the milestone for its `milestone`. The control plane adds its own filter
  label and `owner: human` itself.
- For task files, `/peal:idea` keeps sending the whole text.

## Done when

- A test of the helper shows an idea's frontmatter becoming the same labels, lines and
  milestone `peal create` writes on the issues storage.
- `plugin/commands/idea.md`'s control-plane branch uses it on the issues storage and keeps
  the whole text for task files.

## Raw

> What is missing for belfry #42?

## Notes

Found while putting the control plane on Peal (its issue #42), filed from that session's
idea. A milestone given through task_create becomes a proposal the human decides there,
not a direct move, so the control plane's guard against a session steering its auto
mode stays.
