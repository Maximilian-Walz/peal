---
plan: required
touches: [plugin/lib/commit.sh, plugin/bin/peal]
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

---

## Outcome

<!-- Written at close, replacing this comment. -->
