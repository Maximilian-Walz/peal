---
milestone: m7
plan: required
size: M
depends: []
touches: [plugin/lib/frontmatter.sh, plugin/lib/yaml-lib.awk, plugin/lib/yaml-parse.awk, plugin/lib/config.sh, plugin/lib/milestones.sh, plugin/lib/tasks.sh, plugin/lib/apply.sh]
---

# 0156 — The helpers peal apply shares run in fewer processes and in linear time

## Intent

After 0152 most of the processes and time of a `peal apply` are in helpers it shares
with other commands, which 0152 left alone: the configuration parsed again for each
key, the milestone files parsed twice, the frontmatter of the same task parsed once per
field read, and the YAML parser taking time quadratic in a line's length under busybox
awk. After this task an ordinary apply runs in markedly fewer processes and a batch
holding a 64 KiB value takes under 3 s under busybox, with every command sharing these
helpers faster too.

## Scope

- The configuration read once per process (`peal_config_load`, `peal_config_get`).
- `peal_fm_get` and its callers (`_peal_cycle_row` reads three fields with three parses;
  `peal_task_check`) reading a file's frontmatter once.
- `yaml-lib.awk` / `yaml-parse.awk`: a long line parsed in time linear in its length
  under busybox awk (as 0152 did for `apply.awk`'s `str()`: windows and `index()`
  instead of one `substr` per character).
- `peal apply`'s second `peal_ms_load` in `_pa_check` skipped when no milestone file
  changed.

## Done when

- An ordinary escaped `file`+`add` apply (the hostile harness's `apply, escaped values
  [dollar]`) runs in at most half the processes it took after 0152 (205 processes,
  136 execs, measured with `strace -f`), output byte-identical.
- `apply, escaped values [long]` takes under 3 s under busybox awk (about 4.8 s after
  0152, 31 s before it).
- Every harness passes under every awk.

## Raw

Found in 0152, whose plan kept the shared helpers out of scope and asked for an idea
with the profile.

## Notes

Profile after 0152 (local, mawk, `bash -x` with the innermost function per external
command; calls whose stderr goes to a file are not counted, so the shared figures are
low): of an ordinary escaped `file`+`add` apply's external commands, 21 are
`apply.sh`'s own (82 before 0152) and at least 56 the shared helpers' and startup's:
`peal_ms_load` 16 (the milestone files parsed in `_pa_compose` and again in
`_pa_check`), `peal_config_get` 7 and `peal_config_load` 6 (the configuration parsed
six times), `_peal_files_ids` 6, `_peal_files_next_id` 3, the cycle helpers 6.
Under busybox awk, `apply, escaped values [long]` spends about 5 s of its 4.8–5.4 s in
six frontmatter parses of the filed task, whose frontmatter holds the 64 KiB value
(`peal_fm_get merge`, `peal_fm_set milestone`, `peal_task_check`, `_peal_cycle_row`'s
three `peal_fm_get`), each 0.6–1.4 s.

---

## Outcome

<!-- Written at close, replacing this comment. -->
