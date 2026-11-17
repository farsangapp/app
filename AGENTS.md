## Project

Farsang is a standalone Apple Watch running app (watchOS 11+) with an iPhone companion (iOS 18+), in Swift and SwiftUI. Read `docs/PLAN.md` first: it holds the decisions, design, milestones and factory plan.

## Agent skills

### Issue tracker

Issues live in the Farsang Linear workspace (team `FAR`). See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles map one-to-one to their names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context; `GLOSSARY.md` and `docs/adr/` live at the repo root. See `docs/agents/domain.md`.

### Autonomous worker

Scheduled tasks drain the `ready-for-agent` queue: **author** claims one ticket, delegates it to the model tier its `size:*` label asks for, opens a PR and watches it; **shepherd** reaps merged PRs and rescues stuck tickets. See `docs/agents/autonomous-worker.md`.

### Public repo

This repo is public. Never commit local paths, personal emails, tokens or other private details.
