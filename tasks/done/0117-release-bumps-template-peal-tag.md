---
milestone: m3
plan: required
touches: [plugin/lib/ship.sh, plugin/lib/version-field.awk, plugin/lib/githooks.sh, plugin/lib/*.test.sh, plugin/templates/decisions.yml, .peal/config.yml, plugin/lib/config-defaults.yml, docs/reference/configuration.md, docs/reference/cli.md, docs/design.md]
size: M
---

# 0117 — Release bumps the template's Peal tag

## Intent

Let `release.version-files` reach more than a top-level field of a JSON, TOML or YAML
file: a nested YAML field or a marked line. Then `peal ship bump` can set the Peal tag in
the Get Peal step of `plugin/templates/decisions.yml` at release time. Today that pin is
updated by hand after each release, and `tools/pins.test.sh` fails the first pull request
that runs the harnesses until someone does it. A release commit still cannot set a SHA
for itself, so this only shortens the lag for the tag, not for the SHA.

## Scope

- The marked-line form of `release.version-files`: `"PATH: \"TEXT\""` (parse, edit, the
  chore(release) gate, docs).
- Peal's own `.peal/config.yml` lists `plugin/templates/decisions.yml` with the Get Peal
  fetch line as its marker; the template's how-to comment is reworded.
- Out of scope: nested YAML fields (filed as an idea), setting the SHA (filed as an idea),
  `tools/ci-changes.sh`.

## Done when

- `peal ship bump` sets the version on a marked line, changing only that token; the
  pre-push gate accepts exactly that edit and refuses a commit that changes more.
- Refusals are tested and leave main unchanged: no line holds the marker, two lines do,
  the line holds no version or two, an empty or backslashed marker; hostile markers write
  nothing.
- `tools/pins.test.sh` stays green after a simulated release of the template.
- The docs describe the form.

## Raw

> Extend release.version-files to reach a nested YAML field or a marked line, so peal ship bump can set the Peal tag in plugin/templates/decisions.yml's Get Peal step at release time. Today tools/pins.test.sh (task 0069) fails the first harness-running PR after each release until the template's Peal SHA and tag are updated by hand; a SHA still cannot be set by the release commit itself, so this narrows the lag only for the tag. Touches plugin/lib/ship.sh, docs/reference/configuration.md, the chore(release) gate.

## Notes

- Filed from task 0069, which pinned the template's Peal fetch to v0.2.0's commit.
- Open question: the pin is a SHA with the tag in a comment. If the release sets only the
  tag, the SHA and the tag disagree until the SHA is updated by hand. Is a tag-only bump
  worth that, or should the pin take another form (for example the tag plus a check of
  the SHA)?
- The chore(release) gate lets the bump commit touch only version files and the
  changelog (`docs/design.md`); `docs/reference/configuration.md` documents
  `release.version-files`.
- 2026-10-18, the human, at planning: tag-only bump (A), with a follow-up task for a
  narrow write after `peal ship tag` that sets the SHA (D); nested YAML out, filed as its
  own idea; syntax `PATH: "TEXT"` (literal, no control characters, tab or backslash; the
  one `X.Y.Z` on the line is replaced, a `v` prefix not checked; any plain file type);
  the planner's Scope and Done when taken; `tools/ci-changes.sh` left as it is; the
  template comment reworded; "dotted field refused" kept in the docs.

## Plan

Approach:
- `peal_version_files` (`plugin/lib/ship.sh:65-86`) accepts `"PATH: \"TEXT\""` next to
  `"PATH: FIELD"`: a bare word is a field, a double-quoted literal a marker. TEXT is a
  literal string (pass it through `ENVIRON`, not `awk -v`), non-empty, with no control
  character, tab or backslash. The extension check is lifted for marked lines only.
- `peal_version_edit` (`ship.sh:181-195`) sends a marker to a new line mode in
  `plugin/lib/version-field.awk`: exactly one line contains TEXT; that line holds exactly
  one version token `MAJOR.MINOR.PATCH(-pre)?` with no digit or dot right before or after;
  the token is replaced, nothing else changes. Otherwise status 2 and a message, as a
  missing field today.
- The gate (`plugin/lib/githooks.sh:312-373`) already re-derives the edit through
  `peal_version_edit`; adjust its comment and the "changes more than its $field" message.
- `.peal/config.yml:15` adds
  `"plugin/templates/decisions.yml: \"fetch -q --depth 1 https://github.com/Maximilian-Walz/peal\""`;
  `plugin/templates/decisions.yml:41-44` comment says the release sets the tag and the SHA
  is set by hand once the tag exists.
- Docs: `docs/reference/configuration.md:46-56`, `docs/reference/cli.md:582-602` (the
  dotted-field refusal stays), `docs/design.md:435-450`, `plugin/lib/config-defaults.yml:44`
  and `.peal/config.yml:52-59`; `plugin/bin/peal:285-295`, `plugin/lib/next.sh:176-184`,
  `docs/security.md:97-114,251-264` where they describe the form.
- File two ideas: the SHA write after `peal ship tag` (option D); nested YAML fields.

Verification:
- `plugin/lib/ship.test.sh`: bump with a marked-line item changes only the token
  (`diff -U0`); a rerun says already at; `peal ship tag` refuses while the line is stale;
  the refusals of Done when leave main unchanged.
- `plugin/lib/githooks.test.sh`: the bump passes `pre_push_release`; a hand commit that
  also changes the SHA on the line is refused.
- `plugin/lib/hostile.test.sh:659-677`: a third `what`, the marker.
- `tools/pins.test.sh`, `tools/pins.sh`: clean after a simulated bump of the real template.
- `PEAL_ROOT=$PWD/plugin plugin/bin/peal config release.version-files` parses;
  `peal_version_edit` on the real template with 0.3.0 changes exactly line 47's tag.
- `tools/lint.sh`, `tools/docs.test.sh`.

Ranges: tasks/doing/0117-release-bumps-template-peal-tag.md:1-42,
plugin/templates/decisions.yml:37-48, tools/pins.test.sh:1-101, tools/pins.sh:1-60,
tools/ci-changes.sh:1-39, plugin/lib/ship.sh:65-98, plugin/lib/ship.sh:181-225,
plugin/lib/ship.sh:566-647, plugin/lib/ship.sh:664-688, plugin/lib/version-field.awk:1-161,
plugin/lib/githooks.sh:312-373, plugin/lib/ship.test.sh:203-304,
plugin/lib/githooks.test.sh:275-319, plugin/lib/hostile.test.sh:659-677,
plugin/lib/next.sh:176-184, plugin/commands/release.md:50-62,
docs/reference/configuration.md:46-56, docs/reference/cli.md:582-602,
docs/design.md:435-450, docs/security.md:97-114, docs/security.md:251-264,
.peal/config.yml:14-16, .peal/config.yml:52-59, .github/workflows/ci.yml:19-34

---

## Outcome

`release.version-files` now also takes a marked line, `"PATH: \"TEXT\""`. A bare word
is a top-level field, as before. A double-quoted literal is a marker: exactly one line
of the file must contain it, and that line must hold exactly one version token
(`MAJOR.MINOR.PATCH(-pre)?`, with no digit or dot right before or after it).
`peal ship bump` replaces only that token. Anything else is refused with status 2:
- no line holds the marker, or two lines do
- the line holds no version, two versions, or one cut by a dot (`1.2.3.4`)
- the marker is empty, or contains a control character, tab, backslash or `"`

The marker reaches `version-field.awk` through `ENVIRON` and is matched with `index()`,
so it is taken literally. The extension check does not apply to marked lines.

The chore(release) gate re-derives the edit through the same `peal_version_edit`. It
accepts exactly the token change and refuses a commit that changes more, such as the
SHA on the same line. The gate needed only a comment change.

Peal's own `.peal/config.yml` lists `plugin/templates/decisions.yml` with the Get Peal
fetch line as its marker. The next release sets the `# vX.Y.Z` comment there along with
`plugin.json`.

Decided with the human at planning: the release bumps the tag only (option A).
- The SHA on that line is still set by hand once the tag exists. Until then the
  template's SHA and tag disagree.
- CI never sees that: its harness jobs check out without tags, so `tools/pins.test.sh`
  skips its SHA check there. Local clones with tags fail it until the SHA is updated.
- Fixing this needs a narrow write after `peal ship tag` that sets the SHA (option D),
  filed as an idea.
- The template comment and `docs/reference/configuration.md` say this.

Nested YAML fields were left out: the target line is text inside a `run: |` block, not a
YAML field. They are filed as an idea of their own, and the docs keep saying a dotted
field is refused. `tools/ci-changes.sh` was left as it is, so a release commit runs all
harnesses.

`tools/pins.test.sh` changed, although it is outside the plan's touches: its "a
different tag is reported" case used v0.3.0, which would equal the version after the
next release. It now uses v99.0.0.

Checks:
- `ship.test.sh`, `githooks.test.sh` and `hostile.test.sh` pass, also under mawk, nawk
  and busybox awk.
- In a scratch copy, `plugin.json` and the template were bumped to 0.3.0;
  `pins.test.sh` and `pins.sh` stayed green.
- `peal_version_edit` on the real template changes exactly line 48's tag.

### Reviewer findings not acted on

- The gate's "changes more than its $field" message was not reworded as the plan said.
  For a marker it reads `its "TEXT" to X`, which is clear enough. The stale gate comment
  the reviewer noted was fixed.
