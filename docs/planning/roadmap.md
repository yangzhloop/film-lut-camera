# Development roadmap

This roadmap organizes the next work. It contains no delivery dates and does not imply that the proposed implementation choices have been approved.

## 1. Resolve the implementation baseline

- Confirm the first-release scope, supported iPhones/iOS versions, and key quality expectations.
- Compare suitable native and cross-platform approaches, especially camera control, preview rendering, capture processing, and future Android support.
- Select a framework and record the decision before scaffolding the application.
- Specify compatible LUT files, input/output color spaces, processing order, and the initial bundled collection.

Exit evidence: an agreed scope and technical decision record, including a practical macOS/Xcode development and validation path.

## 2. Build an interactive UI prototype

- Apply the `lutli` wordmark to the current design baseline.
- Prototype the camera controls, scrolling label strip, leading library entry, app menu, Your looks, and Customize label.
- Exercise importing/editing flows with clearly identified sample data.
- Validate navigation, readable labels, text entry, accessibility, and small-screen layouts.

Exit evidence: a navigable prototype with the proposed interactions reviewed. Sample imagery or simulated camera controls must be identified as such.

## 3. Prove the camera and LUT pipeline

- Connect a real camera preview on a supported iPhone.
- Apply a neutral look and one controlled reference LUT.
- Capture a photograph and compare its appearance, crop, and orientation with the preview.
- Evaluate white balance, exposure compensation, responsiveness, and thermal behavior on representative hardware.

Exit evidence: a real-device capture path with measured observations and any limitations documented. A UI prototype or SDK-only smoke test is insufficient.

## 4. Implement look management and capture controls

- Add the curated built-in looks and agreed intensity behavior.
- Implement validated LUT import, collection capacity, persistence, replacement, and deletion.
- Connect editable two-section labels to the collection and camera strip.
- Implement the agreed WB/exposure behavior, output format, original-copy option if retained, and settings persistence.

Exit evidence: successful end-to-end import, customize, select, capture, and relaunch workflows, including invalid imports and failed operations.

## 5. Complete application settings and release validation

- Implement the approved detailed settings, feedback route, About page, and legal destinations.
- Test permissions, saving/storage errors, interruptions, orientation, supported camera/lens combinations, and accessibility.
- Test look consistency across the supported devices and expected lighting conditions.
- Finalize bundled assets, product copy, and release requirements.

Exit evidence: the agreed device matrix and acceptance checks pass, with known limitations recorded.

## Later milestones

Evaluate Android after the iOS workflow and rendering behavior are established. Reuse product rules and compatible look assets where appropriate, while validating each platform's camera capabilities and color behavior.

Video, RAW, full manual exposure, grain/halation, saved recipes, and editing existing photos remain separate scope decisions.

## Current environment and verification limits

The onboarding environment is Linux. It has a prepared JDK 21 and Android API 36 toolchain. A temporary Android toolchain smoke check successfully compiled a Java Activity, converted it to DEX, packaged an unsigned APK, and verified its contents. This did not build or test Lutli, Gradle, a chosen framework, or a camera application.

Native iOS builds, iOS Simulator, Apple SDK use, signing, and iPhone testing require macOS/Xcode. The current machine has no configured Android emulator or physical camera/device for functional validation.

At the start of this planning branch, the repository contained only its license. There is no application implementation or project test suite yet. Dependency installation, platform targets, and actual build/test commands must be established after choosing the implementation approach.
