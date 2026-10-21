---
plan: required
milestone: m3
size: M
touches: [plugin/lib/claim.sh, plugin/lib/claim.test.sh, plugin/lib/store-files.sh, plugin/lib/store-issues.sh, plugin/lib/store-issues.test.sh, docs/reference/cli.md]
---

# 0121 — Release and the reaper do not warn about a remote branch already gone

## Intent

At a session start, the reaper printed `warning: could not delete origin/task/0058-...`
and the same for 0113, although GitHub had already deleted both branches on merge: the
local `refs/remotes/origin/...` refs were stale, so the remote delete failed on a branch
the remote no longer has. When the delete fails, tell "already gone" (prune the stale
tracking ref, no warning) apart from a real failure (warn as now).

## Scope

When a release (`peal release` or the session-start reap, both `peal_store_release`)
fails to delete the remote branch, tell three cases apart:

- already gone on the remote: prune the stale tracking ref, print nothing;
- the git config is locked (the local branch delete's `branch.<name>` removal): one
  clear `warning:` line naming the manual fix, no raw git lines;
- a real failure: warn as now, with git's reason.

The release avoids config writes when the branch has no `branch.<name>` keys. Both
storages (files, issues). Out of scope: `peal_store_takeover`'s same stale-ref delete
(filed as an idea at close).

## Done when

- `claim.test.sh` `release()`: a remote branch deleted behind the clone's back releases
  with only `released ...`, exit 0, empty stderr, and the stale tracking ref is gone.
- Locked config (`config.lock`) with an upstream set: the release succeeds, branch gone,
  tip kept, exactly one line about the locked config, no `error: could not lock` from git.
- Locked config with no upstream: only `released ...`.
- Remote URL pointing at a missing path: local release succeeds and prints
  `warning: could not delete origin/<b> (` plus git's reason.
- The existing remote-delete case still passes.
- `claim.test.sh` `reap()`: a landed claim with its remote branch already gone is reaped,
  and the whole session-start output has no `could not delete` line and no git line.
- `store-issues.test.sh`: the gone-branch case on the issues storage, same expectations.
- shellcheck and the full suite green; `docs/reference/cli.md` says a gone remote branch
  is pruned silently.

## Raw

> peal: warning: could not delete origin/task/0058-setup-points-at-next (session-start
> output seen in the m2 review, 0046; a pruning fetch then showed both branches already
> deleted on origin)

## Notes

2026-10-19: Also seen (friction from a sandboxed session, 2026-10-18): in a sandbox, git config writes fail with "could not lock config file .../.git/config: File exists". At session start, the reap's stale-ref delete then fails and warns, and git's hint names a wrong ref (`origin/refs/heads/...`). Close's half of this, the upstream that could not be recorded, is done in 0101. When the delete fails, tell three cases apart: already gone (prune, no warning), a locked config (one clear line saying so), and a real failure (warn as now). Where possible, avoid config writes in the reap altogether.

- The code: `plugin/lib/store-files.sh` around the `could not delete` warning in the
  release path, and its twin in `plugin/lib/store-issues.sh`.
- Open: `git ls-remote` after a failed delete costs a network call; matching the error
  text ("remote ref does not exist") is cheaper but depends on git's wording.

2026-10-21, planning with the human: confirm "already gone" with `git ls-remote
--exit-code` (status 2), not by matching git's wording; delete the local branch with
`git update-ref -d` and remove `branch.<name>` only when it has keys, instead of
`git branch -D`; a locked config gets one `warning:` line naming `git config
--remove-section branch.<name>`; a real failure's warning adds git's reason;
`peal_store_takeover`'s same bug is left out and filed as an idea at close. Finding: a
locked config cannot fail the remote delete; the lock errors come from `git branch -D`
(exit 0, stderr captured into the reap's output, `claim.sh:532`).

## Plan

1. Shared helpers in `plugin/lib/claim.sh`, beside `peal_release_worktree`:
   - `peal_release_branch BRANCH TIP`: `git update-ref -d refs/heads/$BRANCH $TIP` (after
     the worktree is removed or detached, as now); then, only if a `branch.<BRANCH>.*` key
     exists (`git config --name-only --get-regexp '^branch\.'` with an exact prefix match
     in awk, no regex built from the name), `LC_ALL=C git config --remove-section
     branch.$BRANCH` with stderr captured. On `could not lock config file`: one `peal_err`
     line, `warning: the git config is locked; branch.<B>'s settings stay in it (remove
     them with git config --remove-section branch.<B>)`; any other failure the same line
     with git's reason. Neither fails the release.
   - `peal_release_remote BRANCH TIP`: today's twin block (ancestor check and its warning
     unchanged); the delete runs under `LC_ALL=C peal_git_try`; on failure
     `git ls-remote --exit-code "$PEAL_REMOTE" refs/heads/$BRANCH`: status 2 →
     `git update-ref -d refs/remotes/$PEAL_REMOTE/$BRANCH`, silent; else
     `warning: could not delete $PEAL_REMOTE/$BRANCH ($PEAL_GIT_ERR)`.
2. Both `peal_store_release` call the helpers; the duplicated block goes.
3. Tests first, against the tests' local bare remote: branch deleted on the remote, a
   `config.lock` (as `close.test.sh:393`), a remote URL at a missing path.
4. One sentence in `docs/reference/cli.md` under `peal release`.

Files: `plugin/lib/claim.sh`, `plugin/lib/store-files.sh`, `plugin/lib/store-issues.sh`,
`plugin/lib/claim.test.sh`, `plugin/lib/store-issues.test.sh`, `docs/reference/cli.md`.

Verification: the Done-when cases, shellcheck, the full suite.

Ranges:
- plugin/lib/store-files.sh:1056-1123
- plugin/lib/store-issues.sh:919-951
- plugin/lib/claim.sh:1-15
- plugin/lib/claim.sh:361-395
- plugin/lib/claim.sh:429-437
- plugin/lib/claim.sh:515-542
- plugin/lib/common.sh:132-147
- plugin/lib/session.sh:184-202
- plugin/lib/close.sh:598-605
- plugin/lib/close.test.sh:380-415
- plugin/lib/claim.test.sh:18
- plugin/lib/claim.test.sh:339-430
- plugin/lib/store-issues.test.sh:708-717
- plugin/lib/store-files.sh:988-1012
- docs/reference/cli.md:414-423

---

## Outcome

Built as planned. Two shared helpers in `plugin/lib/claim.sh` replace the duplicated
release block of both storages (`peal_store_release` in `store-files.sh` and
`store-issues.sh`):

- `peal_release_branch` deletes the local branch with `git update-ref -d` (guarded by
  the tip), and removes `branch.<name>` from the git config only when it has keys
  (exact prefix match in awk). A config that cannot be changed is one `warning:` line
  naming `git config --remove-section branch.<name>` ("the git config is locked" for a
  lock, git's reason otherwise); the release never fails on it.
- `peal_release_remote` keeps the ancestor check; when the remote delete fails it asks
  `git ls-remote --exit-code`: status 2 (no such ref) prunes the stale tracking ref
  silently, anything else warns `could not delete <remote>/<branch> (<git's reason>)`.

What was found: a locked config can never fail the remote delete. The lock errors seen
in sandboxed sessions came from `git branch -D`, which takes the config lock for every
branch, prints `error: could not lock config file` and still exits 0; the reap folded
that stderr into its output. Avoiding the config write for a branch without settings
removes them in the common case. The `origin/refs/heads/...` hint from the Notes could
not be traced; with git's stderr captured at both places no raw git hint reaches the
output any more.

Decided with the human: `ls-remote` over matching git's wording (the extra network call
is paid only after a failed delete); `update-ref` over `git branch -D`; one warning line
for a locked config; git's reason added to the real-failure warning.

Tests: `claim.test.sh` gained `release_remote` (gone branch, locked config with and
without an upstream, unreachable remote) and `reap_gone` (session-start output clean);
`store-issues.test.sh` a gone-branch case. After merging origin/main the reviewer ran
claim.test.sh 330/0, store-issues.test.sh 657/0, store-files.test.sh 636/0; shellcheck
clean. The review found the gone-branch case discarded stderr while naming a "no stderr"
check; fixed on the branch to assert stderr empty.

Left: `peal_store_takeover` has the same stale-ref delete (a deferred remote-only branch
already gone refuses the claim); filed as an idea, out of scope by the human's choice.

Edge for a future reader: `peal_git_try` returns 2 when `mktemp` fails, which
`peal_release_remote` would read as "gone" and prune the tracking ref; harmless (the
next fetch restores it) and not worth a branch.
