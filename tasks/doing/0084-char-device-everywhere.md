---
milestone: m1
plan: required
touches: [plugin/lib/close.sh, plugin/lib/store-files.sh, plugin/lib/store-issues.sh]
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

## Done when

## Raw

> close verify and the defer uncommitted-work checks (store-files.sh, store-issues.sh) still count an untracked character device (a sandbox's /dev/null mount over a protected path) as uncommitted work; 0075 fixed only the Stop hook and close finish. Use peal_status_porcelain there too. Also: the char-device harness cases skip wherever mknod is not permitted (this sandbox, most CI), so nothing actually exercises the filter; find a fixture that does.

## Notes

- Split off from 0075, which is in m1.
- Open question: which fixture works without `mknod`? A symlink to `/dev/null` passes
  `[ -c ]` but git lists it as a symlink. That would test the filter's side effect, not
  the case it is meant for. A test hook that overrides the device check is another
  option.

---

## Outcome

<!-- Written at close, replacing this comment. -->
