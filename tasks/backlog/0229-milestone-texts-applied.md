---
milestone: m6
plan: auto
size: S
depends: []
priority: high
touches: [docs/milestones/]
---

# 0229 — The milestones m6, m7, m9, m4 and m8 carry their goals and acceptance criteria

## Intent

The re-plan of 2026-10-22 reordered Peal's milestones (m6 Safe under Belfry, m7 Cheaper
tasks, m9 Contract kept, m4 Main decides, m8 Ready for newcomers) and wrote a goal and
checkable acceptance criteria for each, but `peal apply` can change a milestone's order,
title, due date and state, not its text. So m6, m7, m4 and m8 keep their old or
placeholder criteria and m9 a placeholder list, and each milestone's review, which
decides whether the milestone can close and be released, has nothing real to check.
When this is done, the five milestone files hold the goals and criteria below.

## Scope

- `docs/milestones/` files of m6, m7, m9, m4 and m8: the goal and the acceptance criteria
  as written in Notes, adjusted only where a task number or a fact has moved since.
- Nothing else: no task moves, no state or order change.

## Done when

- Each of the five files holds its goal and its acceptance criteria from Notes (or the
  adjusted version, with the adjustment named in the Outcome).
- `peal check` passes.

## Raw

> both, file the text task and the apply extension

## Notes

The prepared texts, from the re-plan (JSON, one entry per milestone; `description` or
`goal` is the goal, `acceptance` the criteria):

```json
[
 {
  "milestone": "m6",
  "order": 4,
  "state": "current",
  "description": "Peal works and stays safe when Belfry runs it without the worker's gh login, and no session can grant itself consent: close opens its pull request through pr_create and the reads degrade without a login, every other gh call is listed or refuses with the reason, a filing from the control plane never fails after the human accepted it, merge: auto is the human's alone, a fabricated remote ref proves nothing, the contract template is complete, shape-only pushes cannot turn text from outside into consent, and the trusted-App issues storage is complete. Its release (v0.7.0) unblocks Belfry #42; #671 follows once the issues storage records through Belfry (Contract kept).",
  "acceptance": [
   "Under a session with no gh login (a `gh` that fails authentication), `close finish` ends with the pull request opened through `pr_create` with the same title, body and draft state, and `peal list` and `peal board` answer with the pull request state marked unknown (0176).",
   "Every other gh call Peal makes is listed for Belfry or has a path, a test keeps the list complete, and the writes that need a login refuse up front with the reason (0203).",
   "A text with no heading is filed by `peal create --title` under that title, so a control-plane proposal that passed its dry run never fails at filing (0204).",
   "A claim copy carrying `merge: auto` does not make the board print `merge`; `peal record`, `revise` and `comment` refuse a text that adds it (0177).",
   "The pre-push gate refuses a locally made merge onto main, also with a fabricated `refs/remotes/*` ref (0178).",
   "The `peal init --stage belfry` template names `apply_kinds`, `max_code_jobs` and `never_auto_merge` with `.peal/**`, and Peal's own contract does (0179).",
   "A direct revise push that drops `origin: outsider`, adds `merge` or fills `## Plan` is refused; a stranger's issue whose body holds `## Plan` reads as `PLAN required` (0180, 0161, 0122).",
   "`/peal:idea` under a control plane on the issues storage files its fields as labels and a milestone, and `/peal:setup` lists a trusted App's issues as candidates (0173, 0175).",
   "`docs/security.md` describes each of these with its test."
  ]
 },
 {
  "milestone": "m7",
  "order": 5,
  "description": "A task costs fewer turns, tokens and minutes: harnesses under one awk and a parallel test-all, the macOS job sharded, four to six fewer turns per task, a planner that reads sections and the issues a task cites and asks only what is the human's, small pull requests outside the boundary tiers that merge by themselves, no stray claim or branch left behind."
 },
 {
  "key": "PCK",
  "title": "Contract kept",
  "order": 6,
  "state": "open",
  "goal": "Peal follows the contract decisions the control plane makes in its Belfry on Peal milestone, and its CI proves it: the issues storage records through the control plane's task_record so the login can be hidden, the published fixtures checked in CI, detection by the tools offered rather than an environment variable, one defer path that ends by calling the control plane's tool, one rule for a filed idea's milestone, the guide holding the with-Peal lines the contract drops, and recorded fields the board sees at once. Its release lets the control plane hide the gh login for good (its #671).",
  "note": "created through a main-write pull request; every move or file into it waits until that pull request has merged on main"
 },
 {
  "milestone": "m4",
  "order": 7,
  "acceptance": [
   "A branch that changes `checks.commit`, `main` or `checks.close` in its own `.peal/config.yml` does not change what the gates or close run on it (0091, 0089), and `worktree-setup` runs from main's config (0170).",
   "`peal check` (or SessionStart) warns when the committed launcher differs from the installed one (0088), and doctor's launcher remedy never runs the `.peal/peal` it flagged (0205).",
   "`docs/security.md` says a Bash-call gate cannot hold against the session's own environment, `peal doctor` reports branch protection on main, and each prefix, wrapper and refspec form of the review's list is a refused case (0181).",
   "The threat model says gh with the user's token can merge or write contents directly and what closes it (0182), and covers Claude Code configuration changed on a task branch, with the SessionStart report and the close NOTE (0183).",
   "The config loader refuses an invalid `storage.issues.repo`, `main`, `remote` or `branch-prefix`, the hostile harness covers them, and the low findings each have a test or a documented limit (0120, 0184).",
   "An unknown command names the running Peal and its version (0136); the two version comparators are pinned together (0125); the reviewer proposes the Security line's boundary (0158).",
   "`docs/security.md` says so, with the tests."
  ]
 },
 {
  "milestone": "m8",
  "order": 8
 },
 {
  "milestone": "m5",
  "order": 9
 },
 {
  "milestone": "m7",
  "acceptance": [
   "The implementer's brief says to run one harness under one awk, the main session runs none, and a representative harness builds its fixture once (0185); `tools/test-all.sh -j 4` gives the serial run's result in parallel (0190).",
   "The macOS job's longest shard is under 13 minutes on a code pull request (0186).",
   "A session of the same size as before needs at least four fewer tool calls (0187); the reviewer's brief holds the last milestone review's Outcome and `close finish` runs shellcheck only on changed files (0189).",
   "A `context:` entry names a section and the brief says so (0188); the planner's brief carries the issues and pull requests the task cites, quoted (0135); the shared helpers run in half the processes (0156).",
   "Every guard path `docs/security.md` names is in a merge tier (0162), and a task pull request outside the tiers merges by itself once CI and the security review pass, with no grace (0219).",
   "A planned task asks at most four human questions and records the count (0218); a claim from a subagent outside a fixture is refused (0220); the autosave re-pushes no merged or done branch (0221).",
   "`peal record --round` keeps the round on the claim and the fourth round is refused with the split-or-defer question (0199); the hostile harness flags a silent status-2 run (0165); a locked config prints no raw lock error at hook install (0169)."
  ],
  "note": "the acceptance criteria name tasks filed in phase 3; set them now, replacing the placeholder list"
 },
 {
  "milestone": "m9",
  "acceptance": [
   "On the issues storage under the control plane, `peal record` and the agreed fields go through `task_record` when it is offered, and `peal work` on such a task succeeds with no gh login (0227).",
   "Peal's CI reads the control plane's published fixtures and fails on a `.belfry.yml` its checker refuses (0202).",
   "`/peal:idea` and `/peal:close` detect the control plane the same way, by its tools (0222).",
   "`/peal:defer` under the control plane leaves one record the control plane reads (0223).",
   "A filed idea's milestone is decided once (0224).",
   "`docs/guides/belfry.md` names no command that does not exist, and `/peal:comment` takes the origin from its argument (0225).",
   "`peal record` pushes the claim branch and `peal apply` prints no shell error for a hostile title (0142, 0155)."
  ],
  "note": "the acceptance criteria name tasks filed in phase 3; set them now, replacing the placeholder list"
 },
 {
  "milestone": "m8",
  "acceptance": [
   "The README's first screen says what Peal is, needs and costs, and that the default plan mode may start the build without showing the plan (0191).",
   "`docs/adopting.md` exists with both parts and the back-out list, `docs/migrating.md` is gone and no link to it is dead (0192); the troubleshooting page and the FAQ exist and are linked (0193); `AGENTS.md` and a real example transcript exist and the manifests carry the new description (0194); A1 to A13 are fixed and `docs/design.md` has no issue-numbered history (0195).",
   "After a write to main a clean checked-out main is fast-forwarded, else one line says it is behind, and `peal doctor` reports it (0196).",
   "Empty answers say so, `peal --help` fits one screen, the unknown-command message names the running Peal, and doctor, release, migrate and create messages say what to do (0197); doctor flags a task whose heading disagrees with its id (0197).",
   "`close finish` with `pr.host: none` ends with the pushed branch and the compare URL (0198); `peal import` files a TODO list, issues or a CSV once (0200); `peal status` prints one screen (0201).",
   "`peal record` accepts a Raw section added to a task filed without one (0134); set-milestone refuses clearing a milestone a `depends: milestone` needs (0140); every error line names its command (0228); a repeated `apply` batch files nothing twice (0226).",
   "Every example on the new pages passes `tools/docs.test.sh`."
  ],
  "note": "the acceptance criteria name tasks filed in phase 3; set them now, replacing the placeholder list"
 }
]
```
