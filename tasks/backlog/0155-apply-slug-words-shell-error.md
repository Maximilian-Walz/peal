---
milestone:
plan: skipped
size: S
depends: []
touches: [plugin/lib/apply.sh, plugin/lib/apply.test.sh]
---

# 0155 — peal apply's slug check prints a shell error for a title of no word or several lines

## Intent

A `file` proposal whose title holds a line break, or makes an empty slug (`*`), makes
`peal apply` print a shell error on stderr, e.g. `plugin/lib/apply.sh: line 341: [: : integer expected` or `[: 1`, before
its answer. The slug check in `_pa_static` runs `_peal_slug_normalise` and `cut` line by
line, so `words` holds one count per line (or none for an empty slug: awk prints nothing
for no input) and `[ "$words" -ge 2 ]` fails as a shell error; the proposal is still
answered invalid by the checks after it, but stderr carries the error. After this task such a title is refused with a message of
its own (or its slug made from the whole title), and stderr holds no shell error.

## Scope

- `plugin/lib/apply.sh`: `_pa_static`'s slug check (the `slug=` and `words=` lines of the
  `file` branch).
- `plugin/lib/apply.test.sh`: a case with a title of two lines.

## Done when

- `file` proposals titled `"a b\nc d"` and `"*"` are answered invalid with a message
  naming the title, and stderr holds no `integer expected`.
- `apply.test.sh` passes under every awk.

## Raw

Found in 0152: the before/after comparison of `peal apply` on the hostile inputs showed
`apply.sh: line N: [: : integer expected` on stderr for the raw `glob` and `awkbait` values and the escaped `newline` one (unchanged by 0152, whose refactor had to keep apply's output byte-identical).

## Notes

- The hostile harness's shell-error check does not list `integer expected`, so it did
  not catch this; adding it there is part of the fix or a task of its own.

---

## Outcome

<!-- Written at close, replacing this comment. -->
