---
milestone: m1
plan: required
touches: [plugin/lib/common.sh, plugin/lib/close.sh, plugin/lib/store-files.sh, plugin/lib/store-issues.sh, plugin/lib/claim.sh, plugin/lib/session.sh, plugin/lib/common.test.sh, plugin/lib/close.test.sh, plugin/lib/backlog.test.sh, plugin/lib/claim.test.sh, plugin/lib/session.test.sh]
size: M
---

# 0084 — Every uncommitted-work check ignores untracked character devices

## Intent

Task 0075 stopped the Stop hook and `close finish` from counting an untracked
character device as uncommitted work. In a sandbox, `/dev/null` is mounted over
protected paths, and git lists those mounts as untracked files. `close verify` and the
defer uncommitted-work checks in the files and issues storages still count them, so a
sandboxed session can be told it has unfinished work when it has none. Those checks
should filter the same way, through `peal_status_porcelain`.

The harness cases that cover the filter need `mknod`, and a sandbox or most CI runners
do not allow it, so they are skipped there. As things stand nothing in CI exercises the
filter. The task also needs a fixture that exercises it without that privilege.

## Scope

Every place Peal decides whether a worktree holds uncommitted work ignores an untracked
path that is a character device (a sandbox's `/dev/null` mount over a protected path):
`close verify`, the files and issues defer checks, the release/reaper dirty verdict, and
the session-end autosave (whose `git add -A` must also not stage one). The helper
`peal_status_porcelain` gives the right answer from any directory. The filter is proved by
cases that always run: a symlink to `/dev/null` replaces the `mknod` fixtures, which are
deleted.

Out of scope: paths git quotes; a device inside an untracked directory without
`--untracked-files=all`; mount placeholders seen from outside the sandbox (an idea).

## Done when

- `common.test.sh`, `close.test.sh`, `backlog.test.sh`, `claim.test.sh` and
  `session.test.sh` are green, their character-device cases run unconditionally (no
  "mknod ... skipped" line anywhere), and each case's control shows raw git listing the
  link.
- `close verify` gives `READY 0` with the link present; both defers are not refused for
  it, and still refused (listing only the real file) for a real one; release and reap
  succeed with it; the autosave commits the real work and not the link, and makes no
  commit when only the link is there.
- `peal_status_porcelain` filters the device when run from a subdirectory.
- Reverting each code edit once makes a named case fail (said in the Outcome).
- `tools/lint.sh` is clean.

## Raw

> close verify and the defer uncommitted-work checks (store-files.sh, store-issues.sh) still count an untracked character device (a sandbox's /dev/null mount over a protected path) as uncommitted work; 0075 fixed only the Stop hook and close finish. Use peal_status_porcelain there too. Also: the char-device harness cases skip wherever mknod is not permitted (this sandbox, most CI), so nothing actually exercises the filter; find a fixture that does.

## Notes

- Split off from 0075, which is in m1.
- Open question: which fixture works without `mknod`? A symlink to `/dev/null` passes
  `[ -c ]` but git lists it as a symlink. That would test the filter's side effect, not
  the case it is meant for. A test hook that overrides the device check is another
  option.
- Planning (human's answers, 2026-09-28):
  - Fixture: the symlink to `/dev/null` replaces the `mknod` cases, which are deleted.
    Git lists only regular files, symlinks and directories as untracked (`dir.c`
    `treat_path`), so a real `mknod` device never shows up and those cases were vacuous;
    the sandbox mount (a regular file on disk, a device through `lstat`) looks to git and
    to `[ -c ]` just like the symlink.
  - `peal_status_porcelain` resolving root-relative paths is fixed in this task
    (`common.sh`).
  - `claim.sh` (release/reaper dirty verdict) and `session.sh` (session-end autosave) are
    in this task.
  - Placeholders seen from outside the sandbox (an empty regular file: still dirty,
    autosave would commit it): build as planned, record in the Outcome, file an idea.
  - A device inside an untracked directory (`?? dir/`): unchanged, noted in the Outcome.
  - Defaults kept: quoted paths out of scope; an untracked symlink to a device is
    filtered too (said in the helper's comment); issues defer prints the filtered list;
    macOS checked through the CI run; a worktree holding only a device gets no wip
    commit at session end but is still pushed.

## Plan

**Approach**
- `plugin/lib/common.sh`: `peal_status_porcelain` resolves `top=$(git rev-parse
  --show-toplevel)` once and tests `[ -c "$top/$path" ]`; output and arguments
  unchanged; comment says an untracked symlink to a device is filtered too. New
  `peal_untracked_devices`: root-relative paths of untracked character devices, one per
  line, from `git status --porcelain -z --untracked-files=all` (used by the autosave
  only). Bash 3.2 safe: no `mapfile`; arrays built with `while read`, expanded as
  `${arr[@]+"${arr[@]}"}`.
- `plugin/lib/close.sh:654` (`close verify`, already in `$top`): `peal_status_porcelain`.
- `plugin/lib/store-files.sh:567`: `peal_status_porcelain --untracked-files=all`
  (:636 unchanged).
- `plugin/lib/store-issues.sh:676-678`: capture `peal_status_porcelain
  --untracked-files=all` once; test it and print it through `cut -c4- | sed`.
- `plugin/lib/claim.sh:342`: `[ -n "$(cd "$path" && peal_status_porcelain 2>/dev/null)" ]`.
- `plugin/lib/session.sh:221-222`: guard `[ -n "$(peal_status_porcelain)" ]`; stage with
  `git add -A -- . ':(exclude,top,literal)PATH'...`, one exclude per
  `peal_untracked_devices` line (git's `add_to_index` refuses a device and `git add`
  then stages nothing).
- Rejected: test-only override variables, a fake `git`, `unshare` bind mounts,
  `git add --ignore-errors`, per-path adds.

**Verification** (fixture `ln -s /dev/null <dir>/dev-null`, with raw git listing it as
the control)
- `common.test.sh` `status_porcelain_cases`: mknod branch deleted; filtered from the
  root, from `sub/` (link at the root), and `sub/dev-null` with `--untracked-files=all`;
  real untracked and modified files still shown, pathspecs pass through;
  `peal_untracked_devices` prints `dev-null` and `sub/dev-null` and no real file.
- `close.test.sh`: `char_device_cases` on the symlink, no skip; `verify_cases` after
  "verify: green": link present gives `READY 0`, then removed; `BLOCKED:uncommitted`
  (:641) kept.
- `backlog.test.sh`: files (after :51) and issues (after :171) `defer --dry-run` not
  refused for the link, which is removed before the real defer (:87 uses raw status);
  link plus a real file still refused, the list naming only the file.
- `claim.test.sh`: release succeeds with the link in `$wt` after :300 (`dirty` still for
  `scratch.txt` at :296); reap still reaps `0001-reaped-one` with the link.
- `session.test.sh` autosave: link beside `draft.txt` (:128): `draft.txt` committed,
  `git ls-files dev-null` empty, raw status exactly `?? dev-null`; a second autosave with
  only the link leaves HEAD unchanged.
- Each code edit reverted once, the failing case named in the Outcome; `tools/lint.sh`
  clean.

**Ranges**
tasks/done/0075-network-fails-fast.md:18-32, 58-88; plugin/lib/common.sh:45-59;
plugin/lib/close.sh:440-461, 612, 630-657; plugin/lib/store-files.sh:563-573, 614-619,
636; plugin/lib/store-issues.sh:647-680; plugin/lib/claim.sh:320-392;
plugin/lib/session.sh:64-70, 206-229; plugin/lib/close.test.sh:364-384, 626-681, 716-730;
plugin/lib/common.test.sh:1-16, 150-176; plugin/lib/backlog.test.sh:41-57, 81-88,
154-173; plugin/lib/claim.test.sh:281-311, 313-349; plugin/lib/session.test.sh:120-154;
docs/milestones/m1.md:1-25; git's `dir.c` (`treat_path`), `read-cache.c`
(`add_to_index`), `builtin/add.c` (`add_files`).

---

## Outcome

Every place Peal decides whether a worktree holds uncommitted work now ignores an
untracked character device, the shape a sandbox's `/dev/null` mount over a protected path
takes in `git status`. That covers `close verify`, the files and issues defer checks, the
release/reaper dirty verdict in `claim.sh`, and the session-end autosave.

**What was built**
- `peal_status_porcelain` (`common.sh`) resolves git's root-relative porcelain paths
  against `git rev-parse --show-toplevel`. Before this it tested them relative to the
  current directory, so it was silently wrong anywhere but the top. Its comment says that
  an untracked symlink to a device is filtered too.
- New `peal_untracked_devices` (`common.sh`) lists untracked devices by exact path. It
  uses `-z` and `--untracked-files=all`, and is Bash 3.2 safe. Two places use it:
  - The session-end autosave. It excludes each device from `git add -A` through
    `:(exclude,top,literal)` pathspecs, and its guard makes no commit when only a device
    is there. This matters: git's `add_to_index` refuses a device, and `git add` then
    stages nothing at all, so a sandboxed autosave used to save none of the work in
    flight.
  - Both storages' `peal_store_release`, which deletes a worktree's untracked devices
    just before `git worktree remove`.
- The `mknod` fixtures are deleted. Git never lists a real `mknod` device as untracked
  (`dir.c` `treat_path` lists only regular files, symlinks and directories), so those
  cases were vacuous even where they ran. A symlink to `/dev/null` replaces them. Git
  lists it with `??` and `[ -c ]` sees a device, which is exactly how the sandbox mount
  looks. Every case also checks, as a control, that raw git lists the link.

**Departures from the plan, both reviewed and kept**
- Release and reap: `git worktree remove` (deliberately without `--force`) refuses any
  untracked path. The verdict fix in `claim.sh` alone did not make them succeed. So both
  storages delete the devices first, only paths `peal_untracked_devices` reports, and
  only for a worktree that is being removed anyway. `rm` does not follow the link. On a
  real bind mount `rm` fails, and the removal refuses as before.
- `close.test.sh` `char_device_cases` had never run past the `mknod` skip, and its setup
  was wrong: the Outcome edit was left uncommitted, and for the issues storage the
  branch was never pushed. It now commits and pushes first, as `stop_cases` does.
- One case added beyond the plan: issues-storage release with the link, in
  `backlog.test.sh`, because `claim.test.sh` is files-only.

**Tests.** Each code edit was reverted once, and a named case failed each time:
- the root-relative resolution → common "status: filtered from a subdirectory too"
- `peal_untracked_devices` → session "autosave: the link never staged"
- `close.sh` → close "verify: still READY with the link present"
- `store-files.sh` defer → backlog "defer --dry-run: not refused for the link alone"
- `store-files.sh` release → claim "release" / "reap: landed, clean, pushed, idle ones go"
- `store-issues.sh` defer → backlog "issues defer --dry-run: not refused for the link alone"
- `store-issues.sh` release → backlog "issues release a deferred claim, the link in its
  worktree no obstacle"
- `claim.sh` → claim "reap: landed, clean, pushed, idle ones go; the others stay"
- `session.sh` → session "autosave: the link never staged"

Results: common 27/0, close 855/0, backlog 225/0, claim 255/0, session 120/0, and
`tools/lint.sh` clean. `tools/test-all.sh` did not finish within this session's
foreground timeout; CI runs it.

**Left, by the human's choice**
- Seen from outside the sandbox, or once the mount is gone, the mount point is an
  ordinary empty regular file. Nothing can tell it from real work: release still says
  dirty, and an autosave there would commit it. Filed as an idea
  (sandbox-mount-placeholder-outside-sandbox).
- A device inside an untracked directory still counts wherever a check runs without
  `--untracked-files=all` (git shows `?? dir/`). The sandbox mounts seen so far are files
  at known paths.
- Paths that git quotes are not matched by `peal_status_porcelain`.
- macOS is checked by the CI run.

### Reviewer findings not acted on
- The four-line "delete devices before worktree remove" block is repeated in both
  storages' `peal_store_release`. Kept: each storage owns its release, and the shared
  part, `peal_untracked_devices`, is already a common helper.
