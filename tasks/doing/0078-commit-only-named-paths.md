---
plan: required
touches: [plugin/lib/commit.sh, plugin/lib/commit.test.sh, plugin/bin/peal, docs/design.md, plugin/agents/implementer.md]
priority: high
milestone: m2
size: S
---

# 0078 — `peal commit` with paths commits only those paths

## Intent

`peal commit "<msg>" <paths>` stages the named paths with `git add -- "$@"` and then commits the whole index, so whatever was already staged goes into the commit too. In 0057 about 22 sandbox placeholder files rode along that way, and it took a `git rm --cached` commit to take them out. With paths given, the commit should hold only those paths (`git commit -- <paths>`), or refuse while other paths are staged.

## Scope

`peal commit SUBJECT [--body…] PATH...` commits exactly the named paths, resolved from the caller's directory; everything else in the index stays staged and out of the commit. `peal commit` without paths is unchanged. The help text, design.md and the implementer's instructions say so.

## Done when

- `peal commit SUBJECT PATH...` commits exactly the named paths; other staged changes stay staged and out of the commit.
- The commit-msg gate judges only the committed paths.
- "Nothing to commit" and the new-backlog-file refusal consider only the named paths.
- Named paths resolve from the caller's directory, as git's do; absolute paths work too.
- `peal commit` without paths is unchanged.
- `plugin/lib/commit.test.sh` covers each of the above; the help text and `docs/design.md` say so.

## Raw

> From task 0057, which could not file it itself: the sandbox blocks the push to main. peal commit with paths commits only those paths. `peal commit "<msg>" <paths>` stages the named paths with `git add -- "$@"` but then commits the whole index, so anything already staged goes into the commit too. In 0057 about 22 sandbox placeholder files rode along that way, and it took a `git rm --cached` commit to take them out. When paths are given, commit only those paths (`git commit -- <paths>`), or refuse while other paths are staged.

## Notes

Revised 2026-09-28: priority high: goes into Peal's next patch release (daily-use fixes after m1)

- Open: only the named paths, or a refusal while others are staged?
- Open: what `peal commit` without paths should do; it commits the whole index today.
- Related: 0075 (sandbox placeholder files no longer count as uncommitted work).

The human's answers at planning (2026-09-28):
- With paths: commit only the named paths (`git commit -- PATHS`), the rest left staged, nothing printed about it; no refusal.
- Without paths: unchanged (`git add -A`, commit everything).
- Undoing peal commit's own `git add` when the gate refuses: not in this task; file it as an idea.
- Paths from a subdirectory: fix here; named paths resolve from the caller's directory.
- During a merge: let git's refusal of a partial commit surface through the existing "the commit was refused (above)" path.
- Named paths with no change: keep "nothing staged, nothing to commit".
- A named new backlog file: refused and unstaged, as today.
- Finding: the Note's "Related: 0075" most likely means 0087 (sandbox-mount-placeholder-outside-sandbox); 0075 is network-fails-fast.

## Plan

Agreed 2026-09-28. Size S, model default, merge default.

Approach, in `plugin/lib/commit.sh` (`peal_commit`), the paths branch only:
1. Before `cd "$top"`, capture `git rev-parse --show-prefix`; prepend it to each named path not starting with `/` (absolute paths pass as they are; `--` still guards hostile values).
2. `git add -- PATHS` as today, so new and deleted files are known.
3. Backlog refusal over the named paths only: `git diff --cached --name-only --no-renames --diff-filter=A -- PATHS`, then filtered to `$tasks/backlog/` (a second pathspec would OR, not AND); unstage and refuse only those.
4. "Nothing staged" over the named paths only: `git diff --cached --quiet -- PATHS`.
5. `git commit -q -m SUBJECT [-m BODY] -- PATHS` (git's `--only`): the hooks run on a temporary index of HEAD plus the paths, so the gate's `_peal_staged` sees only them; other staged entries remain staged afterwards. Git's refusal during a merge surfaces through the existing refused path.
Without paths: unchanged. Check every internal caller of `peal_commit` (e.g. `peal_store_record`) still passes paths that resolve from where it runs.

Files: `plugin/lib/commit.sh`, `plugin/lib/commit.test.sh`, `plugin/bin/peal` (help text: PATHs relative to the current directory, only those committed), `docs/design.md` (the `peal commit` bullet), `plugin/agents/implementer.md` (one clause).

Verification (`bash plugin/lib/commit.test.sh`, new cases):
- a file staged elsewhere is not committed and stays staged (the 0057 regression);
- the gate sees only the named paths (a `(tasks)` commit of a task file succeeds with a non-task file staged, and/or a `checks.commit` item on another path does not run);
- named path unchanged while something else is staged: refused "nothing staged, nothing to commit", HEAD unchanged, the other file still staged;
- a new backlog file staged but not named is neither refused nor unstaged; named, still refused and unstaged;
- a deleted file as a named path commits the deletion;
- a path named from a subdirectory commits that file; an absolute path works;
- the existing cases, `bash plugin/lib/hostile.test.sh` and the harness covering `peal record` still pass.
Also: file an idea for restoring the index when the gate refuses a no-path commit.

Ranges: plugin/lib/commit.sh:1-80, plugin/lib/commit.test.sh:1-81, plugin/bin/peal:42-43, plugin/bin/peal:116-118, plugin/bin/peal:411, plugin/lib/githooks.sh:375-377, plugin/lib/githooks.sh:419-440, plugin/lib/githooks.sh:487-497, plugin/lib/store-files.sh:1039-1045, plugin/lib/hostile.test.sh:688-690, plugin/lib/common.sh:10-15, docs/design.md:656-657, docs/design.md:681-683, plugin/agents/implementer.md:23-27, plugin/commands/close.md:66-68, README.md:77, tasks/done/0057-branch-date-utc.md:122, tasks/done/0075-network-fails-fast.md:37, tasks/backlog/0087-sandbox-mount-placeholder-outside-sandbox.md:9-38.

---

## Outcome

<!-- Written at close, replacing this comment. -->
