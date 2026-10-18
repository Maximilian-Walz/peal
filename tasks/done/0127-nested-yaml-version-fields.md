---
milestone: m3
plan: required
size: M
depends: [0117]
model: opus
touches: [plugin/lib/version-field.awk, plugin/lib/ship.sh, plugin/lib/githooks.sh, plugin/lib/*.test.sh, plugin/bin/peal, plugin/lib/config-defaults.yml, plugin/lib/next.sh, .peal/config.yml, docs/reference/configuration.md, docs/reference/cli.md, docs/design.md]
---

# 0127 — release.version-files reaches a nested YAML field

## Intent

`release.version-files` reaches a top-level field of a JSON, TOML or YAML file, or (task
0117) a marked line. Let it also name a nested YAML field (for example `image.tag` of a
Helm values file), set without touching anything else, and re-derived by the
chore(release) gate.

## Scope

- The item syntax for a nested field (today a dotted field is refused), the edit in
  `plugin/lib/version-field.awk`, the gate, docs and tests.

## Done when

- `peal ship bump` sets a nested YAML field, changing only its value; the gate accepts
  exactly that edit; refusals leave main unchanged.

## Notes

- 2026-10-18, the human's answers at planning:
  - A dotted field stays refused for JSON and TOML: "a dotted field reaches only into a YAML file".
  - Path syntax: `.`-separated segments of `[A-Za-z0-9_-]+`, no quoting or escaping; keys with dots or slashes are unreachable.
  - Lists: no index syntax; everything under a `- ` entry is opaque.
  - Anchors: `image: &img` (an anchor, optional comment) counts as a parent; a `!tag` makes it opaque; fields only inherited through `<<: *base` are "no field". The docs note that an edit under an anchor changes its aliases too.
  - Top-level YAML fields go through the same walker (unify); the existing tests guard the behaviour.
  - The same path in two documents (`---`) is refused as "more than once".
  - A tab-indented line inside a region the walk reads refuses the file ("indented with a tab").
  - A path through a non-mapping gets its own refusal: "the field image is not a mapping".
  - Messages: "no top-level field X" for an undotted field, "no field a.b" for a dotted one.
  - `.peal/config.yml`: only its version-files comment lines change.
  - No new guide example; one line each in configuration.md and cli.md.
  - cli.md's "a dotted field is refused" (kept in 0117) becomes "a dotted field of a JSON or TOML file".

## Plan

Agreed 2026-10-18. Size M, model opus, merge default.

Approach:
- Item syntax (`peal_version_files`, plugin/lib/ship.sh): FIELD becomes `[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*`; a dotted field only for `*.yml`/`*.yaml`, else refused with "a dotted field reaches only into a YAML file"; the "is not PATH: FIELD" message mentions `KEY.KEY`; empty segments fail the regex.
- The edit (plugin/lib/version-field.awk): `yaml()` becomes one walker over block mappings by indentation, a top-level field being a path of one segment. Indent = leading spaces; blank and comment-only lines skipped; `---` resets the walk, `...` ends the document. A key line is `KEY[ \t]*:` then a blank or line end, at indent n; KEY compared literally to the segment. Stack entries with indent >= n are popped before each key line. Any key (quoted, non-word) is still tracked so the stack stays right. A key with an empty value (or only a lone `&anchor` and/or comment) is a parent; a key with an inline value is a leaf and makes lines with indent > n opaque (block scalars, multi-line scalars, flow collections, `!tag`). A sequence entry or any non-key line at indent k makes indent > k opaque. At the full path, today's value checks apply; the one-line check becomes "the next non-blank line is not indented beyond the key". Found twice (also across documents) is refused; a prefix that is a leaf is refused "the field X is not a mapping"; a tab-indented line in a read region is refused "indented with a tab". Messages: "no top-level field X" / "no field a.b". POSIX awk only (gawk, mawk, nawk, busybox). JSON and TOML untouched; the END check allows a dotted field only for format=yaml.
- The gate (plugin/lib/githooks.sh `_peal_pre_push_release`): already re-derives through `peal_version_edit`; comments only.
- Docs and help: version-field.awk header, ship.sh comments, docs/reference/configuration.md, docs/reference/cli.md (dotted refusal now JSON/TOML only, new refusals, the anchor/alias note), docs/design.md wording, plugin/lib/config-defaults.yml and its comment copy in .peal/config.yml (version-files lines only), plugin/bin/peal help; next.sh:177-178 comment tweak at most.

Verification:
- plugin/lib/ship.test.sh `bump`: `values.yaml` with `image:\n  repository: x\n  tag: "0.1.0" # pinned` plus decoys (top-level `tag`, `other.tag`, a block scalar holding `tag:`, compact and indented lists with `tag:`, a comment `# image.tag`); `"values.yaml: image.tag"` bumps exactly one line (`diff -U0`), quoting and comment kept; rerun "already at"; `peal ship tag` refuses while stale.
- Refusals through `bump_refused` (main unchanged): `image.nope`, `image.repository.x` (not a mapping), a nested number, a nested block scalar, the path twice (duplicate key, second document), `plugin.json: deps.version` (message updated), `image..tag`, `.tag`, a flow-map parent, a tab-indented line.
- plugin/lib/githooks.test.sh `pre_push_release`: a nested bump passes the gate; a hand commit also changing `other.tag` or the target line's comment is refused.
- plugin/lib/hostile.test.sh: a `yamlfield` case `"values.yaml: image.${H[i]}"`, main unchanged.
- Existing top-level YAML cases still pass.
- All three harnesses under gawk, mawk, nawk and busybox awk; then tools/lint.sh and tools/docs.test.sh.

Ranges relied on: tasks/done/0117-release-bumps-template-peal-tag.md:19-160, plugin/lib/version-field.awk:1-198, plugin/lib/ship.sh:65-104, plugin/lib/ship.sh:187-238, plugin/lib/githooks.sh:313-375, plugin/lib/ship.test.sh:203-332, plugin/lib/githooks.test.sh:310-379, plugin/lib/hostile.test.sh:659-681, plugin/lib/yaml-lib.awk:1-15, plugin/lib/config-defaults.yml:40-48, plugin/lib/init.sh:73-81, plugin/lib/next.sh:176-184, plugin/bin/peal:283-297, .peal/config.yml:54-61, docs/reference/configuration.md:46-56, docs/reference/cli.md:582-591, docs/design.md:436-446, docs/security.md:107-114, tools/docs.test.sh:461-475

## Raw

> Follow-up of task 0117: nested YAML fields in release.version-files, left out of it.

---

## Outcome

Built: an item of `release.version-files` can now name a nested YAML field, `"values.yaml: image.tag"`. `peal ship bump` replaces only that value's characters, and the quoting and the trailing comment stay as they are. The chore(release) pre-push gate re-derives the commit through the same `peal_version_edit`. It accepts exactly that edit and refuses a commit that changes anything more (checked in `githooks.test.sh`). Every refusal leaves main unchanged (`bump_refused` in `ship.test.sh`; a `yamlfield` case in `hostile.test.sh`).

- `plugin/lib/version-field.awk`: `yaml()` is now one walker over block mappings by indentation. Top-level fields go through it too, as a path of one segment. The value checks moved into `yaml_value()`. The check for a one-line value skips blank lines and compares indents.
- Agreed at planning (see Notes):
  - dotted fields reach only into YAML; JSON and TOML refuse them with "a dotted field reaches only into a YAML file"
  - segments are `[A-Za-z0-9_-]+`, with no quoting
  - nothing under a sequence is reachable
  - a lone `&anchor` is a parent, while a `!tag` or a flow map refuses with "the field X is not a mapping"
  - a path found twice, or in two documents, is refused
  - a tab-indented line inside a region the walk reads is refused
- Departures from the plan, all safe in the same direction: the result is a "no field" refusal, never a wrong edit.
  - A column-0 line that is neither a key nor a list entry makes the rest of its document unreadable. That covers a scalar document, a `%` directive, a flow collection and `? key`.
  - A `---` with content on it (`--- |`, `--- !!map`) does the same.
  - Quoted keys are tracked, so the indentation stays right, but they never match a segment.
  - So a few top-level-field files that used to be edited are now refused: `--- !!map`, a column-0 `? key` before the field, and a tab-indented line inside a region the walk reads. The reviewer verified this.
- Fields inherited only through `<<: *base` are "no field". The docs do not say so.
- The tests ran under mawk, nawk and busybox awk: ship 474, githooks 432, hostile 1431, docs 37, all passing, and lint is clean. gawk was not installed in the build session, so nothing ran under it; CI covers the default awk.
- The review found one stale comment above `peal_ship_bump`, fixed in its own commit. Nothing else came out of the review.
