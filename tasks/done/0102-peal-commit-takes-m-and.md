---
plan: required
touches: [plugin/lib/commit.sh, plugin/lib/commit.test.sh, plugin/bin/peal, docs/reference/cli.md]
milestone: m3
size: S
---

# 0102 — `peal commit` takes `-m` and answers `--help`

## Intent

Sessions call `peal commit` the way they call git: `peal commit -m "<subject>" <file>`. `peal_commit` (`plugin/lib/commit.sh`) treats its first argument as the subject. So `-m` becomes the subject, and the real subject is passed to `git add` as a pathspec, which fails. `peal commit --help` is no better: it hands `--help` to the commit-msg hook as a subject. Once this task is done, `-m SUBJECT` is accepted as the subject, `-h`/`--help` print the usage line and exit 0 without committing, and any other leading option is refused with the usage line instead of being taken as a subject.

## Scope

- `peal_commit`: `-m SUBJECT` as the first argument means the subject; `-h`/`--help` print usage.
- Any other leading `-` argument is refused with the usage line rather than taken as a subject.

## Done when

- The commit harness covers `-m`, `--help` and an unknown leading option.

## Raw

> `peal commit` takes `-m` and answers `--help`
>
> Sessions call `peal commit` git-style, `peal commit -m "<subject>" <file>`. `peal_commit` (plugin/lib/commit.sh) takes its first argument as the subject, so `-m` becomes the subject and the real subject goes to `git add` as a pathspec, which fails. `peal commit --help` passes `--help` to the commit-msg hook as a subject. When this is done, `-m SUBJECT` is accepted as the subject, and `-h`/`--help` print the usage line and exit 0 without committing.
>
> Scope: `peal_commit`: `-m SUBJECT` as the first argument means the subject; `-h`/`--help` print usage. Any other leading `-` argument is refused with the usage line rather than taken as a subject.
>
> Done when: the commit harness covers `-m`, `--help` and an unknown leading option.
>
> Belfry friction, 2026-09-28 (job 95c28f566730ea0e): "`peal commit` does not accept `-m` or `--help`: `-m` is treated as the subject (git add fails on the message as a pathspec), and `--help` is passed to the commit-msg hook as a subject." Workaround: the subject passed positionally.
>
> Frontmatter as given: `plan: optional`, `touches: [plugin/lib/commit.sh, plugin/bin/peal]`.

## Notes

- Triage: this is `plan: required`, because the work touches `plugin/`, which is in `plan.required-paths`. The idea asked for `plan: optional`, but that is not a valid value. It touches `plugin/lib/commit.sh` and `plugin/bin/peal`, which the idea names. It has no milestone: nothing ties it to m2's goals.
- The human wrote Scope and Done when themselves, so those sections are kept as written rather than left empty.
- Open question: should `-m` also be accepted after paths or after `--body` (git allows options anywhere), or only as the first argument, as the Scope says? And should `-m` together with a positional subject be refused?
- The usage line printed by `--help` should be the one `peal_commit` already prints on an empty subject, so there is only one copy.
- Plan answers (2026-10-18, human): `-m` only as the first argument; a second `-m` after the subject is refused clearly ("commit: -m goes first, once; the body is --body"); the usage text stays the current string with `[-m] ` inserted (stdout for `--help`, stderr through `peal_err` for refusals); `docs/reference/cli.md` is updated too. Planner defaults kept: `--` first is an unknown option; `--help` works outside a configured project. The note above saying the task has no milestone is stale: it is in m3.

## Plan

Approach:
- `plugin/lib/commit.sh`: one helper `_peal_commit_usage` prints the single usage string, `commit [-m] "<type>(<area>): <what> [NNNN]" [--body TEXT | --body-file FILE] [PATH...]` (the current one with `[-m] ` inserted); the empty-subject refusal (stderr, through `peal_err`) and `--help` (stdout, no prefix) both use it. At the top of `peal_commit`, before `subject=$1`, a `case ${1-} in`: `-h|--help)` usage to stdout, `return 0`; `-m)` require `$2` (else refuse "-m needs a subject"), subject `$2`, `shift 2`; `-*)` `peal_err "commit: unknown option $1"`, usage on stderr, `return 2` (covers `--`); `*)` today's behaviour. The empty-subject check stays (covers `-m ""`). In the loop after the subject (around commit.sh:59-63) a `-m` is refused: "commit: -m goes first, once; the body is --body". Header comment (lines 6-14) shows `[-m] SUBJECT`.
- `plugin/bin/peal`: the `commit)` dispatch (line ~485) skips `peal_config_load` for `-h|--help`, so help works outside a configured project; the usage block (line ~159) shows `[-m] SUBJECT`, keeping the `  commit …` line shape that `plugin/commands/commands.test.sh` parses.
- `docs/reference/cli.md:200-208`: signature to `[-m] SUBJECT`, one sentence on `--help` and the unknown-option refusal.
- The positional form, and its internal caller `plugin/lib/store-files.sh:1158`, are unchanged.

Verification (`bash plugin/lib/commit.test.sh`, new cases in `cases()`):
- `--help`: exit 0, stdout has `<type>(<area>): <what>`, HEAD and `git status --porcelain` unchanged (a file written first, so nothing staged proves `git add` did not run).
- `-h`: the same.
- `--help` outside a Peal project: exit 0 with the usage.
- `-m SUBJECT PATH`: commits only that path, `git log -1 --format=%s` is the subject.
- `-m SUBJECT --body TEXT PATH`: the body lands.
- `-m` alone: refused with "-m needs a subject".
- An unknown leading option (`--amend`, `-x`): refused with the usage and the option named; HEAD unchanged, nothing staged.
- A second `-m` after the subject: refused with "-m goes first, once".
- Existing cases still pass, and `plugin/commands/commands.test.sh`.

Ranges relied on:
- plugin/lib/commit.sh:1-138
- plugin/lib/commit.test.sh:1-161
- plugin/lib/test-lib.sh:31-60
- plugin/lib/common.sh:5-7
- plugin/bin/peal:153-162
- plugin/bin/peal:460-489
- plugin/lib/store-files.sh:1158
- plugin/commands/commands.test.sh:19
- docs/reference/cli.md:200-208
- docs/milestones/m3.md:1-27

---

## Outcome

`peal commit` now reads its first argument as an option when it starts with `-`. `-m SUBJECT` sets the subject. `-h`/`--help` prints the usage to stdout and exits 0 without staging or committing; it works outside a configured project too, because `plugin/bin/peal` skips the config load for it. Any other leading option, `--` included, is refused (exit 2) with the usage on stderr. A second `-m` after the subject is refused with "commit: -m goes first, once; the body is --body". Both help and the refusals use one helper, `_peal_commit_usage` in `plugin/lib/commit.sh`, so there is one copy of the usage text: the old string with `[-m] ` inserted. The positional form and its internal caller in `store-files.sh` are unchanged. `docs/reference/cli.md` shows the new signature.

Decided with the human at plan time: `-m` is accepted only as the first argument (not git-style anywhere), the usage text is the old one with `[-m]` added, and cli.md is updated even though it was outside the written Scope.

`plugin/lib/commit.test.sh` covers `--help`, `-h`, `--help` outside a project, `--amend`/`-x`/`--`, a bare `-m`, a second `-m`, `-m SUBJECT PATH` and `-m` with `--body`; 180 passed, 0 failed, under every installed awk. `plugin/commands/commands.test.sh` passes. Implementer departures: the empty-subject refusal no longer doubles its `commit:` prefix, and the existing "no subject" test matches on `"<type>(<area>): <what>` because `[-m]` would be a glob class in the pattern.

The reviewer found nothing blocking. Its two cosmetic points (a trailing space in the unknown-option message, an over-long line in cli.md) were fixed in a commit of their own. No ideas were filed.
