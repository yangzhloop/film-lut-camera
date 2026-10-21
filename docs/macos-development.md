# Run and test Lutli on macOS

This guide takes you from a fresh checkout to running Lutli in an iPhone simulator or on your own iPhone. Lutli uses SwiftUI, AVFoundation and Core Image. No backend or API keys are required.

The simulator supports interface exploration, look management and renderer tests. Live camera capture, lenses, exposure and white balance require a physical iPhone.

## 1. Install the development tools

You need:

- A Mac running a macOS version supported by your chosen Xcode release.
- **Xcode 16 or newer**, installed from the Mac App Store or [Apple Developer](https://developer.apple.com/xcode/).
- An **iOS 17 or newer** simulator runtime. A physical test iPhone must also run iOS 17 or newer, with an iOS version supported by your installed Xcode.
- [Homebrew](https://brew.sh/) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

Open Xcode once, accept its license and finish installing the requested components. In **Xcode → Settings → Components** (called **Platforms** in some versions), install an iOS simulator runtime.

If Homebrew is not installed, follow its official installation instructions, including the printed shell setup steps. Open a new Terminal window afterward, then install XcodeGen:

```bash
brew install xcodegen
```

Check the selected tools:

```bash
xcodebuild -version
swift --version
xcodegen --version
```

If `xcodebuild` reports that the active developer directory is only the standalone command-line tools, select the full Xcode installation:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Adjust that path if you installed Xcode elsewhere. Complete any remaining first-launch setup in Xcode before continuing.

## 2. Get the application code

For a fresh checkout, run:

```bash
git clone --branch planning/lutli https://github.com/yangzhloop/film-lut-camera.git
cd film-lut-camera
```

The implementation is on **`planning/lutli`**. If you already have a checkout, use it instead of cloning into the same directory. Preserve any local changes before switching branches, then update it with:

```bash
git status --short --branch
git fetch origin
git switch planning/lutli
git pull --ff-only origin planning/lutli
```

Run the remaining Terminal commands from the repository root, the directory containing `Package.swift` and `README.md`.

## 3. Generate and open the Xcode project

```bash
./scripts/ios-bootstrap.sh
open ios/Lutli.xcodeproj
```

The bootstrap script uses XcodeGen to generate the project from [`ios/project.yml`](../ios/project.yml). The generated `ios/Lutli.xcodeproj` is intentionally ignored by Git, so it will not be present immediately after cloning.

Open the generated project in Xcode and allow its local `LutliCore` package to resolve. You do not need CocoaPods, a separate package download or Docker for the normal macOS workflow.

## 4. Run in an iPhone simulator

1. In Xcode's top toolbar, choose the **Lutli** scheme.
2. Choose an available **iPhone simulator** as the run destination.
3. Select **Product → Run**, or press **⌘R**.

The first build and simulator startup can take several minutes. Simulator builds do not require a development signing team.

You can explore the app menu, built-in look labels, preferences, and custom look management. A camera-unavailable message is expected when no camera is available; the simulator does not validate the live camera workflow.

## 5. Run on a physical iPhone

1. Connect your iPhone to the Mac by USB, unlock it, and accept **Trust This Computer** if prompted.
2. Open **Xcode → Window → Devices and Simulators** and let Xcode finish pairing and preparing the device.
3. Enable **Settings → Privacy & Security → Developer Mode** on the iPhone if requested. Follow the restart and confirmation prompts. This setting may appear after pairing with Xcode.
4. In **Xcode → Settings → Accounts**, add your Apple account if necessary.
5. In the project navigator, select the project, then **Targets → Lutli → Signing & Capabilities**.
6. Enable **Automatically manage signing**, select your team, and use a unique bundle identifier you control, such as `com.yourname.lutli`. The repository's `com.lutli.camera` identifier is a development placeholder.
7. Select your iPhone as the run destination and press **⌘R**. Follow any device trust or developer-app verification prompts shown by Xcode or iOS.

A personal team can be used for development on your own device, subject to Apple's provisioning limits. TestFlight and App Store distribution require separate release setup.

Allow camera access when Lutli asks. Photos add-only permission is requested when saving a capture. If camera access was previously denied, use Lutli's **Open Settings** action to change the permission.

**Signing changes in the generated project can be reset by regeneration.** Keep intentional shared project settings in `ios/project.yml`; otherwise, reapply your personal signing choices after running the bootstrap script again. Do not commit the generated `.xcodeproj`.

## 6. Run the automated tests

### Portable core tests

In Terminal, from the repository root:

```bash
./scripts/check-core.sh
```

With Xcode configured, the helper uses the Mac's Swift compiler. These tests cover LUT parsing, channel ordering, intensity, label validation, custom-look limits and persistence. The current baseline has **34 core tests**.

### iOS renderer integration tests

In Xcode, select the **Lutli** scheme and an iPhone simulator, then choose **Product → Test**, or press **⌘U**. The current baseline has **7 iOS tests**, covering Core Image rendering, color profiles, capture recipes and image orientation.

To run the same iOS tests from Terminal, first list available simulators:

```bash
xcrun simctl list devices available
```

Replace `<available-simulator-UUID>` below with the UUID of an available iPhone simulator, then run:

```bash
xcodebuild test \
  -project ios/Lutli.xcodeproj \
  -scheme Lutli \
  -destination 'platform=iOS Simulator,id=<available-simulator-UUID>' \
  CODE_SIGNING_ALLOWED=NO
```

`CODE_SIGNING_ALLOWED=NO` is for this simulator command. Physical-device builds need signing.

The Xcode test scheme runs the iOS integration suite; run the core helper separately for the portable suite. See the [validation record](validation.md) for recorded results and the [GitHub Actions workflow](../.github/workflows/ci.yml) for automated checks.

## 7. Try the main workflows on your iPhone

- Choose Original and several built-in labels, then change intensity and compare the live preview with a saved photo.
- Adjust exposure and Auto, Lock or Manual white balance where the camera supports them. Try focus, available lenses, camera switching and flash.
- Open **Your looks** using the smaller leading icon beside the scrolling labels. Import a compatible LUT from Files, edit both label sections and colors, save it, and select it on the camera.
- Open the upper-right app menu. Try grid, timer, remembering the last look and saving a clean original. Capture a photo, check its save status, review it and share it.
- Relaunch the app and confirm that your custom looks and preferences persist. Exercise permission denial and recovery as part of device testing.

Custom imports support UTF-8 3D `.cube` files with sizes **17 or 33**, normalized domains and samples, standard SDR sRGB input/output, and a maximum size of **8 MiB**. There are five custom slots. The text on a label is decorative and does not set camera ISO.

The full acceptance checks are in the [feature specification](planning/feature-specification.md). Physical-camera behavior and photographic tuning still need device validation before release.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| `brew: command not found` | Complete Homebrew's printed shell setup steps and reopen Terminal. |
| `xcodebuild` requires Xcode or shows the wrong version | Select the full Xcode installation with `xcode-select`, then finish first-launch setup in Xcode. |
| `xcodegen` is missing | Run `brew install xcodegen`. |
| `ios/Lutli.xcodeproj` does not exist | Run `./scripts/ios-bootstrap.sh` from the repository root. |
| No iPhone simulator is listed | Install an iOS runtime in Xcode Settings and create an iPhone simulator in **Window → Devices and Simulators** if needed. |
| iPhone is unavailable or its OS is unsupported | Unlock and pair the phone, wait for preparation, and use an Xcode version that supports its installed iOS version. |
| Signing or provisioning fails | Check your Apple account, selected team, unique bundle identifier and device registration in Xcode. |
| Camera is unavailable in Simulator | Use a physical iPhone for capture and camera-control tests. |
| Photos save fails | Read the review screen's save status, check Photos permission and device storage, then retry. Sharing remains available for the latest captured photo. |

## Editing in VS Code on macOS

You can edit the repository in VS Code and run the core tests in its Terminal. Use Xcode for the iOS run destination, simulator/device launch, signing and native debugging. Regenerate the Xcode project after changes to the project specification or source-file layout.
