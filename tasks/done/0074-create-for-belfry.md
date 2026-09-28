---
milestone: m1
priority: high
plan: required
depends: []
size: M
touches: [plugin/bin/peal, plugin/lib/backlog.sh, plugin/lib/init.sh, plugin/lib/*.test.sh, plugin/commands/idea.md, plugin/commands/commands.test.sh, docs/design.md, README.md, docs/security.md]
---

# 0074 — Filing from a Belfry session: Peal answers `tasks.commands.create`

## Intent

A session under Belfry cannot file a task: `peal idea` fetches, pushes and opens a pull
request from inside its own script, and in the session's sandbox it has neither SSH keys
nor gh's login, so it hangs with no output (eight sessions this week; nothing got filed).
Belfry now runs a contract command, `tasks.commands.create`, itself, outside the
sandbox, with the task's text on standard input and the id expected as `filed: <id>` on
its last line (Belfry #250). When this is done, Peal provides that command, and
`/peal:idea` under Belfry hands its text to Belfry's `task_create` instead of running
`peal idea` in the shell.

## Scope

- A CLI entry for the contract (`peal create --stdin --owner {owner} {title}` or similar)
  that reads the whole task text from standard input, files it the way `peal create`
  does (through a pull request on a protected main, 0061), and ends with `filed: NNNN`.
- `peal init --stage belfry` writes `create:` into the `.belfry.yml` it generates (files
  storage). Peal's own `.belfry.yml` gets it in a follow-up, after Belfry's deploy.
- `/peal:idea`: when `BELFRY_SESSION` is set and off a task branch, write the text and
  call Belfry's `task_create` (Belfry's `idea` tool when it refuses); never run
  `peal idea` there.
- The text is untrusted data: it only ever reaches the task file, never a shell word.

## Done when

- Harnesses: the command files from stdin and prints the id; hostile text lands in the
  file byte for byte; the `belfry` stage writes the key.

## Raw

From Belfry's friction reports (2026-09-25 to 27): `peal idea` hanging in sandboxed
sessions on main; `idea` with `wait: true` returning no id.

## Notes

- Order: Belfry's server accepts `tasks.commands.create` only from the release after
  its #264. Peal's own `.belfry.yml` gets the key once that release is deployed; before,
  the server refuses the contract and keeps the last valid one, so this task's PR waits
  for the deploy (or leaves the key out and a follow-up adds it).
- Origin: a task filed from untrusted text (an outsider's issue or comment) should keep
  that origin in its frontmatter, as Belfry does for issues (Belfry #211). Belfry's
  create does not pass an origin yet; decide in the plan whether the command takes one
  (e.g. `--origin outsider`) or file it as a follow-up with Belfry.
- Human's answers (planning, 2026-09-27):
  - Peal's own `.belfry.yml` does not get the `create:` key here; a follow-up task,
    depending on 0074, adds it once Belfry's release after #264 is deployed.
  - `/peal:idea` reading `BELFRY_SESSION` is accepted as a deliberate exception to "Peal
    reads no Belfry variable", scoped to `/peal:idea` and recorded in `docs/design.md`.
  - Under Belfry, on a task branch `peal idea` still queues offline; anywhere else the
    text goes to `task_create`, and when Belfry refuses it (not a filing job) to Belfry's
    `idea` tool. "Never run `peal idea` there" means off a task branch.
  - Owner: the `--owner` flag wins over the text's frontmatter (set or remove
    `owner: human`).
  - The create form refuses a text that sets `merge`; other fields pass.
  - Slug: the first five words of `{title}`; a title under two words is refused; the
    text's `# NNNN — Title` heading stays as written.
  - Spelling: `peal create --owner {owner} --title {title}`, stdin implied.
  - The pull-request merge wait is capped at about 90 s under the create form (Belfry
    gives 2 min); an open PR at the cap still counts as filed, no extra warning.
  - Origin: no `--origin` now; a follow-up idea depending on Belfry passing the job's
    untrusted flag.
  - The create form works on the issues storage too (prints `filed: <n>`), tested
    lightly, not in the github-issues contract.
  - `docs/design.md`, `README.md`, `docs/security.md` are updated in this task.
  - Generated `.belfry.yml` files from before this change drift; accepted (no users).
  - File an idea from this task: `peal idea` should fail fast in a sandbox
    (non-interactive git/ssh) instead of hanging.

## Plan

Approach:
- `plugin/bin/peal` `cmd_create`: a named-option form `peal create --owner OWNER --title
  TITLE`, the whole task text on stdin, one task. The title is only ever an option value;
  unknown or repeated options are refused with status 2. Usage text updated.
- `plugin/lib/backlog.sh`: `peal_create_filed`, above the storage, for both storages:
  slug from the first five words of the title after `peal_slugify`'s normalisation
  (fewer than two words refused); owner must be `ai` or `human`, the flag wins (set or
  remove `owner: human` in the frontmatter); refuse a text that sets `merge` or holds
  the `-----NEXT TASK-----` delimiter; `peal_store_create plain "" SLUG` with
  `PEAL_MAIN_WRITE_BUDGET` capped at about 90 s unless the caller set it (status 3 with
  an open PR still counts as filed); the storage's lines, then `filed: <id>` as the very
  last line.
- `plugin/lib/init.sh` `_peal_init_belfry_text`: for the files storage only, the line
  `create: .peal/peal create --owner {owner} --title {title}`. Peal's own `.belfry.yml`
  is not touched (follow-up).
- `plugin/commands/idea.md` step 3: `BELFRY_SESSION` unset: unchanged. Set, on a task
  branch: `peal idea` queues offline. Set, elsewhere: never `peal idea`; call Belfry's
  `task_create` with title, the composed text as body and owner, report its id; if Belfry
  refuses (not a filing job), hand the text to Belfry's `idea` tool.
- Docs: `docs/design.md` (Peal-and-Belfry table, the `.belfry.yml` example, the
  `/peal:idea` line, the `BELFRY_SESSION` exception), `README.md` (command list gains
  create), `docs/security.md` (the stdin boundary).
- Ideas filed from this task: add the `create:` key to Peal's `.belfry.yml` (depends
  0074, after Belfry's deploy); `--origin` once Belfry passes the job's untrusted flag;
  `peal idea` fails fast in a sandbox.

Verification:
- `store-files.test.sh`: text on stdin with `--owner ai --title "Model the crate for
  level two"` exits 0, last line exactly `filed: 0004`, matching
  `^[ \t`]*filed:[ \t]*#?([A-Za-z0-9._-]+)[ \t`]*$`, file
  `tasks/backlog/0004-model-the-crate-for-level.md` on the remote's main; `--owner human`
  gives `owner: human`; refused with nothing filed: `--owner robot`, missing `--title` or
  `--owner`, a one-word title, `merge: auto`, the delimiter; a title starting with `-` or
  like `--batch 0001` is filed as a title; the PR route (fake gh, no auto-merge, pending
  checks) returns 0 within the cap with `filed: NNNN` last.
- `hostile.test.sh`: hostile values as `--title` and `--owner` (owner refused, no
  canary); hostile text on stdin lands byte for byte (`cmp`, only `NNNN` replaced).
- `init.test.sh`: files storage's commands block holds the `create:` line with no
  placeholder other than `{title}` and `{owner}`; issues storage has none; re-run and
  `--remove belfry` round-trip.
- `store-issues.test.sh`: the create form prints `filed: <n>` (light).
- `commands.test.sh`: `idea.md` names `BELFRY_SESSION` and `task_create` and never runs
  `peal idea` off a task branch under Belfry.

Ranges:
- docs/design.md:35-105
- docs/security.md:85-120
- README.md:46-54
- .belfry.yml:1-43
- plugin/bin/peal:110-130
- plugin/bin/peal:351-359
- plugin/bin/peal:386-392
- plugin/commands/idea.md:1-130
- plugin/commands/commands.test.sh:43-70
- plugin/lib/ideas.sh:21-54
- plugin/lib/tasks.sh:1-39
- plugin/lib/task-text.sh:1-21
- plugin/lib/task-text.sh:81-93
- plugin/lib/store-files.sh:310-410
- plugin/lib/store-issues.sh:343-430
- plugin/lib/main-write.sh:1-34
- plugin/lib/main-write.sh:55-84
- plugin/lib/main-write.sh:150-306
- plugin/lib/task-check.awk:53-79
- plugin/lib/init.sh:402-481
- plugin/lib/init.test.sh:91-112
- plugin/lib/init.test.sh:218-228
- plugin/lib/store-files.test.sh:36-98
- plugin/lib/hostile.test.sh:1-30
- plugin/lib/hostile.test.sh:318-362
- plugin/lib/hostile.test.sh:494-497
- plugin/lib/hostile.test.sh:644-664

---

## Outcome

Built:
- `peal create --owner ai|human --title TITLE` answers Belfry's `tasks.commands.create`.
  It reads one task text on stdin and files it through the storage, including the
  pull-request route on a protected main. It prints the storage's lines, then
  `filed: <id>` as the very last line. The work is done by `peal_create_filed` in
  `plugin/lib/backlog.sh`:
  - The slug is the first five words of the title, normalised by
    `_peal_slug_normalise`, which it shares with `peal_slugify` in `task-text.sh`.
  - `--owner` wins over the text's own frontmatter.
  - It refuses a title of fewer than two words, an owner other than `ai` or `human`, a
    text that sets `merge`, and a text holding the task delimiter.
  - The title is only ever an option value, so a title such as `--batch 0001` stays a
    title.
- `PEAL_MAIN_WRITE_BUDGET` is capped at 90 s under this form unless the caller set it,
  because Belfry allows the command 2 minutes. A pull request still open at the cap
  counts as filed: exit 0 and the `filed:` line. The storage's own status 3 would read
  to Belfry as a failure, and a retry would file the task twice.
- `peal init --stage belfry` writes `create: .peal/peal create --owner {owner} --title
  {title}` for the files storage only. The github-issues contract has Belfry open the
  issues itself.
- `/peal:idea`, when `BELFRY_SESSION` is set:
  - on a task branch: queues offline with `peal idea`, as before;
  - anywhere else: never runs `peal idea` and calls Belfry's `task_create`;
  - when Belfry refuses (not a filing job): hands the text to Belfry's `idea` tool.
- Docs:
  - `docs/design.md`: the Belfry table and example, and the `BELFRY_SESSION` exception,
    agreed by the human and scoped to `/peal:idea`;
  - `docs/security.md`: the stdin boundary;
  - `README.md`: the command list gains `create`.

Decided: all with the human in planning; the answers are under Notes.

Found and left:
- Peal's own `.belfry.yml` does not get the key yet: Belfry accepts it only from the
  release after its #264. It is filed as an idea that depends on 0074.
- There is no `--origin` flag, because Belfry's contract cannot pass one yet. That is
  filed as an idea too.
- The planned "`peal idea` fails fast in a sandbox" idea was not filed: backlog task
  0075 (network-fails-fast) already covers every internal fetch and push, including this
  one.

Review: the reviewer found two blocking issues, both fixed on the branch:
- `peal_store_create` ran in a command-substitution subshell. `PEAL_MW_STATE` was lost,
  and an open PR at the cap died under `set -u` without the `filed:` line. Fixed in
  617dc7b, with a harness case for an open PR at the cap.
- The slug normalisation was a copy of `peal_slugify`'s. It is now shared, in d6c578f.

Next session:
- origin/main (0059, 0063, 0073) was merged into the branch before the review. All the
  harnesses and lint pass on the tip.
- End-to-end filing through Belfry can only be tried once the key is in Peal's
  `.belfry.yml` (the follow-up idea).
