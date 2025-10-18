# GeoSentinel Pro (SwiftUI, iOS 16+)

A production-ish geofencing sample for **MDI1 111‑C1 — Assignment 2**.

This repo contains all source files you need. To run:
1) In Xcode: **File → New → Project… → iOS App (SwiftUI)** named `GeoSentinelPro`.
2) Close Xcode. Replace the auto-generated folder's contents with the files in this zip (or copy the `GeoSentinelPro` folder into your project).
3) Reopen the project.
4) **Signing & Capabilities**:
   - Add **Background Modes → Location updates**.
   - Add **Location Updates** capability if not present.
   - Add **Push/Notifications** (Local notifications work without Push entitlement, but enable the "Background modes → Remote notifications" if you plan to extend).
5) **Info.plist**: add the following keys:
   - `NSLocationWhenInUseUsageDescription` = "GeoSentinel Pro needs your location to monitor your geofences while using the app."
   - `NSLocationAlwaysAndWhenInUseUsageDescription` = "Always access lets GeoSentinel Pro confirm enter/exit events in the background."
   - `NSLocationTemporaryUsageDescriptionDictionary` (optional for precise upgrades per purpose string key).
   - `UIApplicationSceneManifest` should be present by default.
6) Run on a physical device if possible. Region monitoring is limited/simulated on Simulator.

## What’s implemented
- Multiple **CLCircularRegion** monitoring with safe cap (20).
- **Dwell** (confirm enter after N seconds) & **Exit debounce**.
- **Battery modes**: High Fidelity vs Saver (significant-change + visits).
- **Actionable notifications** with SNOOZE 15m and DONE.
- **Persistence** (UserDefaults) for regions, settings, and last-known states.
- **Debug console** with raw/confirmed events and reasons.
- **Map editor** to create/edit regions with radius slider.
- **Auth flow**: When-In-Use → Always upgrade prompt, Precise Location nudge.

## Files
- `GeoSentinelProApp.swift` – app entry, notification delegate wiring.
- `Models/*.swift` – region/settings/state models.
- `Services/LocationService.swift` – Core Location glue & delegates.
- `Services/NotificationService.swift` – local notification categories & delivery.
- `Utilities/Persistence.swift` – lightweight persistence.
- `ViewModel/GeoVM.swift` – state machine, dwell/debounce, scheduling, logs.
- `Views/*.swift` – SwiftUI UI (List, Map Editor, Debug Console, Settings).

## Notes
- Default dwell: 30s, exit debounce: 20s. Tweak in **Settings**.
- If you exceed 20 regions, the VM prioritizes nearest enabled regions to the user.
- **Visits** and **Significant Change** are used in Saver mode to reconcile state and recenter fences as you move far from home base.

## Test Plan (quick pointers)
- Toggle **battery mode**; verify significant-change / visits in logs.
- Create a 150–300 m fence; drive/walk across boundary and watch **raw**→**dwell**→**ENTERED**.
- Background app; confirm **ENTERED/EXITED** actionable notifications.
- Try very small radius (< 50 m) to see warning log.
- Toggle enable/disable while "inside" and relaunch app; ensure `requestState(for:)` corrects status.

— Generated for MDI1 111‑C1 by Lumi

---
## Student TODOs (Class Lab)
- Implement dwell/debounce in `GeoVM.handleEnterRaw` and `handleExitRaw`.
- Implement `confirmEnter` and `confirmExit` updates + (optional) notifications.
- Fill in `LocationServiceDelegate` methods in `GeoVM` to forward region events and auth changes.
- Verify logs in **Debug Console** and persistence across relaunch.
