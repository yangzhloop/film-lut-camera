# Native iOS architecture

Status: selected for the first implementation. The user chose native iOS after comparing it with a shared Flutter UI. Android remains a later platform implementation. The F10 diffusion extension described below is approved planning scope; the current renderer still implements the LUT-only baseline.

## Components

| Component | Responsibility | Validation |
| --- | --- | --- |
| `Sources/LutliCore` | Bounded .cube parsing, starter LUT generation, labels/palette, five-slot persistent library | Swift package tests on Linux/macOS |
| `ios/Lutli/Camera` | AVFoundation lifecycle and controls, Core Image rendering, still capture, Photos saving | Apple-framework tests and physical iPhone checks |
| `ios/Lutli/App` | Main-actor application state, look selection, preferences, timer and library coordination | Apple-platform integration/UI checks |
| `ios/Lutli/Views` | SwiftUI camera, looks collection, editor, controls, menu and review | Simulator/device layout and accessibility checks |
| `ios/project.yml` | Reproducible Xcode project definition | XcodeGen followed by Xcode build/tests |

## Camera and rendering flow

The following diagram describes the current implementation, before F10 diffusion processing:

```mermaid
flowchart LR
    Camera[AVCaptureSession] --> Frames[Video frame queue]
    Frames --> Preview[Shared SDR sRGB LUT renderer]
    Preview --> UI[SwiftUI preview]
    Shutter[Shutter action] --> Recipe[Immutable look snapshot]
    Camera --> Photo[AVCapturePhotoOutput]
    Photo --> Capture[Full-resolution render]
    Recipe --> Capture
    Capture --> Review[Last-shot review and share]
    Capture --> Photos[Photos add-only save]
```

Session configuration and camera-device mutations are serialized on a dedicated queue. Preview rendering uses a separate queue, discards late frames, and bounds UI frame delivery. The initial preview is limited to a 1280-pixel long edge and 15 delivered frames per second; its practical latency, quality, and energy use require measurement on real devices. Captured photographs use the full configured still dimensions, not the preview buffer.

One reusable Core Image context converts into the SDR sRGB processing/output contract. Filter instances are local to rendering operations. Preserve an embedded source image profile so Display P3 data is converted rather than reinterpreted as sRGB. The selected LUT and intensity are frozen at shutter time; changing the selected look while a photo is processing must not change that photo.

The first implementation is portrait-only. Preview framing uses aspect fit and maps touch coordinates through the displayed image rectangle. Portrait rotation, front-camera mirroring and output orientation need physical-device verification.

## Planned F10 extension: diffusion and colored halation

Status: not implemented. See the [feature specification](../planning/feature-specification.md) and [M4a roadmap](../planning/roadmap.md) for behavior and evidence gates.

HDF and Black Mist require spatial processing that spreads light across neighboring pixels. Add this as a separate render stage; a LUT alone cannot encode it. Continue to use the existing `.cube` import contract and keep imported LUT files unchanged.

The planned render recipe contains the selected LUT and its look intensity, one effect type (Off/HDF/Black Mist), a separate effect strength, HDF glow color and all parameters required for that capture. Snapshot the entire recipe at the shutter action. Later changes to effect, strength or glow color must not alter an in-flight photograph.

Off or 0% effect strength must bypass the spatial stage and preserve the current LUT-only result. Original or 0% look intensity bypasses the creative LUT while leaving an active diffusion effect in place. A requested clean-original JPEG is generated before both creative stages, retaining the camera's exposure/WB processing; it is still a processed JPEG, not RAW.

HDF combines highlight diffusion with an optional colored halation treatment, localized to highlights and their halos. Black Mist uses neutral diffusion with controlled contrast softening and exposes strength only. The final highlight extraction, threshold/rolloff, compositing method, glow-color handling and processing order relative to LUT grading must be selected through reference-image tests and photographic review. The UI illustration establishes interaction, not calibrated algorithms or optical equivalence.

Use one explicit color and processing contract for preview and capture. Normalize spatial radii to image dimensions so preview downscaling does not change the apparent glow size in full-resolution output. Preserve output extent, orientation and edge behavior. Validate gamut/clipping, dark regions and skin tones in addition to bright point-light fixtures. Reuse rendering resources, keep work off the main actor and retain bounded frame delivery; the current preview limit does not establish acceptable performance with diffusion enabled.

The application state will own session-wide effect settings independently of each look. They survive LUT/lens changes, tray dismissal, Off/reselection and background/foreground within the same app session. Each fresh launch starts with Off; the remember-last-look preference continues to control only the look. Keep per-effect strength and HDF color in session memory until a separate persistence feature is specified.

The SwiftUI tray overlays the preview's lower edge and expands upward from the Filters shortcut beside EV/WB. The preview geometry, permanent toolbar, LUT strip and shutter remain fixed. Overlay controls must intercept their own touches so adjusting strength does not trigger focus behind the tray. Avoid overlapping lens controls; the approved concept hides them while the tray is open.

Required new verification includes state-transition tests, Off/0% pixel equivalence, localized glow/color fixtures, proportional preview/capture radii, frozen full-recipe capture and clean-original exclusion. Device profiling and interactive accessibility checks remain required. The existing 34 core and 7 renderer tests do not exercise this extension.

## LUT contract

- UTF-8 `.cube`, maximum 8 MiB, 3D sizes 17 or 33.
- Red changes fastest, then green, then blue; Core Image receives packed RGBA Float32 samples with alpha 1.
- Inputs and output samples are normalized to 0–1. Non-default domains, 1D LUTs, unknown directives and invalid/nonfinite samples produce explicit errors.
- Intensity blends each cube sample with its identity-grid sample. This avoids a separate preview-only grading path.
- Original and the six built-in looks are deterministic generated LUTs. They are original starter grades, not measurements or licensed recreations of named film stocks.

## Persistence and failures

The `LookLibrary` actor owns custom metadata and LUT files. Its JSON index is versioned. Files use generated UUID names, never user-supplied filenames. New imports write their data first, then atomically commit the metadata index; an index failure does not consume a slot. Replacing a LUT atomically replaces the payload while keeping its identity. Deleting commits the index before best-effort cleanup, so a cleanup failure can leave an unreferenced file but not an index pointing at a removed file.

Unreadable/corrupt stored libraries are preserved and reported. Built-in looks remain usable; the app does not silently reset or delete the user's files. Preferences and built-in intensities use UserDefaults. Imported file access is security-scoped and data is copied into application-managed storage on save.

Camera permission is requested for capture; Photos add-only permission is requested when saving. The most recent rendered capture remains available to share even if Photos access is denied or saving fails. There is no account, remote backend, or automatic media upload.

## Platform and release boundaries

Use the local Swift package for logic that can be validated without Apple SDKs. Linux syntax parsing does not establish SwiftUI/AVFoundation type correctness. Core Image pixel tests run in the iOS test target; camera, Photos, orientation, performance, and accessibility need Apple-platform execution.

The checked-in XcodeGen specification generates the project on macOS. Bundle identifier and signing team must be configured by the application owner before device distribution. The About/legal content is development copy; final publisher, feedback and policy details, app icon/release assets, and signing/distribution remain release gates.

For Android, reuse the product contract, label palette, reference fixtures, and compatible LUT assets. SwiftUI and AVFoundation are intentionally native to iOS and will require platform-specific equivalents.
