# Development roadmap

This roadmap implements the [product plan](product-plan.md) and [feature specification](feature-specification.md). The native iOS workflow is implemented in SwiftUI. The pre-F10 baseline passed its Apple build and renderer tests; the expanded diffusion implementation has separate verification gates below. A milestone becomes validated only when its full exit evidence exists, including the relevant interactive UI and physical-device checks. There are no promised delivery dates.

The approved [diffusion-control design](ui-ux.md) is now implemented as M4a: session state, HDF/Black Mist rendering, the Filters tray and capture integration. The [implementation plan](diffusion-implementation.md) records the work and verification scope. All 45 portable core tests pass; native diffusion renderer/UI checks are pending CI, and physical-device tuning remains open.

## Milestone overview

| Milestone | Scope | Dependency | Current evidence |
| --- | --- | --- | --- |
| M0 — Decisions and contracts | Framework, supported platform baseline, LUT contract, data model, build strategy | Product/UI baseline | Architecture recorded; build/test path documented |
| M1 — Domain core | LUT parser, bundled looks, label validation, persistent collection, settings | M0 | Implemented; current suite has 45 passing core XCTest cases, including diffusion state |
| M2 — App interface | Camera layout, menu, library, import/editor, state feedback, accessibility | M0; M1 models | Baseline implemented and compiled on Apple CI; interactive UI checks pending; F10 extension tracked in M4a |
| M3 — Camera and rendering | Live camera, LUT preview, exposure/WB, still capture and processing | M1; camera UI | Baseline implemented; 7 pre-F10 Apple renderer tests passed; physical camera checks pending |
| M4 — End-to-end behavior | Saving/review, preferences, import/replace/delete, relaunch and error paths | M1–M3 | Source integrated; native end-to-end checks pending |
| M4a — Diffusion controls | Filters tray, HDF strength/glow color, Black Mist strength, preview/capture integration | M1–M4 baseline | Source implemented; core tests passed; native renderer/UI CI and device validation pending |
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

Feature coverage: F10, extending the F02/F04 rendering contract and the shooting interface. Status: source implemented, portable state tests passed; Apple-platform and device validation remain separate gates. See the [diffusion implementation plan](diffusion-implementation.md).

Implemented:

1. `DiffusionState` and immutable `DiffusionSettings` represent Off, HDF or Black Mist, independent remembered strengths and named/custom HDF glow colors. **Look intensity** and **Filter strength** remain separate. Off and 0% bypass diffusion; Original and 0% look intensity bypass only the creative LUT.
2. Effect settings live in app-session memory. A fresh launch starts with Off. LUT/lens changes, tray dismissal, Off/reselection and background/foreground retain the current session's settings. Remember-last-look does not restore diffusion across launches. HDF 35% with Neutral glow and Black Mist 20% are provisional development values awaiting photographic tuning.
3. The Filters shortcut sits beside EV/WB. Its overlay has horizontal effect choices, a live strength slider and HDF presets/custom color. It expands upward without moving the preview geometry, toolbar, look strip or shutter. The controls include selected-state feedback, accessibility names, bounded scrolling and Reduce Motion handling.
4. The spatial renderer applies the LUT first, extracts a highlight mask from the ungraded source's peak RGB component, then composites neutral or tinted glow over the graded base. Only soft-light/softening layers are reduced to a maximum 640-pixel long edge; the base photo remains full resolution. Spatial radii are proportional to image dimensions.
5. The locked renderer recipe snapshots the blended LUT and diffusion settings together at shutter time. Updating the LUT preserves diffusion, and updating diffusion preserves the LUT. Preview and still rendering share this path; the clean-original JPEG bypasses both creative stages.
6. New core, Apple pixel and simulator UI tests cover the feature's intended invariants and interactions. The portable suite has executed successfully; native tests are awaiting CI results. Test presence alone does not validate the rendered appearance or interface.

Exit evidence:

- Model tests establish independent strengths, one active effect, fresh-launch Off and the specified session transitions.
- Apple pixel tests establish Off/0% equivalence to the existing LUT-only path, localized HDF glow, neutral Black Mist behavior, clean-copy exclusion and a frozen capture recipe. Preview-sized and full-resolution fixtures establish proportional glow dimensions within documented tolerances.
- Simulator/device interaction checks establish horizontal selection, expansion/collapse, custom-color picker dismissal, unobscured shutter access and stable control placement.
- Physical-device comparisons establish the appearance of both effects across representative highlights, skin tones and dark scenes, with measured performance and any limitations recorded in the [validation record](../validation.md).

The 45 passing core tests provide state/model evidence. The earlier seven Apple renderer tests covered the pre-diffusion baseline and do not establish F10 rendering behavior. Native F10 CI, physical-camera comparisons, VoiceOver review and performance/thermal measurements remain pending. Additional diffusion types, effect stacking and saved effect recipes remain later scope.

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
| Diffusion state and appearance (F10) | State rules are covered by the passing portable suite | Native pixel/UI CI pending; physical-device appearance, VoiceOver and performance evidence still required |
| Photos saving, orientation, sharing | No | Apple-platform permission/error-path tests |
| Android readiness | No | Separate Android application build/device validation |

The onboarding environment is Linux with a prepared Android toolchain. Its earlier temporary APK smoke check verified the toolchain, not Lutli or its future Android implementation. Native iOS builds, Apple SDKs, signing, Simulator, and device validation require macOS/Xcode. Record current implementation evidence separately from these environment capabilities.

## Current validation evidence

See [the validation record](../validation.md) for actual execution evidence. The current portable suite passes all 45 tests, including diffusion state. The earlier successful iOS build and seven Apple renderer tests establish the pre-F10 baseline; the expanded native renderer/UI suite is pending CI. The remaining work is Apple validation, interactive and real-camera verification, photographic tuning, VoiceOver review, performance measurements and release preparation.
