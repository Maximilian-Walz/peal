---
milestone: m3
plan: required
priority: high
size: L
model: opus
touches: [plugin/lib/apply.awk, plugin/lib/apply.sh, plugin/lib/apply*.test*, plugin/lib/hostile.test.sh, .github/workflows/ci.yml, docs/security.md]
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

<!-- Written at close, replacing this comment. -->
