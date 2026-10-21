# Validation record

This record separates portable checks, iOS source/project checks, and real camera validation. It must be updated with actual results rather than inferred from the presence of tests or workflow files.

## Current implementation checks

Recorded on 2026-10-21 (UTC).

| Check | Result | Scope |
| --- | --- | --- |
| Portable Swift core build and XCTest suite | Passed: 45 XCTest cases | Linux, official Swift 6.1.3 container; local helper and GitHub CI passed, including 11 new diffusion-state tests |
| iOS Swift syntax parse | Passed | All app, renderer-test and UI-test Swift sources; syntax alone does not establish an Apple build |
| Project YAML, Info.plist, asset JSON, shell syntax | Passed | Structural/local checks only |
| iOS simulator build and Core Image tests | Passed: 16 tests, 0 failures | macOS CI generated the Xcode project, compiled the app and executed 9 new diffusion tests plus 7 existing renderer tests |
| Simulator diffusion UI tests | Passed: 3 tests, 0 failures | Real app controls; effect switching, remembered strength/color, LUT/menu changes, fresh-launch reset and large text |
| Camera, Photos permissions, preview/capture consistency and performance | Not run | Requires physical iPhone and representative scenes |

The first core test run caught incorrect handling of CRLF line endings in `.cube` input. The parser was corrected to recognize newline characters before rerunning the suite.

Pre-diffusion Apple validation is recorded in [GitHub Actions run 39642652108](https://github.com/yangzhloop/film-lut-camera/actions/runs/39642652108), against application/workflow commit `a714744`. The iOS job reported 7 executed tests with zero failures in approximately 8 seconds. The earlier native build identified a missing `AppIcon` catalog; a development icon was added before the successful run. This validates the app build and renderer integration, not interactive UI behavior or a physical camera.

## F10 diffusion implementation

[GitHub Actions run 39650156405](https://github.com/yangzhloop/film-lut-camera/actions/runs/39650156405) passed against application/workflow commit `3497cf8`. The Apple job reported **16 renderer tests, 0 failures** (9 diffusion and 7 existing tests) and **3 UI tests, 0 failures**. Renderer tests took about 17 seconds; UI tests took about 99 seconds. Project generation, app/test compilation, simulator execution and result upload succeeded. The same run's portable-core job passed. Screenshots from the UI flows are retained in the uploaded `ios-test-results` XCTest result bundle.

The [Filters tray](planning/ui-ux.md) and [F10 feature scope](planning/feature-specification.md#f10--diffusion-filters-and-halation) are implemented in source, following the [implementation plan](planning/diffusion-implementation.md). HDF starts at 35% with Neutral glow when first selected; Black Mist starts at 20%. These are development tuning candidates, not calibrated optical strengths.

| Check | Current result | Evidence and remaining limits |
| --- | --- | --- |
| Effect model and session transitions | Passed: 11 new core tests | One active effect, independent strengths, fresh-session Off, remembered settings and immutable snapshots |
| Overlay interaction | Passed: 3 simulator UI tests | Effect switching, strength/color retention, LUT/menu independence, fresh-launch Off and shutter position at default/large text |
| Off and 0% bypass | Passed in Apple pixel tests | Pixel comparison against the existing LUT-only path; Original/identity still permits diffusion |
| HDF and Black Mist rendering | Passed in Apple pixel tests | Synthetic light fixtures cover colored/neutral halo locality, dark regions, saturated lights and alpha |
| Resolution and capture integration | Passed in Apple integration tests | Proportional halo dimensions across the 640-pixel spatial layer cap, frozen capture recipe and clean-original exclusion |
| Custom color and accessibility | Manual review pending | Native opaque ColorPicker is implemented with live updates; opening/dismissal, VoiceOver, Reduce Motion and small-device reachability need interactive review |
| Physical-device quality and performance | Not run | Representative lighting, skin tones and highlights; camera/lens switching; latency, memory and thermal measurements |

Synthetic pixel and simulator interaction tests do not establish photographic quality or live-camera performance. The base photo remains full resolution; only blurred spatial layers are capped at 640 pixels on the longest edge. Preview and capture use the same proportional radii and render recipe.

## Required Apple/device checks

- Exercise the remaining interactive UI flows on Simulator and physical iPhones; the three automated diffusion flows above cover only their stated scope.
- Verify denied/restricted camera states, interrupted capture, background/foreground recovery, and simulator-without-camera behavior.
- Check available lenses, front/rear switching, flash support, focus coordinates, and exposure/WB bounds on each supported device.
- Compare Original, identity, and graded previews with the captured JPEG under daylight, tungsten, mixed lighting, and high contrast.
- Verify portrait orientation and front-camera mirroring; check full-resolution photo dimensions on camera/lens changes.
- Exercise Photos allowed/denied, save errors, clean-original on/off, review and sharing.
- Import valid and invalid LUTs, reach the five-slot limit, replace at capacity, cancel edits, delete the selected look, and relaunch.
- Check keyboard handling, touch targets, large text, VoiceOver and label contrast.
- Measure actual preview delivery, capture latency, memory and thermal behavior before setting release performance guarantees.

## Release content still required

Built-in look tuning/approval, final legal and publisher information, feedback destination if one is desired, app icon and store assets, signing identity, supported-device matrix, and distribution approval are separate release requirements.
