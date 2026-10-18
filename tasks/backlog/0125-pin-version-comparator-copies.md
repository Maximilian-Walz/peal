---
plan: required
---

# 0125 — Pin session.sh's version comparator to the launcher's

## Intent

`plugin/lib/session.sh` holds `_peal_vcmp`, a copy of the awk version comparator in the shared finding block of `plugin/templates/launcher` and `plugin/templates/githook`. The copy is unavoidable (the templates can source nothing), but unlike the launcher/stub block, which a test keeps byte-identical, nothing checks that the two comparators stay equal. If they drift, SessionStart's no-downgrade decision (`peal_write_root`) and the launcher's choice of root disagree. A test should pin them together: either both comparators run over one version table, or the awk program is extracted from each and compared.

## Scope

## Done when

## Raw

> Pin session.sh's version comparator to the launcher's: plugin/lib/session.sh _peal_vcmp (line 33) is a copy of the awk comparator in the shared finding block of plugin/templates/launcher (around line 164) and githook. The templates can source nothing, so the copy is necessary, but unlike the launcher/stub block (byte-identical per launcher.test.sh:24) nothing tests that the two stay equal. If they drift, SessionStart's no-downgrade decision (peal_write_root) and the launcher's choice of root disagree. Add a test that runs both comparators over the same version table, or extracts and cmp's the awk program. Found in review of 0115.

## Notes

- Found by the reviewer of 0115, which introduced both copies.
- Open question: a behavioural table (robust to formatting) or a byte comparison of the awk program (catches any drift, brittle to reindenting)?
- Context: `docs/security.md` (the launcher's root resolution, 0040).

---

## Outcome

<!-- Written at close, replacing this comment. -->
