---
milestone: m1
priority: high
plan: skipped
depends: []
---

# 0075 — Peal's network calls fail fast, and close works after a push from outside

## Intent

Peal's own git and gh calls hang when they cannot authenticate: `close begin`'s fetch,
`close finish`'s push and the main-write push wait forever over SSH in a sandbox, with
no output. When this is done, every network call Peal makes fails within seconds with a
message naming what could not be reached, and a session that pushed its branch itself
can still finish its close.

## Scope

- Every internal `git fetch|push|ls-remote` runs with `GIT_TERMINAL_PROMPT=0` and, when
  `GIT_SSH_COMMAND` is unset, `ssh -o BatchMode=yes -o ConnectTimeout=10`; `gh` calls
  get a timeout. A failure says which remote and why, and falls into the existing
  "could not fetch" paths where there are any.
- `close finish` skips its push when `HEAD` equals `@{upstream}`.
- The uncommitted-work checks (Stop hook, `close finish`) ignore untracked character
  devices: the sandbox's `/dev/null` mount points over protected paths.

## Done when

- Harnesses: a remote that cannot authenticate fails within the timeout with the
  message; finish with an up-to-date branch pushes nothing; an untracked character
  device is not counted as uncommitted.

## Raw

From Belfry's friction reports (2026-09-25 to 27): `close begin` hanging on fetch,
`close finish` pushing again after a manual push, placeholder files counted as work.

## Notes


---

## Outcome

Built:

- **Network calls fail fast.** `bin/peal` exports `GIT_TERMINAL_PROMPT=0` and calls the
  new `peal_ssh_batch_mode` (`plugin/lib/common.sh`). It finds the ssh command git
  would use, following git's own precedence: `GIT_SSH_COMMAND`, then
  `core.sshCommand`, then `GIT_SSH`, then plain `ssh`. When that program is ssh, it
  appends `-o BatchMode=yes -o ConnectTimeout=10`. ssh keeps the first value it gets
  for an option, so options the setup already chose win. A proxy or key set through
  any of the three still applies. A non-ssh program (plink, a wrapper) is left alone.
- **Warnings say why.** `peal_git_try` runs a fetch, push or ls-remote and captures the
  reason on failure. Every existing "could not fetch/push" warning now includes it:
  close begin, decisions, ship, and both storages. Fetches that were silent before
  stay silent. The one bare `gh release view` in `ship publish` got a `timeout 60`.
- **`close finish` skips its push** when `HEAD` already equals `@{upstream}`, so a
  branch the session pushed itself finishes even with the remote out of reach.
- **Untracked character devices are ignored** by the Stop hook and by `close finish`,
  through `peal_status_porcelain`.

Found in review and fixed on the branch:

- The first version defaulted `GIT_SSH_COMMAND` only when it was unset. That overrode
  a user's `core.sshCommand` or `GIT_SSH`. It also did nothing in the sandbox this
  task came from, because that sandbox already sets `GIT_SSH_COMMAND` without batch
  mode. The appending approach above replaces it.
- The tests' fake ssh failed at once whatever arguments it got, so they did not prove
  batch mode was applied. It now hangs unless it receives `BatchMode=yes`. The
  unreachable-remote cases also set a pre-existing `GIT_SSH_COMMAND` the way that
  sandbox does. With the `bin/peal` call removed, the close cases fail.

Verification: `tools/lint.sh` passes, `common.test.sh` 20/20, `close.test.sh` 825/825.
Before the review fixes, the ship, store-files, store-issues, decisions and main-write
harnesses were also green. They were not run again after those fixes. The full
`tools/test-all.sh` was not run in the session; CI runs it.

Left open, filed as an idea (char-device-everywhere):

- `close verify` and the defer checks still count untracked character devices. This
  task named only the Stop hook and close finish.
- The character-device harness cases need `mknod`, so they skip in this sandbox and
  on most CI runners. Nothing in CI exercises that filter yet.

For the next session: origin/main was merged in mid-build, after 0066 landed.
