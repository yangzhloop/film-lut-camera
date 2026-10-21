# Development roadmap

This roadmap implements the [product plan](product-plan.md) and [feature specification](feature-specification.md). The initial native iOS workflow is implemented in SwiftUI, builds on the Apple toolchain, and passes the portable-core and renderer integration tests. A milestone becomes validated only when its full exit evidence exists; interactive UI and physical-device checks remain separate requirements. There are no promised delivery dates.

The approved [diffusion-control design](ui-ux.md) adds F10 as the next implementation milestone, M4a. HDF, colored halation and Black Mist are specified but are not implemented or covered by the existing passing tests.

## Milestone overview

| Milestone | Scope | Dependency | Current evidence |
| --- | --- | --- | --- |
| M0 — Decisions and contracts | Framework, supported platform baseline, LUT contract, data model, build strategy | Product/UI baseline | Architecture recorded; build/test path documented |
| M1 — Domain core | LUT parser, bundled looks, label validation, persistent collection, settings | M0 | Implemented; 34 core XCTest cases passed on Linux |
| M2 — App interface | Camera layout, menu, library, import/editor, state feedback, accessibility | M0; M1 models | Implemented and compiled on Apple CI; interactive UI checks pending |
| M3 — Camera and rendering | Live camera, LUT preview, exposure/WB, still capture and processing | M1; camera UI | Implemented; 7 Apple renderer tests passed; physical camera checks pending |
| M4 — End-to-end behavior | Saving/review, preferences, import/replace/delete, relaunch and error paths | M1–M3 | Source integrated; native end-to-end checks pending |
| M4a — Diffusion controls | Filters tray, HDF strength/glow color, Black Mist strength, preview/capture integration | M1–M4 baseline | UI concept and feature scope approved; implementation and validation pending |
| M5 — Device and release validation | Apple builds, camera matrix, photographic quality, accessibility, release content | M4 and M4a | Not validated; release gates remain |
| M6 — Android and later features | Android camera parity and separately approved additions | Stable iOS contracts | Deferred |

## M0 — Implementation decisions and contracts

Deliverables:

- Use the user-selected native iOS approach: SwiftUI for UI, AVFoundation for camera control, and Core Image for LUT rendering. Keep domain logic in the portable `LutliCore` Swift package.
- Start at iOS 17. Define module boundaries and a reproducible project/build path using an XcodeGen `project.yml`, documented macOS build commands, and macOS CI.
- Adopt the first-version SDR sRGB `.cube` contract, five-slot limit, label rules, and stable look identifiers.
- Separate pure domain logic from camera, graphics, Photos, and UI dependencies so it can be tested independently.
- Define how platform capability and error states reach the interface.

Exit evidence: architecture decision and documented build/test commands. If Apple tools are unavailable in the active machine, record that constraint and provide an Apple-platform validation path instead of claiming a successful iOS build.

## M1 — Implement the domain core

Feature coverage: F02, F05–F07, and persistent portions of F09.

Tasks:

1. Implement strict `.cube` parsing with bounded input and helpful errors; preserve the red-fastest data contract.
2. Provide Original and six original developer looks, with stable IDs and deterministic procedural starter LUTs. Treat photographic tuning as a later release gate, not as proven film-stock accuracy.
3. Model labels, predefined colors, readable text colors, intensity, user preferences, and custom-look records.
4. Implement import validation, save/edit/replace/delete rules, the five-slot cap, selected-look fallback, and atomic local persistence.
5. Add focused tests for data invariants, parser failures, LUT reference values, persistence/recovery, and failure cases that could lose a user's look.

Exit evidence: real tests execute and pass for valid/invalid LUTs, label rules, library capacity, round trips, replacement safety, and selected-look fallback. Test counts and the actual platform/toolchain are recorded in the implementation handoff.

## M2 — Implement the application interface

Feature coverage: F07–F09 and the UI surfaces for F01–F06.

Tasks:

1. Build the approved camera hierarchy with the `lutli` wordmark, current-value EV/WB shortcuts, fixed leading library button, scrolling labels, intensity, and shutter.
2. Build App menu, Your looks tabs, custom-look actions, import route, and live label editor.
3. Add the WB/EV panels, capture review, preference screens, and accurate loading/error/empty states.
4. Connect real domain data. A development preview may use clearly identified fixture imagery, but it must not masquerade as a functioning camera.
5. Review keyboard behavior, safe areas, touch targets, contrast, text scaling, and screen-reader labels.

Exit evidence: the required navigation paths and edit/cancel/save flows work in an interactive Apple-platform run. Static image comparison alone does not validate interaction. Record any UI tests that were not executable in the active environment.

## M3 — Integrate camera and rendering

Feature coverage: F01–F04.

Tasks:

1. Implement permission and camera-session lifecycle states, camera/lens switching, supported focus/flash, interruption, and background recovery.
2. Configure a live preview with explicit SDR color handling, consistent orientation, and reusable rendering resources.
3. Apply the selected LUT and intensity to live frames; avoid unbounded frame queues.
4. Implement automatic exposure compensation and supported Auto/Lock/Manual WB, clamping to hardware capabilities.
5. Capture a still with an immutable snapshot of the selected look/intensity and render its filtered output plus optional clean copy.

Exit evidence: build on the supported Apple toolchain and run on physical iPhones. Demonstrate Original, identity and creative LUT output, control transitions, capture orientation, and preview/output appearance. Profile responsiveness and thermal behavior; establish actual performance thresholds from the supported-device baseline.

## M4 — Complete end-to-end workflows

Feature coverage: F01–F09 together.

Tasks:

- Import a valid LUT, customize its identity, select it, change intensity/WB/EV, capture, save/share, relaunch, and reuse it.
- Exercise capacity reached, canceled import, invalid LUT, replacement failure, deletion of the selected look, and unavailable persisted data.
- Verify Photos add permission, failed saves, storage problems, and clean-copy behavior without false success messages.
- Connect grid/timer/haptics/remember-last-look preferences and cancel timed captures when the session can no longer capture safely.
- Implement a user-initiated feedback composition route and About/legal screens with truthful development status where production details are missing.

Exit evidence: documented end-to-end results, including failures and recovery. All first-version acceptance checks are mapped to unit, integration, UI, or device checks; unrun categories stay visibly unrun.

## M4a — Implement diffusion controls

Feature coverage: F10, extending the F02/F04 rendering contract and the shooting interface. Status: approved design; no diffusion implementation or test evidence yet.

Tasks, in implementation order:

1. Define the effect model and render contract: Off, HDF or Black Mist; independent 0–100% effect strength; HDF glow color; and parameters needed to reproduce the render. Keep **Look intensity** separate from **Filter strength**. Off and 0% bypass only diffusion, while Original and 0% look intensity bypass only the creative LUT.
2. Define session behavior. Start each fresh app launch with Off. Keep the active effect and each effect's settings through LUT/lens changes, closing the tray, temporary Off selection and background/foreground within the same app session. The existing remember-last-look preference must not silently restore diffusion across launches.
3. Build the Filters shortcut beside EV and WB. Reveal the horizontal Off/HDF/Black Mist choices in a tray over the lower preview, then expand the tray upward for effect controls. Keep EV/WB, the LUT strip, look-intensity slider and shutter in place. Add current-effect feedback, accessible control names and a custom glow-color picker.
4. Add a separate spatial processing stage for HDF highlight bloom with optional colored halation, and Black Mist neutral diffusion/contrast softening. Validate the highlight mask, glow tint, processing order relative to the LUT, color-space handling and normalized bloom radius. The concept's percentages are examples, not calibrated optical strengths.
5. Integrate the full immutable recipe at shutter time: LUT/intensity, effect type/strength, glow color and required render parameters. Use the same processing contract for preview and full-resolution photos. The clean-original copy bypasses both the LUT and diffusion.
6. Add meaningful model and image fixtures for bypass, effect switching, session restoration, highlight locality, color behavior, resolution scaling and in-flight capture isolation. Exercise the overlay on compact devices with text scaling and VoiceOver. Measure preview/capture latency, memory and thermal behavior on physical iPhones before tuning release defaults.

Exit evidence:

- Model tests establish independent strengths, one active effect, fresh-launch Off and the specified session transitions.
- Apple pixel tests establish Off/0% equivalence to the existing LUT-only path, localized HDF glow, neutral Black Mist behavior, clean-copy exclusion and a frozen capture recipe. Preview-sized and full-resolution fixtures establish proportional glow dimensions within documented tolerances.
- Simulator/device interaction checks establish horizontal selection, expansion/collapse, custom-color picker dismissal, unobscured shutter access and stable control placement.
- Physical-device comparisons establish the appearance of both effects across representative highlights, skin tones and dark scenes, with measured performance and any limitations recorded in the [validation record](../validation.md).

Existing core and renderer test results do not satisfy these new exit gates. Additional diffusion types, effect stacking and saved effect recipes remain later scope.

## M5 — Release readiness

Tasks:

- Select and test the supported iPhone/iOS matrix, including different camera/lens capabilities.
- Review every built-in look against skin tones, neutral references, highlights/shadows, indoor light, and outdoor scenes.
- Review HDF glow colors and Black Mist with built-in and imported looks, and approve measured effect-strength defaults after M4a validation.
- Measure preview/capture consistency, latency, memory, thermal behavior, and interrupted-session recovery on device.
- Finish accessibility, input validation, permission copy, legal/publisher content, and the real feedback destination.
- Complete signing, app metadata, release assets, distribution, and any store requirements through the appropriate account-controlled workflow.

Exit evidence: release checks completed with owners, tested versions, results, and known limitations. No release-ready claim while required Apple builds/device checks or production content remain unresolved.

## M6 — Later milestones

Android is a separate implementation and device-validation milestone. Reuse product behavior, LUT assets/contract, and portable tests where appropriate, while validating Android camera capabilities, color, permissions, and storage independently.

Video, RAW, manual shutter/ISO, grain, additional diffusion/halation treatments, effect stacking, saved recipes, and editing existing photos require separate scope and performance decisions. The approved HDF/colored-halation and Black Mist subset belongs to M4a; these further additions are not implied by it.

## Validation responsibilities

| Check | Can portable/core tooling establish it? | Additional evidence |
| --- | --- | --- |
| LUT structure, numeric values, labels, capacity, stored metadata | Yes, using actual domain tests | Corrupt-file and failed-write fixtures |
| iOS source/project compiles | No | Xcode build on macOS |
| Interface layout and navigation | Partly through model tests | Simulator/device UI run and accessibility review |
| Camera controls and live LUT rendering | No | Physical iPhone with representative lighting |
| Diffusion state and appearance (F10) | State rules only, once tests are implemented | New Apple pixel tests, interactive overlay checks and physical-device appearance/performance evidence |
| Photos saving, orientation, sharing | No | Apple-platform permission/error-path tests |
| Android readiness | No | Separate Android application build/device validation |

The onboarding environment is Linux with a prepared Android toolchain. Its earlier temporary APK smoke check verified the toolchain, not Lutli or its future Android implementation. Native iOS builds, Apple SDKs, signing, Simulator, and device validation require macOS/Xcode. Record current implementation evidence separately from these environment capabilities.

## Current validation evidence

See [the validation record](../validation.md) for the 34 passing core tests, successful iOS simulator build, 7 passing Apple-framework renderer tests, and remaining interactive/device checks. The initial validation found and corrected a CRLF `.cube` parsing issue and a missing app-icon asset. These results cover the implementation before F10. Next work includes M4a diffusion implementation, interactive UI and real-camera verification, followed by photographic tuning and release preparation.
