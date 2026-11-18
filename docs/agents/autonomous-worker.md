# Autonomous worker

Autonomous work runs as scheduled tasks in T3 Code that drain the Linear queue
(team `FAR`). It is built on T3 Code's own tools: `schedule_task` for the
trigger, `delegate_task` for the implementation, `watch_pull_request` for review
and CI feedback.

| Task | File | Queue | Responsibility |
| ---- | ---- | ----- | -------------- |
| **Author** | [`author.md`](author.md) | `ready-for-agent` | Claim one ticket, delegate it to the model tier its size label asks for, open a PR, watch it, answer review feedback. |
| **Shepherd** | [`shepherd.md`](shepherd.md) | `In Review` | Janitor: reap merged PRs, clean up worktrees, rescue stuck tickets. Also the fallback responder if PR watching proves unreliable. |

CodeRabbit reviews every PR. The human owner approves every PR for now (see
"Approval" in `docs/PLAN.md`).

## Model tiers

The ticket's size label picks the model. Provider and model ids are the ones
`orchestrator_capabilities` lists.

| Label | Provider instance | Model | Option |
| ----- | ----------------- | ----- | ------ |
| `size:trivial` | `opencode` | `opencode-go/deepseek-v4-pro` | `variant: high` |
| `size:medium` | `claudeAgent` | `claude-sonnet-5-5` | `effort: high` |
| `size:complex` | `claudeAgent` | `claude-opus-5-5` | `effort: high` |

Rules:

- **Two strikes escalate.** A tier that fails the same ticket twice moves it up
  one tier (trivial, then medium, then complex). A ticket that fails twice at
  `size:complex` goes to `ready-for-human`.
- **Attempts are recorded in Linear**, not in memory. Each failed attempt gets a
  comment starting `Attempt <n> (<tier>) failed:`; the next run counts them.
- **Never switch provider silently.** If the needed provider or model is not in
  `orchestrator_capabilities`, do not claim the ticket. Report which one is
  missing and stop.
- A ticket with no `size:*` label is not claimed. Triage labels it first.

## Rollout order

1. Dry-run one ticket by hand, following `author.md` step by step in a normal
   thread. Confirm that a watched PR wakes the thread on a review comment and on
   failed checks.
2. Turn on **author alone**, on a slow interval (60 minutes). It started with
   one open PR at a time; the limit is now **10 open PRs** (`author.md` step 0
   enforces it).
3. Add the shepherd once the author has had clean runs.
4. Raise cadence only after several clean runs in a row.

Kill switch: disable the scheduled tasks (`schedule_task` with
`enabled: false`, or in T3 Code settings). Scheduled runs only fire while the
Mac is on, T3 Code is running, and the external drive holding Xcode is mounted.

## Scheduled task prompts

Keep the prompts short and point at the files, so behavior lives in git:

- Author: `Read docs/agents/author.md in the farsang project and follow it. Do one run.`
- Shepherd: `Read docs/agents/shepherd.md in the farsang project and follow it. Do one run.`

## Identity and secrets

- **Linear:** for now the factory uses the owner's own Linear account, so
  `assignee: "me"` is the owner. The `agent-claimed` label marks agent-owned
  tickets, and every author and shepherd query filters on it, so tickets the
  owner works by hand are never touched. Linear does not notify an account
  about its own comments, so failures are surfaced by the `ready-for-human`
  label (keep a saved Linear view of that label). A separate bot user can
  replace this later: change the Linear connection and drop the label filter.

- GitHub work runs as the shared bot account; its login is set up in the
  environment. No task sets up identity itself.
- The repo is public. Never put local paths, personal emails, tokens or other
  private details in code, commits, PRs, tickets or comments.
- Commits end with the attribution line the environment provides.

## Hardware-only checks

Real GPS, battery drain and the speaker test cannot run in CI or a simulator.
Tickets for them are labeled `ready-for-human` and are never claimed.
