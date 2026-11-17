# Author

A scheduled task runs this file. Each run drains **at most one**
`ready-for-agent` ticket end to end: claim it, delegate the implementation, open
a PR, enable auto-merge, then watch the PR and answer feedback. The queue is
Linear team `FAR`. Tiers and escalation rules are in
[`autonomous-worker.md`](autonomous-worker.md).

Before anything else, read `docs/agents/issue-tracker.md` and
`docs/agents/triage-labels.md`.

## 0. Capacity check

```
list_issues: team "FAR", label "agent-claimed", state "In Review"
```

If any ticket is `In Review`, a PR of yours is still open: report "PR open, not
starting new work" and stop. This keeps one PR in flight while the factory is
new. (Remove this rule only when the owner says so.)

Also call `orchestrator_capabilities` once in this thread, before the first
`delegate_task`, and keep the result for step 3.

## 1. Find

```
list_issues: team "FAR", label "ready-for-agent", assignee "null"
```

Walk the results by urgency, most urgent first: Linear `priority` orders `1`
(Urgent) ahead of `2` (High), `3` (Medium), `4` (Low), and `0` (No priority).
Break ties oldest-first. For each candidate:

- Confirm it has no open blockers (`get_issue` with `includeRelations: true`;
  skip if `blockedBy` lists anything not `Done`).
- Confirm it carries exactly one `size:*` label. If not, skip it.
- Count its earlier `Attempt <n> (<tier>) failed:` comments to decide the tier
  (see step 3).

The first candidate that passes is your target. No target: report "queue empty"
and stop. Do not invent work.

## 2. Claim (the lock)

Before writing any code:

```
save_issue: id, assignee "me", state "In Progress",
            addLabels ["agent-claimed"], removeLabels ["ready-for-agent"]
```

The assignee write is the lock; it stops a concurrent run from taking the same
ticket. Never work a ticket you haven't claimed.

While the factory shares the owner's Linear account, `"me"` is the owner, so the
`agent-claimed` label is what marks a ticket as agent-owned. Every "my tickets"
query uses that label, never the assignee alone, so tickets the owner is working
by hand are never touched.

Only claim after step 3's tier check passes, so that an unavailable provider
never leaves a claimed ticket behind.

## 3. Pick the tier

Start from the `size:*` label, then apply escalation: every two failed attempts
at a tier move the ticket up one tier. Look the tier up in the table in
`autonomous-worker.md`.

- Tier is available in `orchestrator_capabilities`: continue.
- Not available: do not claim. Report the missing provider or model and stop.
  Never fall back to another model.
- Already failed twice at `size:complex`: go to the Failure section as
  permanent.

## 4. Implement in a delegated worktree

```
delegate_task:
  role: implementation
  isolation: worktree
  mode: async
  target: { providerInstanceId, model, options }   # from the tier table
  title: "<issue-id> <title>"
  task: <brief below>
```

Follow the tool's `next` guidance and do not poll or sleep for the child.

The brief must be self-contained, because the child gets no history. Include:

- The issue identifier, title, description and acceptance criteria.
- The branch name: `far-<n>-<kebab-title>`, lowercase, built from the issue
  identifier and title. Linear's `gitBranchName` carries a `<user>/` prefix;
  drop it. The branch-naming check rejects anything else, and the prefix would
  also leak a username into the public repo.
- Read `docs/PLAN.md`, `docs/agents/domain.md`, `GLOSSARY.md` and any relevant
  `docs/adr/` first (skip files that don't exist).
- Implement with the `/implement` skill (it drives `/tdd` and closes with
  `/code-review`).
- Build and test must pass locally with the Xcode available on this Mac.
- Open a pull request from that branch with `gh pr create`; do **not** merge.
  Use `/pr` for the body, and link the ticket `FAR-<n>`.
- Keep the repo's privacy rule: no local paths, emails or tokens anywhere.
- Return the PR URL and a one-line summary, or a precise error if it fails.
- Do not watch the PR; the parent does that.

## 5. Open the loop

When the child returns a PR URL:

1. `save_comment` on the ticket with the PR URL and a one-line summary.
2. Request a CodeRabbit review only if no automatic review starts within a few
   minutes: comment `@coderabbitai review` on the PR.
3. Enable auto-merge so the PR merges the moment it can:
   `gh pr merge <url> --auto --squash`. It waits on the required checks and the
   owner's approval. If enabling it fails, leave the PR open and say so on the
   ticket.
4. `save_issue`: state `"In Review"`.
5. `watch_pull_request` on the PR, then **end the turn**. The watch wakes this
   thread on failed checks, new reviews or comments, and conflicts. Do not call
   it again on a wake.

## 6. On a wake

Handle old comments first, then the new event. A wake is not a merge decision.

- **PR merged:** `save_issue` state `"Done"` (if Linear has not already done it),
  comment `Merged: <url>`, remove the worktree and local branch following
  `shepherd.md` step 0, and finish.
- **Checks failed:** read the failing job's log (`gh run view --log-failed`),
  delegate a fix as in step 4 but on the PR's existing branch
  (`gh pr checkout <url>`; do not start from `main`), and push to the same
  branch. A failed attempt counts toward the two-strike rule.
- **Changes requested or new review comments** (human or CodeRabbit): delegate
  the fix the same way. The child must:
  - read the requested changes (`gh pr view <url> --json reviews,comments`,
    inline comments via `gh api repos/{owner}/{repo}/pulls/<n>/comments`);
  - implement them with `/implement`, and push to the same branch;
  - react with 👍 to each comment its commit resolved (inline:
    `gh api -X POST repos/{owner}/{repo}/pulls/comments/<id>/reactions -f content=+1`;
    top-level: `.../issues/comments/<id>/reactions`), and reply only to answer a
    question, disagree or add context, naming the commit;
  - not resolve the reviewer's threads (they resolve their own);
  - re-request review from the human collaborator (the one that is not the bot):
    `gh pr edit <url> --add-reviewer <login>`.
  Then re-enable auto-merge and end the turn again.
- **Conflict:** rebase the branch onto `main` in the worktree, push with
  `--force-with-lease`, and end the turn.
- Never approve the PR yourself.

## Failure

If anything in steps 2-6 fails:

- `save_comment` on the ticket: what broke, what you tried, the exact error,
  starting with `Attempt <n> (<tier>) failed:` when an implementation attempt
  failed.
- **Notify the human**: the failure ticket's `ready-for-human` label is the
  alert. Linear does not notify an account about its own comments, and the
  factory currently acts as the owner, so an @-mention would reach nobody.
- **Open a failure ticket** in team `FAR` titled `Worker failure: <issue-id>`,
  label `ready-for-human`, with what broke and the exact error. Link it from the
  comment on the stuck ticket.
- Then mark the ticket so it isn't silently re-picked:
  - **Permanent** (can't be solved, or two failures at `size:complex`):
    `addLabels ["needs-info"]` (or `ready-for-human` for hardware-only work),
    `removeLabels ["agent-claimed"]`, `assignee null`, state `"Todo"`.
  - **Transient** (environment, flaky CI, tool error): `addLabels
    ["ready-for-agent"]`, `removeLabels ["agent-claimed"]`, `assignee null`,
    state `"Todo"` to retry.
  - If a PR is already open, leave the ticket `In Review` and let the next
    wake or shepherd run retry; do not re-queue it as new work.
- Never leave a ticket stuck in `In Progress` with no comment.

## Guardrails

- **One ticket per run**, even if the queue is long.
- **Claim before work**; the assignee write is the lock.
- **Merge only via auto-merge.** Never force-merge a PR whose checks or review
  haven't passed.
- **Never switch model provider silently.**
- **Never delete** tickets or comments to "clean up"; only comment.
- **Public repo:** no local paths, personal emails or tokens in anything you
  write.
