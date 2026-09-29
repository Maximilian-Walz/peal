# Milestones

A milestone is a goal with tasks. Set one up when the backlog has grown past what you
can hold in your head, or when there is something to ship that several tasks add up to.
Until then the tasks need no milestone.

## Setting one up

`/peal:setup milestones` asks the first milestone's title, writes it as
`docs/milestones/m1.md` and offers a review task for it. A milestone is one Markdown
file: its data in the frontmatter, its goal and acceptance criteria in the body. Give a
task to a milestone with its `milestone` field, or `peal set-milestone`. The fields and
the states a milestone can be in are in
[Tasks](../reference/tasks.md#milestone-files).

One milestone is `current`. A bare `/peal:work` offers its tasks first, then the tasks
that belong to none. The others are `open` (planned, offered only by name), `parked` (a
reason says why it waits) or `done`.

## Changing a state

`peal milestone-state` is the one way a state changes. It writes onto the main branch
itself, so you run it from anywhere, then pull:

<!-- docs-check: run -->
```text
$ peal init --stage tasks >/dev/null
$ peal init --stage milestones
created docs/milestones/m1.md
$ git add -A && git commit -qm "chore(peal): set up the milestones stage"
$ git push -q -u origin main
$ peal milestone-state m1 parked --reason "waiting for the API"
milestone m1: parked
current milestone: none
$ git pull -q
$ peal milestones
m1 parked 1 - First milestone
$ peal milestone-state m1 open
milestone m1: current
current milestone: m1
```

Parking the only current milestone leaves none current. Whenever none is current after a
change, the first open milestone by order becomes current
([CLI](../reference/cli.md#peal-milestone-state)).

## Closing one

Each milestone has a review task, `depends: [milestone]`: it stays blocked until the
others are done, and its session runs `/peal:milestone-review`. The command lists the
tasks not done, walks each acceptance criterion and asks for evidence of it, files loose
ends as ideas, and triages the backlog. Its last step is one question, "Close m1?". On
yes it runs `peal milestone-state m1 done` with the review as the milestone's record.

The review also runs without a task, as a Belfry action
([running under Belfry](belfry.md)). Milestone files are read-only in an ordinary task:
a task never changes the state of its own milestone.
