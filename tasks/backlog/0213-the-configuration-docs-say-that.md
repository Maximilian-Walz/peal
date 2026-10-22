---
plan: required
priority: low
milestone: m8
---

# 0213 — The configuration docs say that fields reached through a YAML merge key are refused

## Intent

Since 0127, the reader that finds a nested YAML field in a release version file (`release.version-files`, `"PATH: KEY.KEY"`, used by `peal ship bump`) refuses a field it could reach only through a YAML merge key (`<<: *base`) and reports it as "no field". The reference does not say so, so a project whose version field is inherited through an anchor gets a refusal it cannot explain from the docs. Either document the limit where the version-file format is described, or support merge keys if that turns out to be cheap.

## Scope

## Done when

## Raw

> The configuration docs say that fields reached through a YAML merge key are refused
>
> ## Intent
>
> Since 0127, the config reader refuses a field it can reach only through a YAML merge key (`<<: *base`) and reports it as "no field". The configuration reference does not mention this. Document the limit, or support merge keys if that turns out to be cheap.
>
> ## Done when
>
> - `docs/reference/` names the limit (checked by the docs harness), or a config test reads a field through `<<:`.
>
> ## Notes
>
> - From the m3 milestone review (0127's Outcome).

## Notes

- From 0127's Outcome ("Fields inherited only through `<<: *base` are \"no field\". The docs do not say so."), raised at the m3 milestone review.
- "The config reader" here is the nested-YAML field walk of `peal ship bump` over `release.version-files` (0127), not the reader of `.peal/config.yml`. The limit belongs where that format is described: the `release.version-files` row of `docs/reference/configuration.md` and/or the `peal ship bump` section of `docs/reference/cli.md` (which already lists what the nested walk does not enter). Open: which of the two, or both.
- Open: whether merge-key support is cheap in the awk walk (the anchor's mapping would have to be found and walked, and an edit would land in the anchor, changing every alias that merges it). That last point may argue for documenting the refusal rather than supporting it.
- The human set the priority to low.

---

## Outcome

<!-- Written at close, replacing this comment. -->
