---
plan: auto
size: M
depends: [0192]
touches: [docs/design.md, docs/security.md, docs/guides/belfry.md, README.md, .peal/config.yml, plugin/lib/work.sh, plugin/bin/peal, CHANGELOG.md]
milestone: m8
---

# 0195 — Fix the docs' inaccuracies and move design.md's history and scope tables out

## Intent

The documentation review compared each page with the code and found thirteen places where prose has slipped; the docs harness keeps the reference and examples honest, but not prose and history. In addition, `docs/design.md` opens with "Issue #2 settled the decisions below; the build is split into the issues listed at the end" and ends with a "Building Peal" table of issues, while CONTRIBUTING says GitHub issues are not tasks, so an agent skimming the design looks for work in issues; and its scope tables describe the reference project in enough detail that a reader can tell its kind of project, which is noise for every other reader (and the planner reads the file: see the context task). When this is done the table's items are fixed and the design reads as Peal's design.

## Scope

Fix, each in its own place:
- A1 and A2: the README and `docs/guides/working-a-task.md` say "you agree the plan" and show `plan: -, size: S`, which `/peal:idea` does not produce (the default `auto` may build without a stop; the line is `plan: auto, size: -`); adjust the harness fixture. (Shared with the README task; whoever lands first does it.)
- A3: `peal --help` (the `work` line) and the comment in `plugin/lib/work.sh` omit `auto`.
- A4: requirements stated up front (the README task).
- A5: Peal's own `.peal/config.yml` commented defaults lack `worktree-setup` and `pr.security`; regenerate the block.
- A6: `docs/security.md`'s "What this milestone leaves open" is written as the first milestone's task; retitle it "Open limits" and list the open tasks.
- A7: delete "Issue #2 settled..." and the "Building Peal" table from `docs/design.md` (keep them in a `docs/history.md` or the first changelog entry).
- A8: `docs/migrating.md` step 2 installs nothing (the adopting task rewrites it).
- A9: the pin example's `"ref": "vX"` in getting-started becomes a real tag.
- A10: `CHANGELOG.md` entries are the Outcome's first sentence ("Built as planned."): a hand-edited first paragraph per release meanwhile, and a `release-note:` text in the kinds task (0060) as the real fix.
- A11: `docs/guides/belfry.md` shows an abridged contract that omits `pool`, `create` and `revise` that `peal init --stage belfry` writes: say "abridged" or show the whole file.
- A12: the manifests' description (the AGENTS task).
- A13: the seven-line paragraph in getting-started as bullets.
- Move the scope tables out of `docs/design.md` into the adopting guide, shortened to categories with a generic example each.

## Done when

- Each of A1 to A13 is fixed or recorded as covered by the task named, and `tools/docs.test.sh` passes.
- `docs/design.md` has no issue-numbered history and no table that reveals the kind of the reference project.
- `docs/security.md`'s last section is titled "Open limits" and names the open tasks.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Documentation review, section 6 (table A1 to A13), 7.3 and 8.4; about the design file's tables also section 1 of that review.
- Security: none.

---

## Outcome

<!-- Written at close, replacing this comment. -->
