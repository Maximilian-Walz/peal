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
