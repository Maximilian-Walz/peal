---
milestone: m3
plan: required
depends: [0133]
---

# 0149 — Peal's own .belfry.yml merges the safe pull requests by itself and uses Belfry's plan, triage and release actions

## Intent

Peal's own `.belfry.yml` uses little of Belfry's contract: one rule (`agreed tasks`, `task: {merge: auto}`) with no required checks, no paths that always wait for the human, no review tier, the release action commented out, and no plan or triage action. Set it up so that more pull requests go through without the human, while what could loosen Peal's gates or its release chain still waits for them. Merging is shipping for Peal: the marketplace installs `./plugin` from the default branch, so a fresh install gets main as soon as something merges, with no release in between.

The human decided:

- **Merge scope:** task-file-only and docs-only pull requests, and tasks the human marked `merge: auto`, each only with `shellcheck`, `harnesses (ubuntu-latest)` and `harnesses (macos-latest)` green. Guard code merges by itself once a fresh `security-pr` review passed on its head. The core gates always wait for the human.
- **Grace:** 1h on the review tier, since no release gates main.
- `policy.update_behind` stays at its default, and `max_concurrent` and `permission_mode` stay as they are.

## Scope

## Done when

## Raw

> what a subagent could maybe do in the meantime is find out if we can improve the belfry config in the peal repo. E.g. set up some auto-merge stuff and make use of other features.

The human's answers, in their own words (choices offered to them): merge scope "As proposed", grace "Short grace, 1h", and "File a Peal task".

## Notes

- Depends on 0133, which adds `apply: .peal/peal apply` and drops `milestone`, `retire` and `defer`. The plan action proposes `move`, `priority` and the milestone kinds only with `apply`.
- The candidate below passed `belfry check` (Belfry v0.25.0) together with 0133's `tasks.commands`. Check the paths against `docs/security.md` and the tree before building; a guard file added since must join a tier.
- `.belfry.yml`, `.github/**` and `.claude/settings.json` never merge by themselves under Belfry's own guards. `plugin/hooks/hooks.json` is not among them, hence `plugin/hooks/**` in the never tier.
- Open for the planner: should `CLAUDE.md`, `plugin/commands/*.md` and `plugin/agents/*.md` (the prompts every user's sessions run) join a tier? Today the `agreed tasks` rule could merge them.
- The `threshold` triggers of plan and triage start a run by themselves (at most once a day). Schedules stay off until the human turns them on.
- Found alongside: `/peal:close` writes Summary, Decisions and Human steps but no `Security:` line, which Belfry highlights on the merge item. That is a task of its own.

The candidate, besides `tasks:`:

```yaml
actions:
  milestone-review:
    title: Milestone review
    prompt: /peal:milestone-review {milestone}
    triggers: [milestone]
  # The Releases tab's button. Releasing stays the human's call: nothing else starts it,
  # and /peal:release asks the human to confirm the version before it tags.
  release:
    title: Release
    prompt: /peal:release
    triggers: [button]
    single: true
    release: true
  # Belfry's own plan, with the milestone trigger (offered next to Close now) and a run
  # when more than 10 open tasks are in no milestone, at most once a day.
  plan:
    title: Plan
    planning: true
    triggers: [button, milestone, threshold, schedule]
    schedule: "0 7 * * 1"
    threshold: 10
    single: true
  # Ideas from other projects' sessions land here; sorted into one gallery.
  triage:
    title: Triage
    triage: true
    triggers: [button, threshold, schedule]
    schedule: "0 6 * * 1"
    threshold: 10
    single: true
  # A fresh session's security review of a pull request touching a boundary in
  # docs/security.md. review_before_merge starts it for its paths, on every new head;
  # for the never_auto_merge paths it runs too, for the human who merges those.
  security-pr:
    title: Security review of a PR
    triggers: [merge]
    paths: &never
      # What could loosen the process or the release chain, and what runs on a user's
      # machine before anything else: always the human's merge.
      - plugin/hooks/**
      - plugin/templates/launcher
      - plugin/templates/launcher.test.sh
      - plugin/templates/githook
      - plugin/templates/githook.test.sh
      - plugin/templates/decisions.yml
      - plugin/lib/githooks.sh
      - plugin/lib/githooks.test.sh
      - plugin/lib/git-guard.sh
      - plugin/lib/git-guard.test.sh
      - plugin/lib/session.sh
      - plugin/lib/session.test.sh
      - plugin/lib/main-write.sh
      - plugin/lib/main-write.test.sh
      - plugin/lib/ship.sh
      - plugin/lib/ship.test.sh
      - plugin/lib/hostile.test.sh
      - plugin/commands/release.md
      - plugin/.claude-plugin/plugin.json
      - .claude-plugin/marketplace.json
      - .peal/**
      - tools/ci-changes.sh
      - tools/ci-changes.test.sh
      - tools/test-all.sh
      - tools/pins.sh
      - tools/pins.test.sh
      - docs/security.md
      - SECURITY.md
    prompt: |
      Review pull request #{pr} ({branch} into {base}) for security, with fresh eyes: you have the docs and the code, not the session that wrote it. Change no code.

      1. Read docs/security.md in full: its assets, attackers and every boundary with its guard and harness.
      2. Run `git fetch origin {branch} {base}` as a command of its own, then review the commit {head}, the head this run is for: `git diff origin/{base}...{head}` and `git log origin/{base}..{head}`. If {head} is missing after the fetch, end with `verdict: fail` and say so. Read the code around each change as it is at {head}.
      3. Ask of each change: does every guard still hold, and does its harness still say so? Does it open a way past one: a shell word built from task or issue text, a file of the work tree that runs, a write onto main of a new shape, a gh call outside peal_gh, text from others that reaches a prompt unmarked? Does docs/security.md still describe the code? Run the harnesses of the files it changes with tools/test-all.sh.
      4. Report each finding with its file and line, what an attacker could do and the fix; then what you checked and found sound. A problem in code the pull request does not change is not its business: file it as an idea with the belfry idea tool, its first line `Security: ` and the finding.
      5. End with one line: `verdict: pass` when nothing you found should hold the merge back, or `verdict: fail` and the finding that should. A pass lets the pull request merge without the human reading it first: pass only what you would merge yourself.
policy:
  max_concurrent: 2
  permission_mode: auto
  merge: human
  merge_method: squash
  # On top of Belfry's own guards (.belfry.yml, .github/**, .claude/settings.json).
  never_auto_merge: *never
  # The other guards docs/security.md names, with their harnesses: they merge by
  # themselves only once security-pr passed on the PR's head, from a job that carried no
  # text from outside, after an hour with Hold: merged code reaches fresh installs at once.
  review_before_merge:
    review: security-pr
    grace: 1h
    paths:
      - plugin/bin/peal
      - plugin/lib/apply.awk
      - plugin/lib/apply.sh
      - plugin/lib/apply.test.sh
      - plugin/lib/backlog.sh
      - plugin/lib/backlog.test.sh
      - plugin/lib/store-files.sh
      - plugin/lib/store-files.test.sh
      - plugin/lib/store-issues.sh
      - plugin/lib/store-issues.test.sh
      - plugin/lib/issues-lib.awk
      - plugin/lib/issues-scan.awk
      - plugin/lib/frontmatter.sh
      - plugin/lib/frontmatter.test.sh
      - plugin/lib/work.sh
      - plugin/lib/work.test.sh
      - plugin/lib/claim.sh
      - plugin/lib/claim.test.sh
      - plugin/lib/github.sh
      - plugin/lib/fake-gh
      - plugin/commands/commands.test.sh
      - tools/lint.sh
      - .shellcheckrc
  auto_merge:
    # Task files and milestone texts: CI skips the harnesses for these.
    - name: task files
      paths: ["tasks/**", "docs/milestones/**"]
      max_lines: 400
      checks: &checks [shellcheck, "harnesses (ubuntu-latest)", "harnesses (macos-latest)"]
    # Documentation (docs/security.md stays under never_auto_merge).
    - name: docs
      paths: ["docs/**", README.md, CONTRIBUTING.md, CHANGELOG.md]
      max_lines: 400
      checks: *checks
    # The human agreed, with the task's plan, that its pull request may merge itself.
    - name: agreed tasks
      task: { merge: auto }
      checks: *checks
docs:
  - title: Design
    path: docs/design.md
  - title: Getting started
    path: docs/getting-started.md
  - title: Guides
    path: docs/guides/
  - title: Reference
    path: docs/reference/
  - title: Security
    path: docs/security.md
  - title: Milestones
    path: docs/milestones/
  - title: Changelog
    path: CHANGELOG.md
```

---

## Outcome

<!-- Written at close, replacing this comment. -->
