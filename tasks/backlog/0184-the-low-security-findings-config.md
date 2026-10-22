---
plan: auto
size: M
depends: []
touches: [plugin/lib/github.sh, plugin/lib/main-write.sh, plugin/lib/session.sh, plugin/lib/claim.sh, plugin/lib/backlog.sh, plugin/commands/comment.md]
milestone: m4
priority: low
---

# 0184 — The low security findings: config values reaching gh api paths and jq, the autosave's contents, the outsider mark of comment, session-start writes to the remote, awk -v

## Intent

Five low findings of the security review, one task because each is small and they share tests. (a) Work-tree config values reach `gh api` URL paths, jq filters and git ref names unvalidated: `storage.issues.repo` goes into `repos/$PEAL_REPO/...` everywhere (`plugin/lib/github.sh`), `.base.ref == "$PEAL_MAIN"` is interpolated into a jq filter in `plugin/lib/main-write.sh` (another filter in the same file uses `--arg`), and `remote:` and `main:` go into `git fetch` and `git push`. The config comes from the work tree (0091) and only `peal doctor` validates it (0120), so a branch can redirect Peal's API calls. (b) The SessionEnd autosave (`plugin/lib/session.sh`) runs `git add -A -- .` then commits and pushes with no question: an untracked scratch file with pasted secrets goes to the remote, and on a public repository it is public. (c) The outsider mark of `/peal:comment` is decided by the model from a header in the text (`plugin/commands/comment.md` step 3), because the control plane's revise command passes no origin. (d) The SessionStart hook writes without asking: on every new session it fetches, then reaps claims it judges done or deferred, which pushes branch deletions to the remote and installs `core.hooksPath` when the config says `guardrails`; opening a clone of someone else's Peal project can push deletions to their remote. (e) `awk -v` is given values that can be hostile (`plugin/lib/claim.sh`, `plugin/lib/backlog.sh`): `-v` interprets backslash escapes, so a value with `\n` or `\\` compares wrongly; no injection, a misjudgement.

## Scope

- (a) 0120 validates `storage.issues.repo` (`^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`) and `main`, `remote` and `branch-prefix` (`git check-ref-format --branch`); this task makes the main-write jq filter use `--arg`. 0120 is raised or linked as the plan finds best (it is more severe than its place suggests).
- (b) The autosave adds tracked files and new files under the task's `touches`, or honours an exclude list; at least it refuses files named like secrets and says so.
- (c) The control plane's revise command passing `{origin}` is a Belfry change (filed there); Peal's `comment.md` then passes the flag verbatim. Until then say in `docs/security.md` that the mark rests on the model.
- (d) Reaping at session start only touches local refs and reports the remote deletions it would make; remote deletions on an explicit command.
- (e) Untrusted prose goes through `ENVIRON`, as `plugin/lib/task-text.sh` already does.

## Done when

- Each of (a) to (e) has a test, or `docs/security.md` documents the limit that remains with its reason.
- The hostile harness covers `storage.issues.repo`, `main` and `remote` with hostile values.

## Raw

> I'd also like to do a thorough review of peal now. I think there we should also focus on security and performance of course. Instead of UI (peal has none) we should focus on usability of its commands and general design with the boundary to belfry in mind

## Notes

- Security review findings 10 to 14 (LOW). Findings 12 and 13 touch the control plane boundary.
- Security: touches the work-tree config limit, the autosave and the SessionStart hook in `docs/security.md`.

---

## Outcome

<!-- Written at close, replacing this comment. -->
