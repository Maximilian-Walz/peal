---
plan: required
touches: [plugin/templates/decisions.yml, .github/dependabot.yml, tools/pins.sh, tools/pins.test.sh, tools/lint.sh, docs/security.md, CONTRIBUTING.md]
priority: high
milestone: m2
size: M
---

# 0069 — Pin actions/checkout in the decisions workflow template

## Intent

The workflow template Peal hands to projects, `plugin/templates/decisions.yml`, still
uses `actions/checkout@v4` by tag. Pin it by commit SHA, as 0041 did for Peal's own CI:
once a project copies it into its `.github/workflows`, that project's Dependabot keeps the
pin current.

## Scope

- Pin `actions/checkout` by commit SHA (v7.0.1) and Peal by a release's commit SHA
  (v0.2.0) in `plugin/templates/decisions.yml`; the "Get Peal" step fetches that commit
  instead of cloning the default branch.
- Dependabot (`directories: ["/", "/plugin/templates"]`, `actions/checkout` grouped across
  both with `group-by: dependency-name`) keeps the action current.
- `tools/pins.sh`, run by `tools/lint.sh`, refuses an unpinned reference in
  `plugin/templates/*.yml` and `.github/workflows/*.yml`.
- `tools/pins.test.sh` proves the guard and checks the template's Peal pin against
  `plugin.json`'s version.
- `docs/security.md`'s CI boundary and `CONTRIBUTING.md` say so.

## Done when

- `tools/pins.sh` exits 0 on the repository; every `uses:` and the Peal fetch in the
  template carry a 40-hex SHA with a `# vX.Y.Z` comment, and no `git clone` is left.
- `tools/pins.test.sh` shows the guard refusing each unpinned form (tag, short SHA, SHA
  without tag comment, `./local`, `docker://`, `git clone`, a fetch by branch, a fetch
  without `# vX.Y.Z`), exit 2 on no files, and exit 1 naming lines 37 and 42 on
  `origin/main`'s template before this task.
- `tools/pins.test.sh` fails when the template's Peal tag differs from `plugin.json`'s
  version (proved on a temp copy), and passes on the repository.
- `git ls-remote` confirms both SHAs (checkout v7.0.1 is `3d3c42e5…`, Peal v0.2.0^{} is
  `8927e464…`); the new Get Peal step, run locally, checks out that commit and its
  `peal` has `decision`.
- Both YAML files parse; `dependabot.yml` has `directories` and no `directory`;
  `tools/lint.sh`, `tools/docs.test.sh` and `tools/pins.test.sh` pass.
- The Outcome names the post-merge check for the human: Dependabot lists `/` and
  `/plugin/templates` without a config error (else drop the `groups` block).

## Raw

> Pin actions/checkout by SHA in plugin/templates/decisions.yml, the workflow template Peal hands to projects: once copied into a project's .github/workflows, that project's Dependabot keeps the pin current. Found closing 0041, which pinned only Peal's own CI.

## Notes

Deferred 2026-09-28 after a claim: stale claim: its session stopped; given back so auto mode picks it up again

- Nothing in Peal's own repository keeps the template's pin current (Dependabot scans
  only `.github/workflows/`): does the pin go stale in the template between releases, and
  is that acceptable, or does something (a check, a Dependabot directory entry) keep it
  current?
- Whether it belongs to m1 ("a CI whose supply chain is pinned") is the planner's or a
  milestone review's call; filed without a milestone.
- `docs/security.md`, the CI boundary.

Agreed with the human 2026-09-29 (planning):
- Scope widened: the pin plus what keeps it current, a guard, `docs/security.md`.
- Dependabot `directories` keeps the checkout pin current (not a harness against
  `ci.yml`, not accepted staleness); pin v7.0.1, the SHA Peal's CI uses.
- Add a guard refusing unpinned references. Its reach was left to the session, which
  chose templates and Peal's own workflows: one glob, and every workflow complies.
- Dependabot grouping was left to the session: one `actions/checkout` group across both
  directories (`group-by: dependency-name`); if Dependabot rejects it after merge, drop
  the `groups` block in a follow-up.
- `docs/security.md`'s CI boundary mentions the template.
- The "Get Peal" clone is pinned in this task too, to v0.2.0's commit. The check that
  the pin follows `plugin.json`'s version lives in the harness, not lint, so a release's
  bump pull request is never blocked. The pin lags one release (a release commit cannot
  name its own SHA): accepted.
- One M task, not split; merged by a human.

## Plan

Agreed 2026-09-29.

1. `plugin/templates/decisions.yml`:
   - line 37: `uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`;
   - lines 40-42, Get Peal: `git init -q "$RUNNER_TEMP/peal"`, then a `git -C
     "$RUNNER_TEMP/peal"` fetch `-q --depth 1 https://github.com/Maximilian-Walz/peal
     8927e4644010042329fed4ddb2f8084aa98ebf02 # v0.2.0`, then `git -C
     "$RUNNER_TEMP/peal" checkout -q FETCH_HEAD`. Its comment says Dependabot does not
     update it and how to find another release's commit (`git ls-remote
     https://github.com/Maximilian-Walz/peal 'refs/tags/vX.Y.Z^{}'`). The publish line
     is unchanged.
2. `.github/dependabot.yml`: `directories: ["/", "/plugin/templates"]` (no `directory`),
   and `groups: checkout: {patterns: ["actions/checkout"], group-by: dependency-name}`.
3. `tools/pins.sh [FILE...]` (default `plugin/templates/*.yml .github/workflows/*.yml`),
   line-based: every `uses:` is `OWNER/REPO[/PATH]@<40 lowercase hex> # v<digits>...`;
   any `git clone` is refused; a git fetch of an `https://` URL carries a 40-hex SHA and
   `# vMAJOR.MINOR.PATCH`. Prints `path:line: reason`; exit 1 on a finding, 0 clean, 2
   when it finds no files. `tools/lint.sh` calls it after shellcheck.
4. `tools/pins.test.sh`: fixtures for each refused form, a clean fixture, the empty set,
   `origin/main`'s pre-task template (lines 37 and 42); the real template's Peal tag
   equals `v` + `plugin.json`'s version (its failure proved on a temp copy with 0.3.0;
   the message names `git rev-parse vX.Y.Z^{commit}`); when tag v0.2.0 exists locally,
   its commit equals the pinned SHA, else that sub-check is skipped with a note.
5. `docs/security.md` CI boundary: one sentence (the template ships its action and its
   Peal pinned by SHA; Dependabot keeps the action current across `/` and
   `/plugin/templates`; the Peal pin follows each release, checked by
   `tools/pins.test.sh`; `tools/pins.sh` refuses an unpinned reference); Guard adds
   `plugin/templates/decisions.yml` and `tools/pins.sh`, Harness `tools/pins.test.sh`.
   `CONTRIBUTING.md:50-51`: lint also runs `tools/pins.sh`.
6. Verification as in Done when; also run the Get Peal lines locally, and list in the
   Outcome any commits since v0.2.0 touching `plugin/lib/decisions.sh` or
   `plugin/lib/main-write.sh`. Queue as an idea at close: extend
   `release.version-files` to a nested YAML field.

Ranges relied on: plugin/templates/decisions.yml:1-49, .github/dependabot.yml:1-7,
.github/workflows/ci.yml:23-34, .github/workflows/scorecard.yml:22-25, tools/lint.sh:1-26,
tools/ci-changes.sh:1-38, plugin/lib/ship.sh:65-86, plugin/lib/ship.sh:181-195,
plugin/lib/decisions.sh:354-367, plugin/.claude-plugin/plugin.json:1-11,
.peal/config.yml:9-16, docs/reference/configuration.md:46-50, docs/design.md:389-392,
docs/design.md:421-427, docs/security.md:245-257, CONTRIBUTING.md:42-59, CHANGELOG.md:12,
CHANGELOG.md:41, plugin/commands/next.md:99-100, tasks/done/0041-ci-supply-chain.md:14-25,
tasks/done/0041-ci-supply-chain.md:54-59, tools/docs.test.sh:3-27.

---

## Outcome

<!-- Written at close, replacing this comment. -->
