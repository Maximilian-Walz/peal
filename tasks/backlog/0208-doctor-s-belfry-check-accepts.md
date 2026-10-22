---
plan: required
origin: outsider
milestone: m8
---

# 0208 — Doctor's belfry check accepts a .belfry.yml with block scalars

## Intent

`peal doctor`'s belfry check reads `.belfry.yml` with Peal's YAML subset reader, which refuses block scalars (`|` and `>`). A valid control-plane contract writes its start prompt as `start: |` under `tasks.github-issues`, so doctor reports ".belfry.yml:5: block scalars (| and >) are not supported" and then "FAIL belfry: .belfry.yml's tasks: section does not parse" on a correct setup. Adopters then learn to ignore doctor. The check should get past block scalars in fields it does not read (skipping them, or reading them); if neither works, it should warn rather than fail.

## Scope

## Done when

## Raw

> peal doctor's belfry check does not fail on a .belfry.yml with block scalars
>
> ## Intent
>
> `peal doctor` fails on a valid `.belfry.yml` whose start prompt is a block scalar (`start: |`): ".belfry.yml:5: block scalars (| and >) are not supported", then "FAIL belfry: .belfry.yml's tasks: section does not parse". The control plane's own contract uses `start: |` under `tasks.github-issues`, so doctor fails on a valid setup, and adopters learn to ignore it.
>
> ## Scope
>
> - Doctor's belfry check (or Peal's YAML reader) skips over block scalars in fields it does not read, or reads them. If neither is possible, the check warns instead of failing.
>
> ## Done when
>
> - A doctor.test.sh case passes on a `.belfry.yml` with a `|` and a `>` block scalar.
>
> ## Notes
>
> - Reported as friction by a session of another project that ran doctor on its issues-storage setup.

## Notes

- Open question: where the fix goes. The refusal comes from the shared reader (`plugin/lib/yaml-lib.awk`, "block scalars (| and >) are not supported"), which task frontmatter and milestone files also use, and their tests (`frontmatter.test.sh`, `milestones.test.sh`) expect the refusal. Teaching the shared reader block scalars changes what task headers accept; a doctor-only path (skipping block-scalar values in `.belfry.yml`) keeps the subset strict elsewhere. The planner decides.
- Reported as friction by a session of another project, from running doctor on its issues-storage setup.
- `docs/reference/configuration.md` and `docs/design.md` may describe the YAML subset; keep them in step.

From a session of belfry (job a2994d4ed443ae0c).
