---
milestone: m3
plan: skipped
size: S
depends: []
---

# 0141 — Reproduce the sandbox friction of `peal close wait` and name the denied host

## Intent

Belfry's Friction page reported `peal close wait` answering `WAIT:checks-pending` seven times in two sessions, the gh calls reaching a host the sandbox denies. By the code a denied gh gives `BLOCKED:gh-failed`, not `WAIT`, so the mechanism is unproven. When this is done it is reproduced under a sandbox that denies GitHub's host, and, if real, `peal close verify` names the denied host in its verdict.

## Scope

- Reproduce first; if the report does not hold, close with the finding.
- `plugin/lib/close.sh` verify, `plugin/lib/github.sh` if the host must be surfaced.

## Done when

- The friction is reproduced or shown not to occur, with evidence in the Outcome.
- If real, `peal close verify` names the denied host, with a test.

## Raw

> From task 0067's note of 2026-10-18 (Belfry's Friction page): under the sandbox `peal close wait` answers `WAIT:checks-pending` every round.

---

## Outcome

**Not reproduced as `WAIT`, but a related defect was real and is now fixed.** A gh call the
sandbox denies cannot produce `WAIT:checks-pending`. Every failed `peal_gh` call returns
non-zero, and the verdict maps that to `BLOCKED:gh-failed`. `WAIT:checks-pending` needs a
check-runs read that *succeeds* and shows a check still running. The existing
`plugin/lib/close.test.sh` case "verify: gh fails" already pinned this. Evidence captured in
this session's sandbox, which allows only GitHub's hosts:

- `GH_HOST=example.com gh api /x` prints `Get "https://example.com/api/v3/x": Forbidden`;
- `curl -sS https://example.com` prints `curl: (7) CONNECT tunnel failed, response 403`;
- the sandbox logs `deny network-outbound example.com:443 (host is not on the allow list)`.

So the seven `WAIT`s on Belfry's Friction page most likely came from GitHub reachable with
checks really pending, or from an older build. If `WAIT` under the sandbox shows up again,
look there first. The real friction was that a denied host gave a bare
`BLOCKED:gh-failed` that did not say why.

**Built.** `peal_gh` (`plugin/lib/github.sh`) copies gh's stderr to `$PEAL_GH_ERRFILE` when
that is set. The new `peal_gh_failed` reads it, and when it finds gh's
`Get "https://HOST/...": Forbidden` form it prints `BLOCKED:gh-failed (host HOST is denied by
the network sandbox; ask the human to allow it)`. Otherwise it prints plain `BLOCKED:gh-failed`.
`peal_close_verify` (`plugin/lib/close.sh`) is now a thin wrapper: it makes the temp file,
runs `_peal_close_verify` with it, removes it and returns the status. `peal_pr_checks` uses
the same helper. Other callers of `peal_gh` (`main-write.sh`) leave `PEAL_GH_ERRFILE` unset
and keep the bare verdict. Callers match the verdict by its `BLOCKED:` prefix, so the suffix
breaks nothing. `plugin/commands/close.md` says so. Only gh's message form is matched; peal
does not call curl. Test: "verify: gh fails on a denied host" in `close.test.sh`, with
`fake-gh` gaining a `$FAKE_GH/fail-message` override. `close.test.sh`: 981 passed, 0 failed.

**Found in review and fixed.** The first build cleaned up with a `RETURN` trap inside
`peal_close_verify`. A bash `RETURN` trap outlives the function and fires again when the
caller returns. By then the variable was unset, so `set -u` killed the shell and every
`READY`/`WAIT` verdict exited 1. This was fixed by the wrapper above. The commit gate did not
catch it because `checks.close` runs only `tools/lint.sh`; the harnesses run in CI. A future
session should run the `plugin/lib/*.test.sh` it touches by hand, reading the whole output,
before closing.
