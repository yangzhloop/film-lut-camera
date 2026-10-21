# Lutli

**lutli** is an iOS-first camera app for live film-inspired LUT looks, adjustable white balance/exposure, and a small collection of custom looks with editable two-color labels.

The repository contains the native implementation in **SwiftUI + AVFoundation + Core Image**, including the HDF/Black Mist diffusion extension, a portable Swift core, tests, and the detailed product/development plan. Android is a later milestone. The built-in color grades and diffusion parameters await photographic tuning on physical devices.

## Develop on macOS

Requirements: macOS, **Xcode 16 or newer**, Xcode command-line tools, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The first target is iPhone on iOS 17+, in portrait orientation.

Follow the [macOS setup and testing guide](docs/macos-development.md) for cloning the implementation branch, simulator and iPhone setup, signing, tests, and troubleshooting.

```bash
brew install xcodegen
./scripts/ios-bootstrap.sh
open ios/Lutli.xcodeproj
```

Choose the Lutli scheme. For a physical iPhone, select your signing team and a bundle identifier you control in Xcode. The default `com.lutli.camera` identifier is a development placeholder. Regenerating the project restores settings from `ios/project.yml`, so retain intentional shared changes there.

The simulator can exercise the interface and Core Image tests; real camera behavior requires an iPhone. Camera permission is needed to shoot. Photos add-only permission is requested when saving. No backend or API keys are required.

## Validate

Portable domain tests:

```bash
./scripts/check-core.sh
# Or, with Swift installed:
swift test --parallel --jobs 4
```

The helper uses a local Swift compiler when present, otherwise the official `swift:6.1.3-noble` Docker image. Docker may need to download that image on its first run. Tests cover LUT parsing, channel ordering, intensity, labels, library limits, persistence, replacement/deletion, failed writes, and diffusion settings/session transitions.

Apple-framework tests, after generating the project:

```bash
xcrun simctl list devices available
xcodebuild test \
  -project ios/Lutli.xcodeproj \
  -scheme Lutli \
  -destination 'platform=iOS Simulator,id=<available-simulator-UUID>' \
  CODE_SIGNING_ALLOWED=NO
```

`ios/LutliTests` includes Core Image identity/channel, diffusion, frozen capture recipe, embedded color-profile, and orientation checks. `ios/LutliUITests` includes diffusion-tray interaction checks. `.github/workflows/ci.yml` defines separate portable-core and macOS/iOS jobs. Test source and a configured workflow do not establish a passing run; see the [validation record](docs/validation.md) for actual results.

## Included workflows

- Live LUT preview, still capture, supported camera/lens switching, focus, flash, exposure compensation and white balance.
- Original plus six generated looks, per-look intensity, and a fixed library button before the horizontally scrolling filter labels.
- HDF and Black Mist diffusion with separate effect strength, HDF preset/custom glow colors, and an expanding Filters tray beside EV/WB.
- Five custom LUT slots with import, replace, delete, and independent top/bottom label text and colors.
- Capture review/share, optional clean original, grid/timer/haptics preferences and remembered look selection.
- App menu with settings, feedback composition, About, and clearly identified development legal copy.

Imports support standard SDR sRGB 3D `.cube` files with sizes **17 or 33**, normalized domains and samples, up to **8 MiB**. Arbitrary Log/HDR LUTs are not automatically made compatible. Numbers printed on filter labels are decorative text, not camera ISO.

## Diffusion controls

The [latest UI/UX concept](docs/planning/ui-ux.md#latest-approved-shooting-concept) adds **Filters** beside EV and WB. A horizontal chooser offers Off, HDF and Black Mist. HDF expands to strength and glow-color controls; Black Mist offers neutral diffusion strength. One effect combines with the selected LUT, with separate Look intensity and Filter strength controls.

The [F10 feature specification](docs/planning/feature-specification.md#f10--diffusion-filters-and-halation) now has source implementations for the model, controls and rendering. Each fresh launch starts with diffusion Off. HDF initially uses 35% with Neutral glow and Black Mist uses 20%; these are development tuning values, not calibrated optical-filter equivalents.

Validation passed on commit `3497cf8`: **45 portable tests, 16 iOS renderer tests and 3 simulator UI tests**, with zero failures, plus the Apple build ([CI run](https://github.com/yangzhloop/film-lut-camera/actions/runs/39650156405)). The UI tests cover selected diffusion interactions; they do not establish every app flow. Physical-device appearance/performance, manual custom-color-picker interaction and VoiceOver/accessibility review remain required. See the [diffusion implementation plan](docs/planning/diffusion-implementation.md), [roadmap](docs/planning/roadmap.md) and [validation record](docs/validation.md).

## Product and engineering documents

- [Product plan](docs/planning/product-plan.md)
- [Detailed feature specification and acceptance checks](docs/planning/feature-specification.md)
- [UI/navigation and reviewed mockups](docs/planning/ui-ux.md)
- [Development roadmap](docs/planning/roadmap.md)
- [Diffusion implementation plan](docs/planning/diffusion-implementation.md)
- [Native architecture](docs/architecture/native-ios.md)
- [Validation record and remaining device checks](docs/validation.md)

This is an initial implementation, not a release-ready camera. Physical-device camera/rendering checks, photographic tuning, accessibility review, final legal/publisher details, app icon/release assets, and distribution configuration remain required before release. The latest shooting concept and implemented app use Lutli; the retained older menu/library and label-editor artwork still shows its former STILL wordmark.
