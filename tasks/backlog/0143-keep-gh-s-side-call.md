---
milestone: m3
plan: required
priority: low
touches: [plugin/lib/github.sh]
---

# 0143 — Keep gh's side call to cafe.github.com out of sandboxed sessions

## Intent

Under Belfry's sandbox, every `peal_gh` run logs `deny network-outbound cafe.github.com:443 (host is not on the allow list)`. Task 0141 showed this denial did not cause `peal close wait`'s `WAIT:checks-pending`: the checks really were pending. But the denial still shows up as noise in every close session, and it made the 0067 friction look like a sandbox failure. Find out what gh contacts cafe.github.com for, and at which gh version. If it is a side call gh can do without (telemetry, update notifier), `peal_gh` turns it off through gh's environment, with a test. If gh needs it to work, don't work around it: record that the host belongs on the sandbox's allow list. When this is done, Peal's gh calls make no request to cafe.github.com, or the project knows why they must.

## Scope

## Done when

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

---

## Outcome

<!-- Written at close, replacing this comment. -->
