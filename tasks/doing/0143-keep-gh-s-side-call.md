---
milestone: m3
plan: required
priority: low
touches: [plugin/bin/peal, plugin/lib/fake-gh, plugin/lib/close.test.sh, plugin/lib/github.sh, docs/security.md]
size: S
---

# 0143 — Keep gh's side call to cafe.github.com out of sandboxed sessions

## Intent

Under Belfry's sandbox, every `peal_gh` run logs `deny network-outbound cafe.github.com:443 (host is not on the allow list)`. Task 0141 showed this denial did not cause `peal close wait`'s `WAIT:checks-pending`: the checks really were pending. But the denial still shows up as noise in every close session, and it made the 0067 friction look like a sandbox failure. Find out what gh contacts cafe.github.com for, and at which gh version. If it is a side call gh can do without (telemetry, update notifier), `peal_gh` turns it off through gh's environment, with a test. If gh needs it to work, don't work around it: record that the host belongs on the sandbox's allow list. When this is done, Peal's gh calls make no request to cafe.github.com, or the project knows why they must.

## Scope

- `plugin/bin/peal` exports `GH_TELEMETRY="${GH_TELEMETRY:-0}"`, so every gh Peal starts (peal_gh, the board's `gh pr list`, ship, doctor) runs with gh's telemetry off; a value the user set is kept.
- `GH_NO_UPDATE_NOTIFIER` is not set: nothing ties it to cafe.github.com.
- The gh commands an agent runs itself from the command markdown are out of scope (a follow-up idea).

## Done when

- The Outcome names what the request is for (gh's telemetry), with evidence and the gh version checked.
- The harness proves Peal's gh runs with `GH_TELEMETRY=0` when unset or empty, and with the user's value when set.
- The Outcome says how far the sandbox claim is proven: the session cannot see the sandbox's deny line, so the proof rests on gh's documentation, the binary's strings and the harness.

## Raw

> Keep gh's side call to cafe.github.com out of sandboxed sessions
>
> ## Intent
>
> Under Belfry's sandbox every `peal_gh` run logs `deny network-outbound cafe.github.com:443 (host is not on the allow list)`. Task 0141 showed that this denial is not what made `peal close wait` answer `WAIT:checks-pending`: the checks really were pending, and green once they finished. Still, the denial is noise in every close session, and it made the 0067 friction look like a sandbox failure. When this is done, Peal's gh calls make no request to cafe.github.com, or the project knows why they must.
>
> ## Scope
>
> - Find out what gh contacts cafe.github.com for (telemetry, update notifier, or something else) and at which gh version.
> - If it is telemetry or the update check: `peal_gh` (`plugin/lib/github.sh`) turns it off through gh's environment (for example `GH_TELEMETRY=0`, `GH_NO_UPDATE_NOTIFIER=1`, whichever gh actually honours), with a test.
> - If gh needs it to work: do not work around it. Write down that the host belongs on the sandbox's allow list.
>
> ## Done when
>
> - The Outcome names what the request is for, with evidence.
> - A sandboxed `peal close verify` logs no denial for cafe.github.com, or the Outcome explains why it must.
>
> ## Raw
>
> > After task 0141 (PR #239): during `peal close wait` the sandbox logged `deny network-outbound cafe.github.com:443`, and the verdict was `WAIT:checks-pending`; CI was really running and went green. Probably a denied side call gh makes on its own plus checks really pending. If telemetry, peal_gh could turn it off with GH_TELEMETRY=0 / GH_NO_UPDATE_NOTIFIER; otherwise add the host to the sandbox's allow list.
> >
> > Friction (job 4f6c864a0b1c0ecd): `peal close wait` ran nine minutes twice, answered WAIT:checks-pending, and the sandbox denied cafe.github.com on each run; wait_ci answered at once. (Its proposed fix, wait_ci in close step 6, shipped as 0067.)
>
> ### Merged: `peal close wait` polls GitHub itself under Belfry. It ran nine minutes twice, returned WAIT:checks-pending each time…
>
> Friction a session of peal reported: the tooling around its work got in its way.
>
> ### Job 4f6c864a0b1c0ecd (peal)
>
> - **Tried:** Wait for the closed task's PR to go green with `peal close wait`, as /peal:close step 6 says.
> - **What happened:** `peal close wait` polls GitHub itself under Belfry. It ran nine minutes twice, returned WAIT:checks-pending each time and spent GitHub budget. The sandbox also denied cafe.github.com on each run. Belfry's wait_ci then answered at once.
> - **Workaround:** Called wait_ci for the PR, then `peal close verify` (READY).
> - **Proposed fix:** In /peal:close step 6, when BELFRY_SESSION is set, wait with Belfry's wait_ci tool and then run `peal close verify` once, instead of `peal close wait`. This matches what /peal:idea already does for task_create.

## Notes

- Milestone m3 and priority low are the human's decision at filing.
- Open question: the sandbox itself is Belfry's, and this repository must not know Belfry (`docs/design.md`). Should a fix in `peal_gh` hold for gh under any network filter, rather than branch on `BELFRY_SESSION`? And if the host must stay reachable, where does Peal record that: a sentence in `docs/security.md`, or only the Outcome?
- Open question: whether the request comes from gh itself or from an extension or the gh version installed on the worker; the Outcome should name the version it checked.
- Context: `docs/security.md` (what Peal's gh calls reach), `docs/design.md` (Peal never needs Belfry).
- 2026-10-20 evidence (worker's gh 2.102.0, no extensions): the gh binary holds `https://cafe.github.com` beside `GH_TELEMETRY_ENDPOINT_URL`; `gh help environment` documents `GH_TELEMETRY=0|false` as telemetry off (precedence over `DO_NOT_TRACK`); `GH_TELEMETRY=log gh api rate_limit` prints one `command_invocation` payload and the call works. A sandboxed `gh api rate_limit` shows the session no deny line either way.
- Human's answers (planning): the fix lives in `plugin/bin/peal`, for all of Peal's gh calls; keep a user's `GH_TELEMETRY`, default `0` when unset or empty; the agent's own gh calls in the command markdown are a follow-up idea; the plan agreed as below, merge by a human.

## Plan

Approach: one line in `plugin/bin/peal` next to `export GIT_TERMINAL_PROMPT=0` (lines 13-19), with a short comment why: `export GH_TELEMETRY="${GH_TELEMETRY:-0}"`. Every gh Peal starts is a child of `bin/peal` (peal_gh in github.sh, the board's `gh pr list` in store-files.sh, ship.sh's gh calls, doctor's `gh auth status`), hooks included. `0`, not `log` (log would land in peal_gh's captured stderr and `PEAL_GH_ERRFILE`). No `GH_NO_UPDATE_NOTIFIER`, no `BELFRY_SESSION` branch. First, confirm `GH_TELEMETRY=0 gh api rate_limit` still works.

Files:
- `plugin/bin/peal`: the export and comment.
- `plugin/lib/fake-gh`: append `${GH_TELEMETRY-unset}` to `$FAKE_GH/env` on every call (one write covering all branches), documented in its header comment.
- `plugin/lib/close.test.sh` verify cases: with `GH_TELEMETRY` unset the recorded value is `0`; with `GH_TELEMETRY=false` it is `false`; with it empty it is `0`.
- `plugin/lib/github.sh`: header comment notes gh runs with telemetry off (set in bin/peal), if it helps.
- `docs/security.md` §"`gh` holds the token": one sentence: Peal's gh runs with gh's telemetry off (`GH_TELEMETRY=0` unless the user set it), so its calls reach only GitHub's API; Guard pointer to `plugin/bin/peal`.

Verification: `bash plugin/lib/close.test.sh` (both storages), full harness suite and shellcheck green; `PEAL_ROOT=$PWD/plugin plugin/bin/peal close verify` from the branch after the PR; the Outcome quotes the evidence in Notes and names the follow-up idea for the agent's own gh calls.

Ranges: tasks/doing/0143-keep-gh-s-side-call.md:1-65, plugin/lib/github.sh:1-5, plugin/lib/github.sh:46-89, plugin/bin/peal:1-35, plugin/lib/fake-gh:1-50, plugin/lib/fake-gh:61-80, plugin/lib/fake-gh:107-127, plugin/lib/store-files.sh:223-241, plugin/lib/ship.sh:858-900, plugin/lib/doctor.sh:195-224, plugin/lib/close.test.sh:643-700, plugin/lib/issue-fixtures.sh:27-41, docs/security.md:303-312, docs/reference/cli.md:1-11, plugin/commands/close.md:63-64, docs/design.md:113-120

---

## Outcome

<!-- Written at close, replacing this comment. -->
