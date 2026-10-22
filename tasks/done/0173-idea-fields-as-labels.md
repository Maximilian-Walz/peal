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

---

## Outcome

Built `peal idea-fields` (issues storage only): it reads an idea's composed text on
stdin and prints the issue `peal create` would open from it, as `title:`, `milestone:`
(when there is one), one `label:` line per label, then `body:` and the body. That body
holds the `Part of`, `Depends on` and `After deploy of` lines, then the text without
frontmatter and heading. The helper calls `_peal_issues_from_text`, so the mapping stays
the storage's own. It runs offline. On task files `peal_store_idea_fields` refuses with
status 2, because they take the whole text.

`plugin/commands/idea.md`'s control-plane branch (off a task branch, `task_create`) now
splits on `peal config storage.kind`. `files` still sends the whole text as `body`.
`issues` pipes the text through `peal idea-fields` and passes `body`, `labels` and
`milestone`. Documented in `docs/reference/cli.md` and `docs/reference/commands.md`.

Verified by a new check in `plugin/lib/store-issues.test.sh`. It feeds `peal
idea-fields` the text `peal create` filed as issue 3 and compares the title, milestone,
labels and body with that issue. A second check covers the refusal of a text with no
heading. The suite gives 741 passed, 0 failed under mawk, nawk and busybox awk, and
`peal.test.sh` gives 29 passed.

For the next session:
- The `idea` tool fallback (when `task_create` refuses) still takes the whole composed
  text. That is the control plane's to map.
- Whether the control plane's `task_create` accepts `labels` and `milestone` was not
  checked from here. The control plane is outside this repository.

### Reviewer findings not acted on

None. The one finding was fixed in its own commit: the files-storage stub had separated
`peal_store_create` from its doc comment.
