# Spike: MapKit offline maps and spoken alerts on the watch

Ticket: FAR-8 (build), FAR-15 (run on the real watch). The `FarsangSpike` target is throwaway and never shipped. It
is watch-only, has its own bundle id, and is not part of the `Farsang` scheme, so it stays out of that scheme's build
and archive. CI builds it with the `FarsangSpike` scheme for the watch simulator.

## Questions

1. Can a third-party watchOS app using MapKit show Apple Maps' offline regions with no phone nearby?
2. Can the watch speak aloud through its own speaker with no headphones?

## What the app does

- Screen 1 (map): full-screen `Map` centered on the user, a button to re-center on the current location, and a label
  showing whether location is available.
- Screen 2 (speech): a button that speaks "In 150 meters, turn right" with `AVSpeechSynthesizer` in a workout-style
  audio session (`.playback`, `.voicePrompt`), and a label showing the active audio route.

Swipe up or down (or turn the Digital Crown) to switch screens.

## Test steps

Needs a real Apple Watch (watchOS 11+) with the app installed from Xcode, and an iPhone paired to it.

### Install

1. Open `Farsang.xcodeproj` (run `xcodegen generate` first), pick the `FarsangSpike` scheme, set your own signing team
   locally (do not commit it), and run it on the paired watch.
2. Open the app once while the phone is nearby and allow location access when asked. Do this somewhere other than the
   test site, so the spike's map never loads tiles for the test viewport while online.

### Offline map (question 1)

1. On the iPhone, open Apple Maps, tap your profile picture, choose Offline Maps, then Download New Map. Download a
   region that covers where you will test, with a clear margin around it.
2. In the same screen, keep "Sync with Apple Watch" switched off for this region until the baseline in step 6 is done.
   If it was on, switch it off now.
3. Check that the region is not already on the watch: it must not be listed under "On This Watch" in the watch's Apple
   Maps offline maps.
4. Go to the test site, which must be inside the region. Do not open `FarsangSpike` or Apple Maps there while online, so
   the test viewport has no cached tiles.
5. Turn on airplane mode on the watch, then switch Wi-Fi off, so it has no network. Move the phone out of Bluetooth
   range (or switch it off).
6. Baseline (before syncing): open `FarsangSpike`, go to screen 1, wait up to a minute for a location fix, tap the
   center button and note the zoom level. Record whether tiles draw. Leave the app.
7. Restore connectivity, switch "Sync with Apple Watch" on for the region and sync it to the watch. Wait until it appears under "On This Watch", not just "On
   Your iPhone". If it never appears there, the run is invalid: record it as inconclusive.
8. Go offline again as in step 5. Open `FarsangSpike`, go to screen 1, wait for a fix, tap the center button and use
   the same viewport and zoom levels as the baseline. Pan and zoom to see whether map tiles draw. Also compare with the
   Apple Maps app on the watch in the same state.
9. Record what you see in the results table. Take a screenshot if you can.

How to read the outcome:

- Tiles draw after syncing but not in the baseline: pass. The synced region is what draws them.
- Tiles draw in the baseline too: cached tiles are not proof. Do not use this run to justify dropping the fallback
  renderer. Redo it at a site whose viewport has never been loaded.
- Tiles do not draw after syncing, although the region is under "On This Watch": check whether the Apple Maps app on the
  watch can draw it offline. If Apple Maps cannot either, the run is inconclusive: do not choose the fallback renderer
  on this result. If Apple Maps can but `FarsangSpike` cannot, MapKit in a third-party app does not use the region.

### Spoken alert (question 2)

1. Make sure no headphones or Bluetooth speakers are connected to the watch or the phone. Turn the watch's silent
   mode off and raise the volume.
2. Open `FarsangSpike`, go to screen 2, and tap Speak.
3. Note whether you hear it from the watch speaker, and what the route label says.
4. Repeat with the phone away, then once with Bluetooth headphones connected, for comparison.

## Results

Fill in during FAR-15. Add watch model, watchOS version and iPhone iOS version.

| Test | Setup | Expected for a pass | Result | Notes |
| --- | --- | --- | --- | --- |
| Map renders offline | Region under "On This Watch", airplane mode, phone away, same viewport and zoom as the baseline | Tiles draw inside the region after syncing but not in the baseline | | |
| Map baseline | Same viewport and zoom, offline, before syncing | Blank (otherwise the run proves nothing) | | |
| Location label | Same | Shows "Location: available" | | |
| Center button | Same | Map recenters on the blue dot | | |
| Map outside region | Same, outside the region | Blank or coarse map (control case) | | |
| Speech, no headphones | Phone away, no headphones | Heard from the watch speaker | | |
| Audio route label | Same | Names the watch speaker | | |
| Speech, headphones | Bluetooth headphones connected | Heard in the headphones | | |

## Decision

- Offline map result: ______
- Speech result: ______
- Consequence for `docs/PLAN.md`: if the map renders offline in a valid run (baseline blank, region under "On This
  Watch"), Apple Maps is the map and M4 and M5 are not needed. If it does not, and Apple Maps can draw the region on
  the watch, the fallback offline renderer is needed. An inconclusive run decides nothing.
