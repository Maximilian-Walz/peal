---
milestone: m1
plan: required
size: M
touches: [.github/workflows/ci.yml, plugin/lib/hostile.test.sh]
---

# 0077 — Speed up the Linux CI job, the one pull requests actually wait on

## Intent

0065 (the macOS side of the hostile harness) found that CI's history contradicts its
own starting premise: since 0039, the Linux harnesses job has taken 29-36 minutes
against macOS's 21-24 (runs 36129832834 and 36163270642). Linux, not macOS, is the job
a pull request actually waits on. 0065 only trims the macOS job's set and forces
/bin/bash there; this task speeds up Linux itself.

## Scope

- Find where the Linux job's time actually goes: `apt-get update`/install of the awks,
  `npm install -g @anthropic-ai/claude-code`, or the harnesses themselves (0065 added
  per-harness timing output to `tools/test-all.sh`; use it).
- Cut it: caching the apt/npm installs across runs, running harnesses in parallel, or
  trimming what has to run on every pull request, whichever the numbers point to.
- `.github/workflows/ci.yml` and `plugin/lib/hostile.test.sh` (widened by the human);
  the required check names stay as they are (shellcheck, `harnesses (ubuntu-latest)`,
  `harnesses (macos-latest)`, required by main's ruleset).
- Fix the KNOWN matching in hostile's `try()` (it cuts entries at their first space,
  while labels contain spaces).

## Done when

- The Linux side takes under 10 minutes wall-clock on a normal pull request (today
  34m40s, run 36389556208), with a real run's number quoted in the pull request that
  closes this.
- Every harness that runs on Linux today (all 27, or their replacement) still does;
  nothing Linux alone covers stops running there.

## Raw

Filed from 0065, whose human answers said: the macOS goal is at most 1/3 of today's
time, as written; the Linux time becomes this follow-up task.

## Notes

- 0065's plan: "the planner found that CI's history contradicts the premise. Since
  0039, Linux takes 29-36 minutes and macOS 21-24 (runs 36129832834 and 36163270642),
  so Linux is the job pull requests wait on."
- 0065 added per-harness elapsed-seconds output to `tools/test-all.sh`; start from a
  real run's numbers rather than guessing which step is slow.
- Measured on main, run 36389556208: Linux job 34m40s, of which setup 13s (awks 10s,
  Claude Code 3s) and harnesses 34m22s run serially. Per harness (s): hostile 847,
  close 268, store-issues 163, decisions 113, store-files 106, work 79, backlog 69,
  claim 69, githooks 52, ship 49, tasks 49, main-write 42, review 28, session 28, init
  24, setup 21, frontmatter 15, git-guard 14, milestones 14, commit 5, config 3, the
  rest 0-2. Caching installs is pointless; parallel runners are the lever.
- The repository is public (runners free, 4 vCPU); main's ruleset requires shellcheck,
  `harnesses (ubuntu-latest)` and `harnesses (macos-latest)`.
- Human's answers (planning):
  - The required check `harnesses (ubuntu-latest)` may become a gate job over parallel
    `linux (...)` shard jobs.
  - Widen touches to `plugin/lib/hostile.test.sh` for a real shard knob, so ci.yml does
    not copy the awk list or group names, with coverage/KNOWN working across a split.
  - Target under 10 minutes; split arg_cases too.
  - Accept per-try slicing's state drift inside a group (documented in the header
    comment; a local serial run still covers the exact sequence).
  - The implementer measures and picks N between 4 and 6 hostile shards, keeping the
    longest shard under about 6 minutes.
  - Fix the KNOWN matching bug here, not as an idea.
  - Defaults kept: 27 harnesses; macOS job unchanged; no concurrency block; shard names
    as planned; an idea for a local `-j` mode in `tools/test-all.sh` filed at close.

## Plan

Agreed with the human; size M, model default, merge default.

**hostile.test.sh: `PEAL_HOSTILE_SHARD=K/N`.** Unset or `1/1` is today's full serial
run. Malformed (`0/4`, `5/4`, `x`, `3`, `2/`) exits 2 with a message before anything
runs. `try()` counts every call in a global `TRIES`; with the knob set, a shard runs a
try only when `(TRIES - 1) % N == K - 1` and otherwise returns without `assess`. Group
bodies (`hostile_repo`, `cover`, direct `check`/`check_fails`/`self_test`) still run in
every shard, so `COVERED` is complete per shard and `coverage()` runs in each as today
(only when `PEAL_HOSTILE_CASES` is unset); no cross-job aggregation. KNOWN: fix the
matching (entries are cut at the first space while labels contain spaces) so an entry
matches its full `label:kind`; record the labels each shard ran and have the final
"KNOWN still found" loop skip entries whose label did not run in this shard. Each run
prints `hostile shard K/N: ran X of T tries` (serial too) and fails if X is 0 while
T > 0. Header comment documents the knob next to `PEAL_HOSTILE_CASES`, including that
slicing skips other shards' state-changing tries. Composes with `PEAL_HOSTILE_CASES`
and `PEAL_TEST_AWK` unchanged. `test-lib.sh` not expected to change.

**ci.yml.** macOS job: name, trimmed set and `PEAL_HOSTILE_CASES` unchanged; only its
dead `if: runner.os == 'Linux'` steps go. New job `linux`, a matrix with
`fail-fast: false`, each shard installing the awks and Claude Code and setting
`PEAL_REQUIRE_CLAUDE=1`, `PEAL_REQUIRE_JQ=1`:
- N hostile shards `linux (hostile K/N)`: `tools/test-all.sh plugin/lib/hostile.test.sh`
  with `PEAL_HOSTILE_SHARD: K/N`; N appears once. The implementer measures locally and
  picks N in 4-6 so the longest shard stays under about 6 minutes.
- Non-hostile shards balanced by measured seconds, e.g. A: close, frontmatter,
  git-guard (~297s); B: store-issues, decisions, milestones (~290s); C: store-files,
  work, backlog, githooks (~306s); `rest`: computed in the step as `find . -name
  '*.test.sh' -not -path './.git/*'` minus every path the other shards name (hostile
  included), printed, then run (~323s). A missing named path fails `bash`. No
  `PEAL_HOSTILE_SHARD` or `PEAL_TEST_AWK` in these.
- Gate job named `harnesses (ubuntu-latest)`: `needs: linux`, `if: always()`, fails
  unless `needs.linux.result == 'success'`; no checkout, workflow `contents: read`.
  `always()` is essential: a skipped required check counts as passing.
Every `uses:` stays pinned by SHA. Expected wall-clock about 6.5-7 minutes.

**Verification.** Locally: serial `bash plugin/lib/hostile.test.sh` passes with today's
count and prints T; `PEAL_TEST_AWK=mawk PEAL_HOSTILE_SHARD=1/2` and `2/2` pass, print
the same T as unsharded mawk, X values sum to T, coverage in both; bad knob values exit
2; macOS's `PEAL_HOSTILE_CASES="self_test awk_channels"` passes unsharded; a KNOWN entry
with a spaced label matches (demonstrated, then removed); `tools/lint.sh` passes. On the
pull request: the gate is green and the run's time is quoted (target under 10 min);
hostile shards' X sum to the serial T; the union of harnesses across shards is all 27;
a temporary failing commit turns the gate red (not skipped), then is dropped; macOS and
shellcheck green and unchanged.

Ranges: tasks/doing/0077-speed-up-linux-ci.md:1-50, .github/workflows/ci.yml:1-77,
tools/test-all.sh:1-41, plugin/lib/hostile.test.sh:27-66,
plugin/lib/hostile.test.sh:170-310, plugin/lib/hostile.test.sh:326-468,
plugin/lib/hostile.test.sh:472-638, plugin/lib/hostile.test.sh:642-675,
plugin/lib/hostile.test.sh:700-732, plugin/lib/test-lib.sh:17-28,
plugin/lib/test-lib.sh:62-93, tools/install.test.sh:11-18, docs/security.md:194-206,
docs/milestones/m1.md:16-24.

---

## Outcome

The Linux side of CI now runs on parallel runners and takes 7m25s instead of 34m40s:
PR run 36400885058, from the run's start to the gate going green. The PR's first run,
36399839580, took 6m49s. The required check names are unchanged.

**What was built**
- `plugin/lib/hostile.test.sh` gains `PEAL_HOSTILE_SHARD=K/N`.
  - `try()` counts every call and, when sharded, runs only every Nth try (round-robin
    by call order).
  - Group bodies, `cover` and the direct checks run in every shard, so each shard's
    coverage check is complete on its own and no job has to combine results.
  - Every run prints `hostile shard K/N: ran X of T tries` (serial runs as `1/1`) and
    fails when X is 0.
  - Malformed values exit 2 before anything runs.
  - With the knob unset, a run behaves exactly as before, including macOS's
    `PEAL_HOSTILE_CASES`.
- KNOWN matching, fixed as the human asked:
  - `try()` compares a KNOWN entry whole. It used to cut the entry at its first space,
    and labels contain spaces.
  - The final "KNOWN still found" loop cuts the label at the last colon, since labels
    such as `issues: list` contain colons (reviewer's finding).
  - In a full run it checks every entry. Only a sharded run (N>1) skips entries whose
    label it did not run.
- `.github/workflows/ci.yml`:
  - The `harnesses` job is now macOS only, still named `harnesses (macos-latest)`.
  - A new `linux` matrix has 4 hostile shards and 3 shards balanced by measured
    seconds: a = close, frontmatter, git-guard; b = store-issues, decisions,
    milestones; c = store-files, work, backlog, githooks.
  - A `rest` shard runs every `*.test.sh` the others don't name. It reads a/b/c's lists
    by YAML alias, so there is no second copy (reviewer's finding), and it prints its
    list. On CI it ran 16 harnesses: 1 + 3 + 3 + 4 + 16 = all 27.
  - The gate job `harnesses (ubuntu-latest)` has `needs: linux` and `if: always()`, and
    fails unless every shard succeeded.

**How it was checked**
- Locally with mawk:
  - A serial run found T=1496, and shards 1/2 and 2/2 ran 748 + 748.
  - Shard 1/4 ran 374. Every run passed.
- The full serial run under every local awk passed: 1784 tries, 1820 checks.
- On CI, a temporary commit replaced shards a/b/c's command with `false`. The gate
  concluded `failure`, not skipped, and the commit was then reverted: the `wip:` commit
  and its revert stay in the branch's history.

**Timings (run 36400885058)**
- Hostile shards: 2m36s to 5m20s.
- Shards a, b, c and rest: 5m33s to 7m13s.
- macOS: 8m20s, unchanged.
- The longest Linux shard is now c, a non-hostile one. To go faster, rebalance a/b/c and
  rest, or add a shard. Hostile's N is one number in ci.yml.

**Not checked on CI**
- The CI log lines showing the hostile shards' X adding up to T were not read: the
  sandbox cannot fetch Actions logs (friction reported). The sums were checked locally.

**Decisions** (human's answers, in Notes)
- The required check becomes a gate job.
- Per-try slicing's state drift inside a group is accepted and documented in the
  harness's header.
- Fewer than 10 minutes was the target. N=4 was the implementer's choice within the
  agreed 4-6.

**Idea filed at close**
- `test-all-parallel-mode`: a `-j` flag for local `tools/test-all.sh` runs, which are
  still serial, about 35 minutes.

### Reviewer findings not acted on

- "Done when line 1 not met yet": met since the review, 7m25s on run 36400885058, as
  above.
