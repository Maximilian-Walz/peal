---
plan: required
---

# 0122 — `peal comment --origin outsider` on the issues storage

## Intent

`peal comment --origin outsider ID TEXT` sets `origin: outsider` on the task, but only
the files storage carries that field. On the issues storage the mark is probably dropped
silently, just as `peal create --origin outsider` dropped it before 0094, which now
refuses it there. Check whether that happens, and if it does, either refuse the flag on
the issues storage the way 0094 does for `create`, or carry the mark.

## Scope

## Done when

## Raw

> peal comment --origin outsider likely drops the mark silently on the issues storage, like peal create --origin did before 0094 (docs/reference/cli.md says "(files storage)" for it). Refuse it there too, or carry it; check hostile.test.sh/store-issues.test.sh coverage. Found by 0094's implementer, not checked.

## Notes

2026-10-22: Security review findings 7 and 8: the same family as an outsider's labelled issue whose body holds a Plan reading as agreed; see the revise-shape task of Safe under Belfry, which may absorb this.

- Nobody has checked yet: confirm the drop first (`plugin/lib/store-issues.test.sh`).
- 0094 chose to refuse on `create` because `docs/reference/tasks.md` and `docs/design.md`
  record `origin` as files only. Being consistent with that suggests refusing here too.
  Open question: should the comment still be posted when the refusal happens?
- `docs/reference/cli.md`, `peal comment` section.

---

## Outcome

<!-- Written at close, replacing this comment. -->
