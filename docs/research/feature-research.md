# Feature research: WorkOutDoors and Apple's Workout app

Gathered 2026-11-17 by a research subagent. **Caveat:** Reddit and the developer's site could not be fetched. Nothing here is quoted from r/AppleWatch, r/running or r/hiking. It rests on the App Store listing and reviews, three independent reviews, an Apple Community thread and forum snippets. The ranking is a judgment, not a count of Reddit mentions. To validate priorities 1-3, search Reddit directly for pace-plan and heart-rate-zone requests.

## Why WorkOutDoors is loved (ranked)
1. Customisation: 800+ data fields, per-profile and per-interval layouts.
2. Offline maps on the wrist: OpenStreetMap vector tiles stored on the watch, breadcrumb trail, compass modes, contours.
3. GPX/TCX/FIT import and route following: off-route alerts, turn-by-turn when the file has waypoints, bend detection otherwise, elevation profiles, climb detection. Apple's Workout app has no GPX import.
4. Intervals and alerts, built on the iPhone, with heart-rate-zone targets.
5. One-off price (listing shows $8.99), no subscription.
6. Export (FIT/TCX/GPX) and automatic Strava upload.
7. Responsive developer.
8. Battery about equal to Apple's app (one data point).

## Complaints
- Dated, non-native look.
- Overwhelming options, learning curve.
- Setup friction: no route creation in the app, manual Garmin Connect export.
- Scattered regressions (heart rate on iOS 26, lost history, offline maps in 2024). Anecdotal.
- English only (weak source).
- Missing Garmin-style analytics (race predictor, recovery, VO2 max).

## Apple's running features
Has: Pacer, Race Route (race your previous attempts), Track Detection, custom workouts (iPhone Fitness app or watch in watchOS 26) with work/recovery steps, repeats, warm-up/cool-down, targets on pace, heart rate, cadence, power; alerts; Workout Buddy (English-only AI voice coach that needs an Apple Intelligence iPhone nearby, so it does not work phone-free).

Gaps: no GPX import or route following; no real maps or turn-by-turn during a run; Pacer is a flat target (no grade adjustment, per-split plan or finish projection, unlike Garmin PacePro); workout builder does not work with Bluetooth heart rate straps; no training plans (Runna and others fill this).

## Candidate features after v1
| Priority | Feature | Evidence | Effort |
|---|---|---|---|
| 1 | Race pace targets with per-split, grade-adjusted plans and live finish-time projection | some | medium-large |
| 2 | Heart-rate-zone targets with haptic/audio cues for leaving the zone, zone-based intervals | some | small-medium |
| 3 | Structured workouts and programs (warm-up/cool-down, pace/HR targets) built on the iPhone | some | large |
| 4 | Off-route alerts and turn cues from GPX | strong | medium (in v1) |
| 5 | Offline map tile download | strong | large (in v1) |
| 6 | Strava upload and FIT/GPX export | some | medium |
| 7 | Simple native-feeling UI and onboarding with sensible defaults | some | small-medium |
| Later | Recovery, VO2 max, race predictor | weak | large |

Priorities 4 and 5 are WorkOutDoors' core draw, so the case for building them rests on doing it more simply and with a better UI.

## Sources
- [WorkOutDoors App Store listing](https://apps.apple.com/us/app/workoutdoors/id1241909999)
- [Full Potential review](https://www.fullpotential.co.uk/post/apple-watch-app-review-workoutdoors)
- [Mushing.com review](https://mushing.com/gear/workoutdoors-review/)
- [Marlvel.ai review analysis](https://marlvel.ai/apps/workoutdoors) (AI-generated, weak)
- [Apple Community: GPX in Workout app](https://discussions.apple.com/thread/256190635)
- [DC Rainmaker: workout builder](https://www.dcrainmaker.com/2025/09/apple-watch-workout-builder-ios26-watchos26.html)
- [5krunner: watchOS 26 first run](https://the5krunner.com/2025/06/10/watch-os26-first-run-i-went-for-my-first-run-on-the-new-apple-os-some-pictures/)
- [5krunner: offline maps (vendor-written)](https://the5krunner.com/2026/06/11/apple-watch-offline-maps/)
- [Apple: outdoor run guide](https://support.apple.com/en-sa/guide/watch/apdf2260a232/26/watchos/26)
- [Workout Buddy coverage (Tom's Guide)](https://www.tomsguide.com/wellness/fitness/i-ran-15-miles-with-the-apple-watchs-new-workout-buddy-heres-my-verdict)
- [Garmin PacePro (5krunner)](https://the5krunner.com/garmin-features/performance/pacepro/)
