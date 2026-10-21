# Lutli

**lutli** is an iOS-first camera app for live film-inspired LUT looks, adjustable white balance/exposure, and a small collection of custom looks with editable two-color labels.

The repository contains the initial native implementation in **SwiftUI + AVFoundation + Core Image**, a portable Swift core, tests, and the detailed product/development plan. Android is a later milestone. The built-in color grades are original starter LUTs awaiting photographic tuning.

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

The helper uses a local Swift compiler when present, otherwise the official `swift:6.1.3-noble` Docker image. Docker may need to download that image on its first run. Tests cover LUT parsing, channel ordering, intensity, labels, library limits, persistence, replacement/deletion and failed writes.

Apple-framework tests, after generating the project:

```bash
xcrun simctl list devices available
xcodebuild test \
  -project ios/Lutli.xcodeproj \
  -scheme Lutli \
  -destination 'platform=iOS Simulator,id=<available-simulator-UUID>' \
  CODE_SIGNING_ALLOWED=NO
```

`ios/LutliTests` covers Core Image identity/channel behavior, frozen capture recipes, embedded color profiles, and image orientation. `.github/workflows/ci.yml` defines separate portable-core and macOS/iOS jobs. A configured workflow is not evidence of a passing run; see the [validation record](docs/validation.md) for what has actually been checked.

## Included workflows

- Live LUT preview, still capture, supported camera/lens switching, focus, flash, exposure compensation and white balance.
- Original plus six generated looks, per-look intensity, and a fixed library button before the horizontally scrolling filter labels.
- Five custom LUT slots with import, replace, delete, and independent top/bottom label text and colors.
- Capture review/share, optional clean original, grid/timer/haptics preferences and remembered look selection.
- App menu with settings, feedback composition, About, and clearly identified development legal copy.

Imports support standard SDR sRGB 3D `.cube` files with sizes **17 or 33**, normalized domains and samples, up to **8 MiB**. Arbitrary Log/HDR LUTs are not automatically made compatible. Numbers printed on filter labels are decorative text, not camera ISO.

## Approved next feature: diffusion controls

The [latest UI/UX concept](docs/planning/ui-ux.md#latest-approved-shooting-concept) adds **Filters** beside EV and WB. A horizontal chooser offers Off, HDF and Black Mist. HDF expands to strength and glow-color controls; Black Mist offers neutral diffusion strength. One effect combines with the selected LUT, with separate Look intensity and Filter strength controls.

This design and [F10 feature specification](docs/planning/feature-specification.md#f10--diffusion-filters-and-halation) are approved; the tray and diffusion rendering are **not implemented yet**. The existing 34 core and 7 iOS renderer tests validate the current LUT implementation. New diffusion checks are planned in the [roadmap](docs/planning/roadmap.md).

## Product and engineering documents

- [Product plan](docs/planning/product-plan.md)
- [Detailed feature specification and acceptance checks](docs/planning/feature-specification.md)
- [UI/navigation and reviewed mockups](docs/planning/ui-ux.md)
- [Development roadmap](docs/planning/roadmap.md)
- [Native architecture](docs/architecture/native-ios.md)
- [Validation record and remaining device checks](docs/validation.md)

This is an initial implementation, not a release-ready camera. Physical-device camera/rendering checks, photographic tuning, accessibility review, final legal/publisher details, app icon/release assets, and distribution configuration remain required before release. The latest shooting concept and implemented app use Lutli; the retained older menu/library and label-editor artwork still shows its former STILL wordmark.
