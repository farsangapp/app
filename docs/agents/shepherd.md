# Shepherd

A scheduled task runs this file. It is the janitor for tickets the author has
left `In Review`: it reaps merged PRs, cleans up, and rescues stuck tickets. It
does **not** start new work. The queue is Linear team `FAR`.

The author normally answers review feedback itself, by watching its PR. The
shepherd's section 2 is the fallback if that proves unreliable (see the rollout
notes in `autonomous-worker.md`). Leave section 2 switched off until the owner
says to use it.

Before anything else, read `docs/agents/issue-tracker.md`.

## 0. Reap merged PRs

```
list_issues: team "FAR", label "agent-claimed", state "In Review"
```

For each ticket, find the PR URL in the author's earlier comment and check it:

```sh
gh pr view <url> --json state,mergedAt,mergeStateStatus,headRefName,headRefOid
```

- **merged** (`state` is `MERGED`):
  - `save_issue` state `"Done"` if it is not already; comment `Merged: <url>`.
  - Remove the PR's worktree. Find it with `git worktree list` by matching the
    branch (`headRefName`). If it is dirty (`git -C <path> status --short`),
    keep anything useful before removing with `--force`; if you cannot preserve
    it, stop and comment instead of deleting.
  - From outside the removed worktree, delete the local branch. Skip when it does
    not exist (`git show-ref --verify --quiet refs/heads/<name>`). Otherwise
    compare the merged head (`headRefOid`) with the local tip
    (`git rev-parse refs/heads/<name>`) and run `git branch -D -- "<name>"` only
    when they match; a tip that has advanced means someone kept working there,
    so leave it. Squash merges leave the tip outside `main`'s ancestry, so `-d`
    refuses and `-D` is safe once the tips match.
  - Leave remote branches untouched.
- **closed, not merged:** comment why; `addLabels ["needs-info"]`,
  `removeLabels ["agent-claimed"]`, `assignee null`, state `"Todo"`.
- **still open** (checks running, awaiting review, conflict): leave it.

### Merged before the shepherd ran

Linear moves a ticket to `Done` as soon as its PR merges, so a PR that merged
between two runs is never `In Review` when this step lists tickets. Also check
the recently finished ones:

```
list_issues: team "FAR", label "agent-claimed", state "Done", updatedAt "-P3D"
```

For each, look in `git worktree list` for a worktree or local branch named after
the ticket (`far-<n>-...`). If one exists, run the same cleanup as for a merged
PR above (worktree, then local branch with the tip check). Skip tickets with no
leftover worktree or branch.

## 1. Rescue stuck tickets

```
list_issues: team "FAR", label "agent-claimed", state "In Progress"
```

A ticket `In Progress` for more than three hours with no recent comment and no
running delegate is stuck: comment what you found, `assignee null`,
`addLabels ["ready-for-agent"]`, `removeLabels ["agent-claimed"]`, state
`"Todo"`. Do not touch one whose delegate
is still running (`task_status` shows it).

## 2. Respond to change requests (fallback, off by default)

Only when the owner has switched this on. For each `In Review` ticket, read the
PR's decision:

```sh
gh pr view <url> --json reviewDecision --jq .reviewDecision
```

`CHANGES_REQUESTED` makes that ticket the target; anything else is skipped. Make
**at most one** fix per run. Delegate it exactly as `author.md` step 6 describes
("Changes requested or new review comments"), using the ticket's current tier.

## Failure

If anything in steps 0-2 fails:

- `save_comment` on the ticket: what broke, what you tried, the exact error.
- Open a failure ticket titled `Worker failure: <issue-id>` labeled
  `ready-for-human`, linked from that comment.
- The ticket already has an open PR, so do not put it back on `ready-for-agent`.
  Transient: leave it `In Review`. Permanent: comment what is blocked,
  `addLabels ["ready-for-human"]`, `removeLabels ["agent-claimed"]`,
  `assignee null`, state `"Todo"`.

## Guardrails

- Never start new implementation work.
- Never approve or merge a PR. Merge happens only through auto-merge.
- Never delete tickets or comments; only comment.
- Never remove a dirty worktree without preserving or reporting its changes.
