---
milestone: m4
plan: required
touches: [tools/pins.test.sh, .github/workflows/ci.yml]
---

# 0206 — pins.test.sh checks the template's Peal pin in CI, not only in clones that have the tags

## Intent

`tools/pins.test.sh` checks that the decisions workflow template's pinned Peal SHA (`plugin/templates/decisions.yml`, the Get Peal fetch line) is the commit of the tag its `# vX` comment names. When that tag is missing from the clone, the test skips the check. The harness jobs in `.github/workflows/ci.yml` check out without tags (only the `changes` job uses `fetch-depth: 0`), so CI never runs it. That is how v0.5.0 shipped pinning v0.4.0's commit under a `# v0.5.0` comment and nothing failed. The pin on main is correct again (v0.6.0), and since 0130 a release pins by itself. Still, docs/security.md says the pin follows each release and is checked by `tools/pins.test.sh`, and in CI that isn't true yet. CI should get the tags, either by fetching them in the job that runs pins.test.sh or by having pins.test.sh fail instead of skip when the tag exists on the remote but not locally. Then a pin that doesn't match its tag fails CI.

## Scope

## Done when

## Raw

> pins.test.sh checks the template's Peal pin in CI, not only in clones that have the tags
>
> ## Intent
>
> `tools/pins.test.sh` checks that the decisions template's pinned SHA is the commit of its `# vX` tag, but it skips that check when the tag is not in the clone. The harness jobs in `.github/workflows/ci.yml` check out without tags (only the `changes` job uses `fetch-depth: 0`), so CI never runs the check. v0.5.0 shipped with v0.4.0's SHA under a `# v0.5.0` comment, and nothing failed. The pin on main is correct again (v0.6.0), and since 0130 a release pins by itself, but docs/security.md promises that the pin "follows each release … checked by tools/pins.test.sh".
>
> ## Scope
>
> - The job that runs pins.test.sh fetches tags (`fetch-tags: true`, or `git fetch --tags` before the run). Or pins.test.sh fails, not skips, when the tag exists on the remote but not locally.
>
> ## Done when
>
> - A template whose SHA is not its tag's commit fails CI (shown once on a throwaway branch or by a harness case).
>
> ### Merged: Security: main's decisions workflow template (plugin/templates/decisions.yml, the Get Peal fetch line) carries the tag comment `# v0.5.0` but pins 5deda7caec4b6e933f4e972b0b5786399cd9d6e5, v0.4.0's release commit; v0.5.0's commit is 015c03e43ef2246b1d37ef84bfff36e0dfa00415. The v0.5.0 release bumped the tag comment, but no `chore(release): pin v0.5.0` followed. So a project that copies the template runs v0.4.0 under a v0.5.0 label. This doesn't open an attack: it's an older pinned commit of Peal's own history, not a foreign one. It does break what docs/security.md promises, that the pin follows each release. `tools/pins.test.sh` catches it ("the pinned SHA is v0.5.0's commit"), but only in a clone that has the tags, so CI's tagless checkout skips the check. Fix: run `peal ship pin v0.5.0` now; since 0130, later releases pin by themselves. Also consider fetching tags in the CI job that runs pins.test.sh, so a missed pin fails CI. Found in the security review of 0130's pull request.

## Notes

- The human placed this task in milestone m4.
- Open question: which way to go, fetching tags in CI or having pins.test.sh fail when the tag is on the remote but not local? The second needs network access from the test, and local runs may be offline. A shallow checkout may also need its `fetch-depth` raised so the tag's commit resolves.
- Open question: is the merged note's immediate fix (`peal ship pin v0.5.0`) already settled? The idea says main pins v0.6.0 correctly now; check that before starting.
- Context: docs/security.md, the section on the decisions template's Peal pin and the harness line naming `tools/pins.test.sh`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
