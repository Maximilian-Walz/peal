---
milestone: m3
plan: required
touches: [plugin/bin/peal, plugin/lib/main-write.sh, plugin/lib/store-files.sh, plugin/lib/store-issues.sh, plugin/commands/setup.md, docs/design.md]
---

# 0112 — `peal apply`: carry out a batch of proposals as one change

## Intent

A control plane's triage and planning runs end with a list of changes the human
accepted: file these tasks, move those to another milestone, change a priority, add a
dependency, retire a duplicate, create or park a milestone. Today each is one `peal`
command, and on a repository whose main branch takes pull requests only, each opens a
pull request of its own, so one decision becomes a dozen pull requests for the human to
merge. When this is done, `peal apply` reads the whole list as one JSON document on
stdin and makes it one change: one commit on the files storage (one pull request where
main is protected), the matching API calls on the issues storage, and one line of result
per item on stdout.

## Scope

- `peal apply` takes the proposal kinds Belfry's contract defines for
  `tasks.commands.apply` (Belfry issue #434, with the kinds of #433): file, add, move,
  priority, depends, retire (with a duplicate), milestone create, update, state and
  split. Each item is validated as the single commands validate it today (depends
  cycles, unknown milestones, frontmatter), and a batch with an invalid item changes
  nothing and says which.
- Filed tasks get ids the way `peal create` gives them (unique across filings, 0073),
  keep `origin` when given, and may refer to each other within the batch.
- `/peal:setup belfry` and `peal init --stage belfry` write `apply:` into
  `.belfry.yml`; this repository's own `.belfry.yml` gets it once a release carrying it
  is installed.
- Whether the single commands stay is decided with Belfry's #434; Peal follows it.

## Done when

- A batch of mixed items on the files storage becomes one commit (one pull request on a
  protected main), and on the issues storage the matching API calls; each item's result
  is printed. Tested against the fake gh.
- An invalid item leaves everything unchanged and names the item.
- `docs/design.md` documents `apply` next to the other Belfry commands.
