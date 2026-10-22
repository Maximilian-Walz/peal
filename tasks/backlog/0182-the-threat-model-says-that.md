---
plan: auto
size: S
depends: []
touches: [docs/security.md, README.md]
milestone: m4
---

# 0182 — The threat model says that gh with the user's token can merge or write contents directly

## Intent

`docs/security.md` says "`gh` holds the token; Peal only calls it" and "the merge is the human's". But a session can run `gh pr merge N --squash`, `gh api -X PUT repos/o/r/pulls/N/merge`, `gh api -X PUT repos/o/r/contents/path` (a commit on main through the API, skipping every git gate) or `gh api -X DELETE repos/o/r/git/refs/heads/x` with the user's token, and no guard looks: the git guard matches `git` only. Peal itself enables auto-merge and merges its own narrow writes through `peal_gh` (`plugin/lib/main-write.sh`). The control plane's own threat model lists the same gap (the worker's gh login being readable from the sandbox). When this is done the threat model says it plainly and says what closes it.

## Scope

- `docs/security.md`: a limit entry, with the calls above, saying "nothing merges by itself" depends on branch protection with required reviews for the token the session can use; under Belfry the login is removed from the sandbox (Belfry's #671) and sessions open pull requests through the control plane; standalone, branch protection and a token limited to what the session needs.
- The README's wording follows.
- Optional, if the plan finds it worth it: the git guard refuses the obvious `gh pr merge` and `gh api` writes to `pulls/*/merge`, `contents/`, `git/refs` and branch protection, as a signpost like the rest.

## Done when

- `docs/security.md` has the entry and the README does not promise more than it holds.
- If the guard is extended, `git-guard.test.sh` has a case for each call.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Security review finding 4 (HIGH, read). Under Belfry this is closed by hiding the login (#671) once close and the reads work without it (the urgent task of Safe under Belfry).
- Security: touches the gh boundary and "the merge is the human's" in `docs/security.md`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
