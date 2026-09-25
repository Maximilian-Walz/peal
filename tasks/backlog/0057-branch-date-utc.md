---
plan: required
priority: high
---

# 0057 — Branch-date detail in UTC: the "every state" and "parked" harness checks fail around midnight

## Intent

Print the branch date in UTC so it matches the rest of Peal, for example
`TZ=UTC git log -1 --format=%cd --date=format-local:%Y-%m-%d ...`. Put it in one shared helper that both stores call, not two copies. This fixes the real inconsistency and not only the tests. Setting `TZ=UTC` in the harnesses would only hide it.

## Done when

- `store-files.sh` and `store-issues.sh` print the `last <date>` detail as the UTC date of the branch's last commit, through one shared helper
- `plugin/lib/tasks.test.sh` and `plugin/lib/store-issues.test.sh` pass with a time zone whose date differs from UTC's at the moment of the run (for example `TZ=Pacific/Kiritimati` or `TZ=Etc/GMT+12`), and with `TZ=UTC`
- A harness check pins this: a branch commit whose local date differs from its UTC date (set through `GIT_COMMITTER_DATE` with an offset) shows the UTC date

## Raw

Filed as issue #57 (https://github.com/Maximilian-Walz/peal/issues/57) from an idea a session had; its text is carried over into the sections above.

## Notes

A parked task's list detail reads `N commit(s) ahead, last <date>`. Both stores build it the same way:

- `plugin/lib/store-files.sh:153`: `git log -1 --format=%cd --date=short "refs/heads/$lb"`
- `plugin/lib/store-issues.sh:125-126`: the same call

`--date=short` prints the commit date in the time zone the commit recorded, which in the harnesses is the machine's local zone. The harnesses compare against `today=$(date -u +%Y-%m-%d)` from `plugin/lib/task-fixtures.sh:10`, which is UTC.

When the local date and the UTC date differ (for example 00:00–02:00 CEST), these checks fail:

- `plugin/lib/tasks.test.sh:79`: "every state" (the `0006 parked ... last $today` line)
- `plugin/lib/store-issues.test.sh:106`: "every state" (the `7 parked ... last $today` line)
- `plugin/lib/store-issues.test.sh:501`: "parked"

Every other date Peal writes is already UTC: `Revised`, `Deferred` and `Retired` notes (`backlog.sh`, `store-files.sh`), decisions (`decisions.sh`), and the session and deferral timestamps (`session.sh`, `backlog.sh`).

---

## Outcome

