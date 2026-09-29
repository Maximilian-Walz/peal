# Releases

A release is a tagged version, made from the tasks finished since the last one. Run
`/peal:release` on the main branch, in any session; it claims nothing and works with
either storage. Do not confuse it with `peal release ID`, which releases a claim's
worktree: the docs write "release a claim" for that.

## What it does

`/peal:release [version]` reads what went in since the last tag, proposes the next
version, shows the notes and asks "Release v0.2.0?". The bump is proposed, not decided:
minor for a feature, patch for fixes, major for a breaking change. A task that
should stay out of the notes says `release-note: none`. On yes it sets the version files,
tags, publishes the release on GitHub and, if you turned `release.wait-ci` on, waits for
the workflow runs of the tag. Every step is a `peal ship` subcommand you can run on its
own after a failure ([CLI](../reference/cli.md#peal-ship)).

## The version files and the changelog

Name the files that hold the version, and optionally a changelog to keep, in
`.peal/config.yml`:

<!-- docs-check: config -->
```yaml
release:
  version-files: ["package.json: version"]
  changelog: CHANGELOG.md
```

Each release then sets the field of every version file and inserts its entry into the
changelog, in one commit on the main branch. Either key alone is enough, and without
either there is nothing to bump: the tag is the release. Every setting is in
[Configuration](../reference/configuration.md#settings).

## Underneath

A project with a version file, a changelog and one `feat` commit since nothing was
released. The file it bumps is not in the stage's files, so the block writes it first:

<!-- docs-check: run -->
```text
$ peal init --stage tasks >/dev/null
$ printf 'release:\n  version-files: ["package.json: version"]\n  changelog: CHANGELOG.md\n' >>.peal/config.yml
$ printf '{"name": "app", "version": "0.0.0"}\n' >package.json
$ git add -A && git commit -qm "chore(peal): set up the tasks stage"
$ git commit -q --allow-empty -m "feat(app): a health check endpoint"
$ git push -q -u origin main
$ peal ship propose
LAST none
ITEM feature - - a health check endpoint
PROPOSE v0.1.0 first
$ peal ship bump 0.1.0
bumped package.json CHANGELOG.md to 0.1.0 on origin/main: …
$ git pull -q
$ cat CHANGELOG.md
# Changelog
## v0.1.0 …
### Features
- a health check endpoint
$ peal ship tag 0.1.0
tagged v0.1.0 …
```

With a changelog set, `bump` comes before `tag`: the tag is refused without its entry.
