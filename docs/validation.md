# Validation record

This record separates portable checks, iOS source/project checks, and real camera validation. It must be updated with actual results rather than inferred from the presence of tests or workflow files.

## Current implementation checks

Recorded on 2026-10-21 (UTC).

| Check | Result | Scope |
| --- | --- | --- |
| Portable Swift core build and XCTest suite | Passed: 34 XCTest cases | Linux, official Swift 6.1.3 container; local helper and GitHub CI passed |
| iOS Swift syntax parse | Passed | `swiftc -frontend -parse` over all app and integration-test source files; superseded by the successful Apple build below |
| Project YAML, Info.plist, asset JSON, shell syntax | Passed | Structural/local checks only |
| iOS simulator build and Core Image integration tests | Passed: 7 tests, 0 failures | macOS GitHub runner; Xcode project generation, app/test compilation, simulator execution and result upload passed |
| Camera, Photos permissions, preview/capture consistency and performance | Not run | Requires physical iPhone and representative scenes |

The first core test run caught incorrect handling of CRLF line endings in `.cube` input. The parser was corrected to recognize newline characters before rerunning the suite.

Apple validation is recorded in [GitHub Actions run 39642652108](https://github.com/yangzhloop/film-lut-camera/actions/runs/39642652108), against application/workflow commit `a714744`. The iOS job reported 7 executed tests with zero failures in approximately 8 seconds. The earlier native build identified a missing `AppIcon` catalog; a development icon was added before the successful run. This validates the app build and renderer integration, not interactive UI behavior or a physical camera.

## Required Apple/device checks

- Exercise the complete interactive UI flows on Simulator and physical iPhones.
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
