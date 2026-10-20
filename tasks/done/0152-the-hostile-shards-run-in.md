---
milestone: m3
plan: required
priority: high
size: L
model: opus
touches: [plugin/lib/apply.awk, plugin/lib/apply.sh, plugin/lib/apply*.test*, plugin/lib/hostile.test.sh, .github/workflows/ci.yml, docs/security.md, plugin/lib/yaml-lib.awk, plugin/lib/frontmatter.test.sh]
---

# 0152 — The hostile shards run in minutes again, print progress, and a job that hangs fails fast

## Intent

Since `peal apply` (0112, #231) merged, the Linux hostile shards of CI take 7 to 44 minutes each instead of 2 to 5. On main, the four shards took 3, 3, 5 and 2 minutes at a10b7d1 (0129). At 136c108 (0112) they took 7, 8, 28 and 10 minutes. Since 0132 one of them takes about 42 minutes on most runs (43c528a: 19, 11, 17 and 42 minutes). So every pull request waits about 45 minutes for its required `harnesses (ubuntu-latest)`, which waits for the slowest shard. That slows every close, every release (`peal ship bump` waits for its pull request) and every pull request Belfry merges by itself.

The slow shard prints nothing between `== plugin/lib/hostile.test.sh` and its result (on 43c528a: "hostile shard 1/4: ran 724 of 2894 tries", "789 passed", 2509 s). For 40 minutes it looks hung, and a release session cancelled one that would have passed. The workflow sets no `timeout-minutes`, so a real hang would hold a runner for GitHub's 6 hours.

Bring each shard back to a few minutes, make a long shard show that it is alive, and have a job that does hang fail within minutes.

## Scope

- `plugin/lib/apply.awk`: `str()` decodes in time linear in the string's length.
- `plugin/lib/apply.sh`: far fewer process forks per field (a manifest loaded once into variables, the accessors rewritten without forks), behaviour byte-identical.
- `plugin/lib/apply.test.sh`: a 1 MiB escaped string decoded byte for byte under every awk.
- `plugin/lib/hostile.test.sh`: progress lines; a try's input built only when this shard runs the try; checks outside `try()` in shard 1 only; a copied seeded repository if seeding dominates; a round-robin offset per awk pass if the slow tries still cluster.
- `.github/workflows/ci.yml`: `timeout-minutes` on every job, the shard comment brought up to date.
- `docs/security.md`: one sentence on how apply's variable names are guarded.
- Out of scope: helpers apply shares with other commands (`peal_fm_set`, `peal_task_check`, `_peal_files_*`, `peal_ms_load`); what slowness remains there is filed as an idea with the profile.

## Done when

- `apply.test.sh` passes under every awk with no existing expectation edited; a one-off comparison shows apply's stdout, stderr, status and resulting tree byte-identical before and after on the hostile and apply inputs (recorded in the Outcome).
- The 1 MiB decoder case passes byte for byte under every awk.
- An ordinary escaped `file`+`add` apply forks at least 70 % fewer processes and takes under 1 s locally (from 2–4 s); `apply, escaped values [long]` takes under 3 s under mawk and busybox (from 33 s). Numbers before and after in the Outcome, no timing assertion in tests.
- A full serial `bash plugin/lib/hostile.test.sh` passes with the try count unchanged; shards 1/4 to 4/4 pass and their ran counts sum to it; `tools/lint.sh` is clean.
- The pull request's CI log shows a progress line per group and awk with elapsed seconds, and no gap over 60 s unless a single try takes that long.
- On the pull request's CI run every `linux (hostile K/4)` finishes in at most 8 min and `harnesses (ubuntu-latest)` in at most 12, pushed lower where the work allows; per-shard minutes and the macOS job's duration in the Outcome (macOS reported, not gated).
- The jobs of `ci.yml` carry `timeout-minutes`: `changes` 5, `harnesses-macos` 30, `linux` 20, `harnesses-linux` 5, `shellcheck` 10, on the job only.

## Raw

> CI got slow: the hostile shards take up to 42 minutes since peal apply, print nothing meanwhile, and have no timeout. Find what made them slow and bring them back to minutes, show progress, and fail a hang fast.

## Notes

- First suspect, unconfirmed: 0112 added hostile cases (`apply, raw values` and `apply, escaped values [...]`, one per hostile value) whose batch holds a `file` proposal. A `file` makes `peal apply` file a task: a commit (the shard's log shows `commit-msg: a wip commit; the checks are skipped` lines) and a write onto main, which may wait or poll as `peal ship bump` does. Time one such try first. The fix is perhaps a stub for the main write in those cases, or one escaped case instead of one per value.
- The shards split `hostile.test.sh` by tries (`PEAL_HOSTILE_SHARD`), not by time, so the slow cases pile into whichever shard gets them. Splitting by measured time (as the non-hostile shards are) would spread them, but only once each try is fast.
- Progress: a line per group, or every N tries, with the elapsed time, so a long shard is visibly alive.
- `timeout-minutes` on each job of `.github/workflows/ci.yml`, a few times its normal duration. That file never merges by itself under Belfry, so the human merges this one.
- Measured on main's push runs, 2026-10-19 to 10-20.
- 2026-10-20, measured locally (mawk, busybox awk; no gawk or original-awk), serial: `arg_cases` alone 1560 tries in 3 min, no try over 0.56 s. Full run 2428 tries in 15 min. Inside the tries the time is almost all `peal apply` in `awk_channels` (run once per awk): 2–4 s per apply try, and with the 64 KiB `long` value 6–33 s (`apply, escaped values [long]` 33 s). Some of these numbers do not add up exactly; the build re-measures first.
- The first suspect is wrong: apply's write onto main takes the plain push route in the hostile repositories (a local bare remote), so nothing polls (main-write.sh:20-34, 183-185). The `wip commit` lines come from `issues_channels`' own setup commits (hostile.test.sh:506, 557).
- `awk_channels` has 200 tries per awk pass, a multiple of 4, so the same try lands in the same shard under every awk: the `long` tries cluster in one shard.
- The human's answers (2026-10-20): fix as much as possible here, the apply.sh fork cost included; apply cases stay under every awk (the cleaner choice); target at most 8 min per shard and 12 for the required check, with the clear ambition to push lower; timeouts 5/30/20/5/10 on the jobs; one task, not split; shared helpers not changed (idea instead); equivalence as a one-off check; checks outside `try()` in shard 1 only and a copied seeded repository if seeding dominates; built on opus.
- 2026-10-20, measured by the build (local, loaded machine, mawk and busybox; `nawk` is mawk here). One `peal apply` on its own, before → after: escaped `file`+`add` [dollar] 294 → 205 processes (`strace -f`), 0.67 → 0.38 s; of its external commands, `apply.sh`'s own 82 → 21 and the shared helpers' at least 56, unchanged (out of scope, idea queued); `escaped values [long]` 2.3 → 1.15 s under mawk, 30.8 → 4.8 s under busybox, the rest six busybox frontmatter parses of the filed task (shared). `apply.awk` alone on a 1 MiB plain string: busybox over 300 s → 0.09 s, mawk 11.9 → 0.02 s. The 79 hostile apply inputs together: mawk 58 → 39 s, busybox 123 → 47 s. Fixed per-shard cost (`PEAL_HOSTILE_SHARD=1/100000`): 19 s before, 17 s (shard 1) and 11 s (others) after: seeding does not dominate, so no copied repository. Full serial run 821 s, 2428 tries; simulated 4 shards 191–203 s by call order, 196–199 s with the offset per awk pass.
- 2026-10-20, after the first CI run of the pull request: the hostile shards took 13–14 min (shard 1: 844 s, shard 2: 765 s). Under original-awk every apply try still takes about 17 s, and macOS's awk_channels takes 581 s. The 20-min timeout cancelled `linux (rest)`, which normally runs about 20–25 min. The human's answers: a timeout per matrix entry (hostile shards 20, a/b/c 20, rest 45), and go on in this pull request to find and fix the cost of apply under original-awk (onetrue-awk built from source locally), filing what lies outside apply's own code.
- 2026-10-20, the original-awk profile: the cost is not apply's own but `yaml-lib.awk`'s `quoted()`, which read a quoted value one byte at a time with `length()` and `substr()` on the whole value, each of them a walk of the string under onetrue-awk's second edition. Once a hostile task file holds the 64 KiB `long` value, every task scan and frontmatter read takes 11–14 s. The human agreed to widen the scope to `quoted()` (linear, byte-identical) in this pull request, `plugin/lib/yaml-lib.awk` and `plugin/lib/frontmatter.test.sh` added to touches.

## Plan

Agreed 2026-10-20. Size L, model opus, merge by the human (`ci.yml` and a security guard).

1. **Measure first**, numbers into Notes: one `peal apply` per input kind (ordinary escaped, `escaped values [long]`, escaped milestone) under `bash -x` with `PS4='+ $EPOCHREALTIME ${FUNCNAME[0]:-main} '`, time summed per function, forks counted (`strace -f -c` or the trace); the fixed per-shard cost with `PEAL_HOSTILE_SHARD=1/100000` and the new group progress lines; which shard each `[long]` apply try lands in per awk pass.
2. **`apply.awk` `str()` linear** (apply.awk:58-96): read a window `substr(doc, pos, 4096)`, find the next `"`, `\` or newline with `match`, append the plain run in one piece; only special characters go through the existing branch, with the same `fail()` messages, `serr` and `pos` accounting. `skipws` and `literal` unchanged.
3. **`apply.sh` forks cut** (bash 3.2-safe: `printf -v` and `${!name}`, no associative arrays). Names are built only from a proposal index and a key matching `^[a-z_]+$` (asserted in the loader again); values are only ever `printf '%s'` arguments.
   - (a) `_pa_load_manifest`, once after apply.awk (920-932): one `while IFS=$'\t' read` loop sets `PA_T_<i>_<k>`, `PA_K_<i>`, `PA_COUNT`; values via `IFS= read -r -d '' PA_V_<i>_<k> <file`. Array items stay files.
   - (b) Accessors without forks, same contracts: `_pa_type` (72-74), `_pa_val` (77-79) kept for pipe callers plus `_pa_get` (sets `PA_V`, trailing newlines stripped as `$(...)` does) and `_pa_get_raw` for `_pa_line` (152-160); `_pa_has` (82-85); `_pa_bad`/`_pa_ok` (88-102) keep status and detail in `PA_ST_<i>`/`PA_DET_<i>`, read by `_pa_finish` (896-910) and `_pa_answer` (884-892); `r/<i>.task`/`.milestone` become `PA_RT_<i>`/`PA_RM_<i>`; `_pa_file_index` (111-120), `_pa_ms_index` (124-133), `_pa_ms_ids` (515-530) loop over variables; `_pa_json_v` sets `PA_J` (862-881).
   - (c) Call sites converted in `_pa_static` (182-291), `_pa_static_ms` (294-346), `_pa_resolve` (350-360), `_pa_ms_resolve` (494-504), `_pa_frontmatter` (378-401), `_pa_item` (405-490), `_pa_ms_item` (542-652), `_pa_compose` (674-708), `_pa_check` (716-813, field reads only), `_pa_build`'s loop (852-856). Files git or awk reads stay files (`t/*.text`, `ms/`, `order`, `ms.idx`, `changes`).
   - (d) Shared helpers outside apply.sh are not changed; what remains slow there is filed as an idea with the profile.
   - Equivalence: before the refactor, capture stdout, stderr, status and resulting `origin/main` tree on the hostile apply inputs (hostile.test.sh:424-449, every value) and apply.test.sh's inputs; compare after; record the result in the Outcome (no committed fixture). `apply.test.sh` passes with no existing expectation edited.
4. **Fixed per-shard cost** (hostile.test.sh), as far as step 1 shows it matters: (i) `try_runs` says whether the next try lands in this shard; the apply loop (427-446) and `each_input` (329-338) skip building inputs for tries that do not run, `TRIES` still counting every try; (ii) the direct checks outside `try()` (377-388, 405-419, 451-459) run only when `SHARD_K == 1`, the comment at 876-890 updated; (iii) only if `hostile_repo` (110-136) dominates: one seeded repository built once and copied.
5. **Progress** (hostile.test.sh): `run_group` (893-897) / each awk pass prints `hostile: <group> [<awk>] starts at <s>s, ran X of T`; `try()` (282-297) prints a line when 60 s passed since the last; `$SECONDS`, stdout, serial runs too.
6. **Round-robin offset**, if the clustering still shows: shard by `(TRIES - 1 + PASS) % SHARD_N`, `PASS` counting awk passes; comment updated; the total and the sum of ran counts unchanged.
7. **`ci.yml`**: `timeout-minutes` on the jobs only (`changes` 5, `harnesses-macos` 30, `linux` 20, `harnesses-linux` 5, `shellcheck` 10); the comment at ci.yml:84-86 updated to the newly measured duration.
8. **`docs/security.md`** (209-217): one sentence that apply's variable names come only from an index and a key checked against `^[a-z_]+$`.

Rejected: trimming the apply cases per awk; time-weighted sharding; bash 4 associative arrays; rewriting apply as one awk program.

Verification: as `## Done when`.

Ranges relied on: tasks/doing/0152-the-hostile-shards-run-in.md:1-38; plugin/lib/apply.awk:1-245; plugin/lib/apply.sh:58-133, 150-160, 182-346, 350-401, 405-490, 494-530, 542-652, 674-708, 716-813, 831-859, 861-979; plugin/lib/hostile.test.sh:105-136, 276-338, 346-361, 363-459, 496-512, 554-558, 876-935; plugin/lib/test-lib.sh:62-87; plugin/lib/main-write.sh:18-34, 128-215, 307-358; plugin/lib/apply.test.sh:68; .github/workflows/ci.yml:36-163; tools/test-all.sh:27-33; docs/security.md:209-217; docs/reference/configuration.md:27.

---

## Outcome

The cost was `peal apply` itself, run once per awk in `awk_channels`, not its write onto main (the hostile repositories push to a local bare remote, so nothing polls). Two things made each apply try cost 2–33 s:
- `apply.awk`'s string decoder appended one byte at a time, so it took time quadratic in a string's length (the 64 KiB `long` value: over 300 s for 1 MiB under busybox);
- `apply.sh` forked one or more processes for every field it read.

`awk_channels` has 200 tries per awk pass, a multiple of 4, so the same slow tries landed in the same shard under every awk: one shard took about 42 min.

Built:
- `apply.awk` `str()` reads 4096-byte windows and appends plain runs in one piece; an escape that may cross a window's end reloads at the backslash. Errors are unchanged: the reviewer compared old and new on 448 documents with escapes at the window edges, under mawk and busybox, identical every time. A 1 MiB string now decodes in 0.09 s under busybox.
- `apply.sh` loads apply.awk's manifest once into variables (`PA_T_<i>_<k>`, `PA_V_<i>_<k>`, `PA_K_<i>`, status and detail in `PA_ST_<i>`/`PA_DET_<i>`), read without forks. Names are built only from digits and keys checked against `[a-z_]` (docs/security.md says so). bash 3.2-safe: `printf -v`, `${!n-}`, `read -d ''`. apply.sh's own external commands per ordinary apply went from 82 to 21; an ordinary escaped `file`+`add` apply takes 0.38 s instead of 0.67 s here.
- `_pa_chomp` strips trailing newlines as `$(...)` does, in linear time. The reviewer found the first version (one newline at a time) took 17.5 s for 30,000 trailing newlines in an outsider field. The obvious regex `$'\n'+$` and the pattern `${v##*[!\n]}` are quadratic too (4 s and 5.6 s), hence the doubling-and-bisection helper (0.009 s). apply.test.sh's `trailing` case covers it.
- `hostile.test.sh`:
  - prints `hostile: <group> [<awk>] starts at Ns, ran X of T` at each group and awk pass, and a line from `try()` after 60 s without one;
  - builds a try's input only when this shard runs it;
  - runs the checks outside `try()` in shard 1 only;
  - offsets the round-robin by awk pass, so the same try moves shard from awk to awk.
  The fixed per-shard cost is 11–19 s, so no copied seeded repository was needed.
- `ci.yml`: `timeout-minutes` on every job (changes 5, harnesses-macos 30, linux 20, harnesses-linux 5, shellcheck 10), and the shard comment brought up to date.

Verified locally (mawk, nawk = mawk, busybox; gawk and original-awk only in CI):
- apply.test.sh passes under every awk, 417 checks, with no existing expectation edited; the 1 MiB decoder case passes byte for byte.
- A one-off comparison of old and new apply covered stdout, stderr, status and the remote's diff, log and refs. The 79 hostile apply inputs are byte-identical under mawk and busybox. apply.test.sh's 258 apply calls are identical except:
  - a `peal/main-write-<sha>` branch name, with the same tree;
  - a stray `cat: <tmp>/s/t/NNNN.last: No such file or directory` line on stderr. It came for a split_milestone refused after its task was loaded, and leaked a temporary path; the reviewer judged its loss acceptable.
- The full serial hostile run passes: 2428 tries, unchanged, in 821 s.
- Shards 1/4 to 4/4 pass, ran 608, 606, 607 and 607 (sum 2428), and took 206, 192, 179 and 198 s here.
- `tools/lint.sh` is clean.

The per-shard minutes on CI, the required check's duration and the macOS job's duration come from this pull request's run.

For the next session: `ci.yml` never merges by itself; the human merges this. What remains of apply's cost is in helpers it shares with other commands (config parsed six times, frontmatter once per field, a YAML parser quadratic under busybox), filed as an idea with the profile. The commit 3ba7100 is a session-end autosave of the `_pa_chomp` fix, completed by 6cf4642.

After close, on the pull request's CI:
- The first run still took 13–14 min per hostile shard. Under original-awk, every try after a task holding the 64 KiB `long` value was filed took 12–25 s, because each task scan and frontmatter read parsed that value in time quadratic in its length: `yaml-lib.awk` `quoted()` read it one byte at a time, and onetrue-awk walks the whole string on each `length`/`substr`.
- With the human's agreement the scope widened to that shared helper: `quoted()` now appends whole runs split at `'` or `\`. It is byte-identical with the old one on 114,974 inputs under mawk, busybox, onetrue-awk 20250804 and 20210215, in both C and C.UTF-8. `frontmatter.test.sh` gained a long-value case.
- That case first used bash `${x//pat/rep}` on ~98 KB strings, which under macOS's bash 3.2 takes far over 30 min and hit the job's timeout. It now builds its expected values by doubling. Under bash 3.2.57 built from Apple's source, the file runs in 6.9 s.
- The 20-min job-wide timeout cancelled `linux (rest)`, which runs about 20–25 min, so the human chose a timeout per matrix entry: hostile shards and a/b/c 20, rest 45.
- main's 0154 (apply reads and answers Belfry's contract) was merged in, ported onto the variable-based reads; apply.test.sh passes under mawk, busybox and onetrue-awk.
- Final CI on 6fdf548: all 12 checks green. The hostile shards take 155, 144, 176 and 184 s (from 19, 11, 17 and 42 min); macOS's hostile `awk_channels` takes 606 s, and its whole job passes within its 30 min.

### Escalations

- Done when: "forks at least 70 % fewer processes". Met for apply.sh's own commands (82 to 21, −74 %). Not met for the whole process tree (294 to 205, −30 %): at least 56 of the remaining processes are in shared helpers, which the agreed scope keeps out. Filed as the idea on those helpers.
- Done when: "`apply, escaped values [long]` takes under 3 s under mawk and busybox". Met under mawk (2.3 to 1.15 s). Not under busybox (30.8 to 4.8 s): about 5 s go to six frontmatter parses of the filed task in the shared YAML helpers, out of scope by the same answer. Same idea.

### Reviewer findings not acted on

- None: the one blocking finding (quadratic trailing-newline stripping) was fixed in 3ba7100 and 6cf4642, and the stderr departure is recorded above.
