---
plan: required
touches: [plugin/lib/githooks.sh, plugin/lib/githooks.test.sh, docs/security.md]
size: S
---

# 0249 — pre-push's first push of main trusts local remote-tracking refs

## Intent

When the remote has no main branch yet, `_peal_pre_push` decides which commits to check with `git rev-list ... --not --remotes`. That trusts the local `refs/remotes/*`, which are local files that anyone can fake with `git update-ref`. Task 0178 removed the same weakness for merges. Only the first push of main is affected. The fix would either base the walk on `git ls-remote` of the remote being pushed to, or refuse a first push of main that adds anything besides Peal's own writes.

## Scope

Only the first-push branch of `_peal_pre_push` (the remote has no `refs/heads/<main>`): it refuses every such push in one line instead of walking `--not --remotes`. Pushes to an existing main and deletes are unchanged; tags and other refs are not covered. Tests in `plugin/lib/githooks.test.sh`; the rule documented in `docs/security.md`.

## Done when

- A first push of main with a faked tracking ref (`git update-ref refs/remotes/origin/fake HEAD`) is refused.
- An honest first push of main is refused with the same single line (not one per commit); the message says the first push is the human's own, outside Peal's gate, and does not name `--no-verify`.
- The existing trunk case (`main: trunk`) expects the new message.
- Every other pre-push case still passes; `bash plugin/lib/githooks.test.sh` and `bash plugin/templates/githook.test.sh` pass.
- `docs/security.md` names the first-push rule in "Nothing reaches main but a merged pull request or Peal's own narrow writes" and its Harness list.

## Raw

> pre-push: when the remote has no main yet, _peal_pre_push walks `git rev-list ... --not --remotes`, which trusts local refs/remotes/* (a local file, fabricable with git update-ref), the same weakness task 0178 removed for merges; only the first push of main is affected. Base the walk on `git ls-remote` of the pushed remote, or refuse a first push of main that adds more than Peal's own writes. Found by the reviewer of 0178.

## Notes

- Open question: which of the two fixes to use. A first push of main normally carries the project's whole history, so refusing everything but Peal's own writes may block a legitimate first push.
- `docs/security.md`, the section "Nothing reaches main but a merged pull request or Peal's own narrow writes".
- 2026-10-26, the human's answers at planning: fix C, refuse every first push of main in one line (no network call, so not ls-remote; not a walk of the whole history). A deliberate first push (new remote, mirror, renamed main) is the human's own push outside the gate. The refusal message does not name `--no-verify`. Main only: tags and other refs are not covered. Scope and Done when filled from the plan.

## Plan

Approach (agreed: option C). In `_peal_pre_push`, the branch where the remote sha is all zeros for `refs/heads/<main>` no longer sets `range="$lsha --not --remotes"`: it refuses at once with one line, e.g. "the remote has no <main>; its first push is the human's own, outside Peal's gate" (no `--no-verify` named). It makes no network call and trusts no local ref. Update the function's header comment to name the first-push rule. Pushes to an existing main (`$rsha..$lsha`) and deletes are untouched; tags and other refs are untouched.

Files:
- `plugin/lib/githooks.sh`: the first-push branch (about 208-209) and the header comment (151-193).
- `plugin/lib/githooks.test.sh`: new `pre_push` cases (faked tracking ref refused; honest first push refused with the same single line); the trunk case (494-495) expects the new message.
- `docs/security.md`: the section at 124-133 and the Harness list at 184-191. The no-network statement at 142-143 stays true.

Verification: the Done when list; `bash plugin/lib/githooks.test.sh` and `bash plugin/templates/githook.test.sh` pass.

Ranges relied on:
- plugin/lib/githooks.sh:151-231
- plugin/lib/githooks.test.sh:54-54
- plugin/lib/githooks.test.sh:127-134
- plugin/lib/githooks.test.sh:450-497
- plugin/templates/githook:1-14
- plugin/templates/githook:252-256
- plugin/templates/githook.test.sh:113-125
- docs/security.md:124-149
- docs/security.md:184-191
- docs/design.md:480-493
- docs/milestones/m6.md:25-26

---

## Outcome

`_peal_pre_push` (`plugin/lib/githooks.sh`) now refuses the first push of main (the remote's sha is all zeros) in one line: "the remote has no <main>; its first push is the human's own, outside Peal's gate." Before, it walked `$lsha --not --remotes`, which trusted local remote-tracking refs, and a ref faked with `git update-ref` let the push through unchecked. This was the same weakness 0178 closed for merges.

Decided with the human at planning: option C. It refuses outright, makes no network call and trusts no local ref. The other options were `git ls-remote` of the pushed URL, which goes against the documented "a pre-push hook makes no network call", and walking main's whole history, which prints one refusal per commit. A deliberate first push (a new remote, a mirror, a renamed main) is now the human's own push outside the gate. The message does not name the bypass. Only `refs/heads/<main>` is covered, not tags. Pushes to an existing main and deletes are unchanged.

Tests (`plugin/lib/githooks.test.sh`, `pre_push`):
- An honest first push is refused, with exactly one line and no `--no-verify` in it.
- A first push with a faked `refs/remotes/origin/fake` is refused. Before the fix, that push passed.
- The `main: trunk` case expects the new message, because pushing `HEAD:trunk` to the test remote is itself a first push.

`githooks.test.sh`: 552 passed. `githook.test.sh`: 25 passed. `docs/security.md` states the rule in "Nothing reaches main but a merged pull request or Peal's own narrow writes" and lists the cases under Harness.

The reviewer found one thing, now fixed in its own commit: the first edit of security.md had dropped the verb of "so is any merge made on this machine", so the document no longer said that local merges are refused.

For the next session: the full `githooks.test.sh` takes about two minutes.
