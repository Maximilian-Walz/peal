# Releases

A release is a tagged version, made from the tasks finished since the last one. Run
`/peal:release` on the main branch, in any session; it claims nothing and works with
either storage. Do not confuse it with `peal release ID`, which releases a claim's
worktree: the docs write "release a claim" for that. Under Belfry, the release runs
as a GitHub workflow instead ([Under Belfry](#under-belfry)).

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

A commit SHA a release cannot hold in its own commit (a pinned reference to the release)
goes into `release.commit-files` as a marked line; `peal ship pin <version>` sets it to
the tag's commit once the tag exists, as a commit of its own.

## Under Belfry

A Belfry session cannot release: its commands run in a sandbox, where only a plain `git
push`, `git fetch` or `git pull` reaches the remote, while `peal ship` runs its own
fetches, pushes and `gh release` calls inside one process, without a key or a `gh` login.
So under Belfry the release runs as a GitHub workflow that the action of the Releases
tab's button dispatches, with no session and no sandbox involved.

Peal ships one as a starter. `peal init --stage belfry --release-workflow` (or
`/peal:setup belfry`, which asks) writes it to `.github/workflows/release.yml`, a copy
of `plugin/templates/release.yml` that runs `peal ship` from a Peal it fetches pinned by
SHA, never from the project. The `.belfry.yml` the stage writes ends with the matching
action as a comment; uncomment it (and the `actions:` line). It is the action `release`
with `workflow: release.yml`, `inputs: { version: { ask: true, pattern:
'v[0-9]+\.[0-9]+\.[0-9]+' } }`, `triggers: [button]`, `single: true` and `release:
true`.

The `pattern` follows `release.tag-prefix` (`v` by default, so `v1.2.0`). The stage
leaves it out when the prefix is empty or holds a character other than letters, digits,
`_`, `-` and `/`; the workflow checks the version itself either way. `peal init --remove
belfry` removes the starter only while it is still Peal's copy, and keeps one you
edited. Peal releases itself the same way, with a workflow of its own.

The starter's Peal pin is the release it came with. To move it to another release, take
that release's commit from `git ls-remote https://github.com/Maximilian-Walz/peal
'refs/tags/vX.Y.Z^{}'` and change both the SHA and the tag in the comment of its `Get
Peal` step, as for the other templates.

The button asks for the version, and the version typed in is the confirmation that
`/peal:release` would otherwise ask for. The workflow runs `peal ship propose` and
`notes`, then `bump`, `tag`, `publish`, `pin`, and `wait` when `release.wait-ci` is on.
Its last step prints `version: vX.Y.Z` and `url: <the release>`, in the log and in the
run's summary, and Belfry's inbox item shows them.

Its two inputs, for a dispatch by hand too (`gh workflow run release.yml -f
version=v1.2.0`):

- `version`: `v1.2.0` (also `1.2.0`, or with a pre-release suffix); empty, the one `peal
  ship propose` proposes. A real run with no version when nothing calls for a release
  fails: name a version.
- `dry_run`: prints the proposal and the notes and tags nothing. It needs no secret and
  runs on any branch; a real run refuses any branch but the main branch (`peal config
  main`, read when the run starts).

The proposing job writes nothing. In the starter it reads the repository, and the
issues and pull requests the notes of the issues storage come from, with the run's own
`GITHUB_TOKEN`, read-only (contents, issues, pull requests) and given only to the step
that reads, so a private repository works as a public one.

Set it up once:

1. Create a GitHub App owned by the repository's owner, with the repository permissions
   Contents and Pull requests (read and write) and Actions, Checks, Commit statuses and
   Issues (read), and install it on the repository. Do not make it a bypass actor of
   main's rules: where main refuses direct
   pushes, `peal ship bump` and `pin` go through a pull request (`main-writes: auto`),
   whose checks run because the App opened it. A pull request the run's own
   `GITHUB_TOKEN` opens starts no workflow, so its auto-merge would wait forever.
2. Create the environment `release` (Settings, Environments), restricted to the main
   branch, with the secrets `PEAL_RELEASE_APP_ID` (the App's ID) and
   `PEAL_RELEASE_APP_KEY` (a private key of the App). A real run whose secrets are
   missing fails before it writes anything.

The App's bot (`<app-slug>[bot]`) makes the bump and pin commits and the annotated tag,
so the identity they name is the one that pushes them.

A run that fails halfway is not resumed. Read its log for the step that failed, fix the
cause, then finish by hand where `gh` is logged in, from that step on. Each `peal ship`
step does nothing, or refuses, where its work is done already: `bump` answers `already
at`, `tag` refuses a tag that exists, `publish` brings an existing release up to date.
After a failed `tag`, for instance, run `peal ship tag v1.2.0`, then `peal ship publish
v1.2.0` and `peal ship pin v1.2.0`.

A new dispatch with the same version works only while its tag does not exist yet.
