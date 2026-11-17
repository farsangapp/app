# Issue tracker: Linear

Issues and specs for this repo live in the **Farsang** Linear workspace, team
**Farsang** (key `FAR`, to be confirmed against the workspace). Issue
identifiers look like `FAR-123`.

Operate Linear through its MCP tools (the `linear` server). Use them for every
operation below. The GitHub repo is `farsangapp/app` and is used for code and
PRs only, not for issues.

## Epics are Projects

Epics in this repo are Linear **Projects**, not parent issues. This matches
Linear's own Jira mapping, where a Jira Epic maps to a Linear Project
(`Project > Issue > Sub-issue` ≈ `Epic > Story > Sub-task`).

- One project per epic; individual work items are issues assigned to that
  project via `project` on `save_issue`.
- Use **parent issues / sub-issues** only to decompose a *single* issue, and for
  `/wayfinder` maps, not to group an epic.
- A group of epics (e.g. a release) is an **Initiative**, not a grandparent
  issue.

The first epics follow the milestones in `docs/PLAN.md`: M0 Setup, M1 Recording,
M2 Import and sync, M3 Route following, M4 Offline map renderer, M5 Map-pack
pipeline, M6 Polish, M7 Release.

## Conventions

- **Create an issue**: `save_issue` with `team: "FAR"` and `title`. Pass
  `description` as Markdown with literal newlines (no escape sequences).
- **Update an issue**: `save_issue` with `id: "FAR-123"` plus only the fields to
  change.
- **Read an issue**: `get_issue` with `id: "FAR-123"`.
- **List issues**: `list_issues` with filters (`team`, `state`, `label`,
  `assignee`, `project`, `parentId`, `query`).
- **Make a sub-issue**: `save_issue` with `parentId: "FAR-123"`.
- **Comment**: `save_comment` with `issueId` + `body`; reply to a thread with
  `parentId` + `body`.
- **Apply / remove labels**: `addLabels` / `removeLabels` on `save_issue`
  (update path). Create labels with `save_issue_label`.
- **Set state**: `state` on `save_issue`: `Todo`, `Backlog`, `In Progress`,
  `Done`, `Canceled`, or `Duplicate`.
- **Relations**: `blockedBy`, `blocks`, `relatedTo` on `save_issue` (all
  append-only; use `removeBlockedBy` / `removeBlocks` / `removeRelatedTo` to
  clear edges).

## Agent-owned tickets

The factory acts as the owner's Linear account, so the `agent-claimed` label
(added at claim, removed on release) marks which tickets the agents own. See
`docs/agents/autonomous-worker.md`.

## Size labels

Every ticket carries one of `size:trivial`, `size:medium`, `size:complex`. The
factory uses it to pick the model tier (see `docs/PLAN.md`).

## When a skill says "publish to the issue tracker"

Create a Linear issue with `save_issue` (team `FAR`).

## When a skill says "fetch the relevant ticket"

Read it with `get_issue` by its `FAR-<n>` identifier.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as
tickets.

- **Map**: a single issue in team `FAR` labelled `wayfinder:map`, holding the
  Notes / Decisions-so-far / Fog body.
- **Child ticket**: an issue with `parentId` set to the map, labelled
  `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`). Once
  claimed, the ticket is assigned to the driving dev.
- **Blocking**: `blockedBy` on the child (list the blocker identifiers). A
  ticket is unblocked when every blocker is `Done`.
- **Frontier query**: `list_issues` with `parentId: "<map>"`; drop any with an
  open blocker or an assignee; first in map order wins.
- **Claim**: `save_issue` with `id` and `assignee: "me"`, the session's first
  write.
- **Resolve**: comment the answer, then set `state: "Done"`.
