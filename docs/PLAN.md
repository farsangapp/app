# Farsang: plan and decisions

Handoff document, written 2026-11-17 from the planning conversation. Read this first.

## Goal
A standalone Apple Watch running app with a good UI and offline maps, plus an iPhone companion for GPX import and settings. For personal use first, App Store later. Built with an agent "software factory" modeled on an earlier agent-driven iOS project.

## Decided
| Topic | Decision |
|---|---|
| Name | **Farsang** (old Persian unit of distance) |
| Bundle IDs | `dev.djawadi.farsang` (iPhone), `dev.djawadi.farsang.watchkitapp` (watch) |
| Platforms | watchOS 11+ and iOS 18+ (defaults; owner's watch is GPS-only, no phone during runs, model/OS not yet confirmed) |
| Language | Native Swift and SwiftUI for both apps. Not React Native. |
| Sports | Running only for v1 |
| Units | km or mi, a setting |
| Apple account | Start with a free account. Enroll ($99/yr) when ready for TestFlight. |
| GitHub | Org `farsangapp`, repo `farsangapp/app`. Shared bot account `amin4mej` (used across projects), added to the repo. Repo is **public**, so macOS CI minutes are free. |
| Linear | New workspace, created after the name (now chosen). |
| Approval | At first the owner approves every PR. Automatic merge comes later. |
| PR review | CodeRabbit. Free on public repos. No star minimum found in CodeRabbit's own pages (an earlier note claimed repos under 10 stars need a manual trigger; unconfirmed). If the first PR gets no automatic review, the author task posts `@coderabbitai review`. |
| Model tiers | Trivial: best OpenCode model (start with DeepSeek V4 Pro). Medium: Claude Sonnet 5.5. Complex: Claude Opus 5.5. Label tickets `size:trivial`, `size:medium`, `size:complex`. A tier that fails twice escalates one tier, then goes `ready-for-human`. If a provider is unavailable, stop and report, never silently switch. |

## Map approach
- Apple Maps offline maps exist on Apple Watch (downloaded in Maps on the iPhone, "Sync with Apple Watch"). Source: https://support.apple.com/guide/watch/use-offline-maps-apd0111bf788/watchos
- Unknown: whether third-party apps using MapKit on watchOS can use those offline maps. The user would also have to download regions in Apple Maps by hand.
- **First spike, on the real watch:** a tiny MapKit test app, phone away, area downloaded in Apple Maps. If the map renders, Apple Maps is the map.
- **Fallback:** Protomaps PMTiles (OpenStreetMap data, ODbL, attribution required). Phone extracts a corridor around the route with `pmtiles extract`, sends it to the watch with `WCSession.transferFile`, and the watch draws it with SwiftUI `Canvas`. Open question: how ODbL share-alike applies to an extract bundled in an app. Needs a legal read before selling.
- Do not use OSM public tile servers (bulk/offline downloading prohibited). Mapbox offline needs its SDK (no watchOS) and forbids preloading/redistribution. Stadia caps offline caching at 100 MB per device. MapTiler bulk-download terms are unclear.
- Put the map behind a small interface so the two options are swappable.

## Design (see `docs/design/watch-v4.html`, `docs/design/phone-v1-sketch.html`)
Structure copies Apple's Workout app: **Controls (left)**, **workout views in the middle (Digital Crown scrolls)**, **Now Playing (right)**.

- Controls: End, Pause, Segment, Mute (silences voice and haptic cues). Apple's own list also has New and Check In (later). Apple's current controls list has no Lock. Users report Water Lock moved to Control Center in watchOS 10 (user-reported).
- Views v1, in order: **Map (first when a route is loaded)**, Metrics, Heart Rate Zones, Segment. A free run with no route starts on Metrics. Views can be reordered or hidden.
- Metrics: elapsed time, distance, average pace, rolling km, heart rate.
- Alerts (turn cue, off route) show over any screen.
- **Voice for every alert**, plus banner and haptic: turn ahead, off route, back on route, each kilometer, segment marked, paused/resumed/ended. Voice is on by default and each type can be turned off on the iPhone. Bluetooth headphones will work. **Unverified:** whether the watch speaker can speak aloud without headphones. Test on the real watch.
- Palette: dark OLED, amber for the route and time, cyan for the user and pace, green for distance, red for heart rate and off-route.
- Deferred to later: Metrics 2, Split, Elevation, Power, Activity Rings, and our own screens (Route progress).
- iPhone: routes library with offline-map status, route detail with offline corridor size, settings. The phone sketch is from the first round and has not been revised.

## Scope
- **v1:** record a run to Health, import GPX on the phone and sync to the watch, show the route on the map, follow it (off-route and turn cues with haptics and voice), the screens above, settings, units.
- **v1.1 (planned, not v1):** race pace targets, heart-rate-zone targets, structured programs.
- Research on what to build after v1: `docs/research/feature-research.md`.

## Milestones
| # | Milestone | Done when |
|---|---|---|
| M0 | Setup: watchOS simulator runtime, signing, XcodeGen skeleton, **Apple Maps offline spike** | App installs on the watch, spike result known |
| M1 | Watch records a run (HealthKit workout, GPS route) | A real run shows in Fitness |
| M2 | Phone imports GPX and syncs to watch | Route on the watch with no phone nearby |
| M3 | Route following, off-route, turn cues (haptic + voice) | Simulated GPX run behaves correctly |
| M4 | Offline map renderer plus battery test (if Apple Maps spike failed) | 1-hour run with map on has acceptable battery drain |
| M5 | Map-pack pipeline end to end (fallback path only) | Real map around a real route, offline |
| M6 | UI polish, settings, always-on display | Daily use feels good |
| M7 | TestFlight, then App Store | Privacy policy, screenshots, review passed |

Hardware-only checks (real GPS, battery, speaker test) stay `ready-for-human` in the factory.

## Software factory
Modeled on an earlier agent-driven iOS project: `docs/agents/` files (`author.md`, `shepherd.md`, `autonomous-worker.md`, `issue-tracker.md`, `triage-labels.md`) and `.github/workflows` (branch-naming check, build-and-test).

- Three scheduled tasks in T3 Code: **author** (claims one `ready-for-agent` ticket, implements in a worktree, opens a PR, enables auto-merge), **shepherd** (reaps merged PRs, addresses change requests), and CodeRabbit as reviewer.
- Queue is Linear labels and states. Claim = assignee write. Order = priority, then oldest, skipping tickets with open blockers.
- Failures: comment with an `@`-mention, open a `Worker failure: <id>` ticket labeled `ready-for-human`.
- Differences from that project: T3 `schedule_task` and `delegate_task` instead of OpenChamber; model tiers by size label; public repo and free macOS CI.
- Scheduled runs only fire while the Mac is on and T3 Code is running. Xcode 27 is installed on an external drive, which must be mounted.
- Linear MCP server is added at user scope (`linear-server`). For unattended runs, prefer an API key in an `Authorization: Bearer` header over the browser sign-in.
- Planned T3-native shape: the author claims one ticket, delegates implementation with `delegate_task` (`isolation: worktree`, model by size label), then links and watches the PR itself with `watch_pull_request` and handles review feedback when woken. The shepherd shrinks to an optional janitor (merged worktrees, stuck tickets). Linear's GitHub integration can mark tickets Done on merge. Later option: a webhook schedule fired by Linear instead of polling.
- Order of turning it on: author alone on a slow interval with one open PR max, then add shepherd, raise cadence only after clean runs. Kill switch: disable the scheduled tasks.

## Environment notes
- Xcode 27.0 (27A266a) selected, from the external drive. `xcodegen` installed via Homebrew.
- watchOS simulator runtime: installed by the user (2026-11-17).
- The `gh` CLI switches GitHub accounts by repo remote: `farsangapp` repos use the shared bot account `amin4mej`.
- Local project folder is a git repo whose `origin` is `git@github.com:farsangapp/app.git` (public).

## Open items (waiting on the user)
Resolved 2026-11-17: v4 watch design accepted; org `farsangapp` and repo `farsangapp/app` created; bot is `amin4mej`; Linear workspace and team `FAR` created and the Linear MCP server connected (user scope); `gh` logged in as the bot; watchOS simulator installed; test watch is Series 7 on watchOS 26 with iOS 27 (deployment targets stay watchOS 11+ / iOS 18+); model tiers confirmed (all three available in T3 Code).

Still open:
0. Linear: `In Review` status added. The factory uses the owner's Linear account for now; the `agent-claimed` label marks agent-owned tickets. A separate bot user is a later option.
1. Install CodeRabbit on `farsangapp` (user said later).
2. Decide whether to adopt a "no comments in code" rule.
3. Give feedback on the iPhone screens (the sketch is still the first round).
4. Verify during the hand dry-run that `watch_pull_request` wakes correctly inside a scheduled run's thread (otherwise fall back to a polling shepherd).

## Next
Done: `AGENTS.md`, `docs/agents/*`, CI workflows, Linear labels, projects M0-M7 and 63 tickets (FAR-5 to FAR-67, with size labels, priorities and blockers), repo settings (auto-merge, squash only, ruleset on `main`).

To do, in order:
1. FAR-5: put the docs, workflows and `.gitignore` into `main` through a PR from `far-5-add-factory-docs-and-ci`.
2. Dry-run one ticket by hand (FAR-6 is first in the queue), then schedule the author alone (see `docs/agents/autonomous-worker.md`).
