import Foundation
import XCTest

/// Exercise the real controls without requiring a camera in Simulator.
/// Renderer pixel tests establish effect output separately.
@MainActor
final class DiffusionControlsTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            let okay = alert.buttons["OK"]
            if okay.exists { okay.tap(); return true }
            return false
        }
    }

    func testEffectSwitchingRetainsStrengthColorAndControlPlacement() {
        launch()
        let toggle = app.buttons["diffusion.toggle"]
        XCTAssertTrue((toggle.value as? String) == "Off")
        let shutter = app.buttons["camera.shutter"]
        let shutterFrame = shutter.frame

        toggle.tap()
        app.buttons["diffusion.effect.hdf"].tap()
        let strength = app.sliders["diffusion.strength"]
        XCTAssertTrue(strength.waitForExistence(timeout: 3))
        strength.adjust(toNormalizedSliderPosition: 0.60)
        app.buttons["diffusion.color.amber"].tap()
        let hdfValue = strength.value as? String
        XCTAssertEqual(shutter.frame.minY, shutterFrame.minY, accuracy: 1)
        attachScreenshot("HDF controls")

        app.buttons["diffusion.close"].tap()
        XCTAssertFalse(app.sliders["diffusion.strength"].exists)
        XCTAssertTrue((toggle.value as? String)?.contains("HDF") == true)
        toggle.tap()
        XCTAssertEqual(app.sliders["diffusion.strength"].value as? String, hdfValue)

        app.buttons["diffusion.effect.blackMist"].tap()
        XCTAssertFalse(app.buttons["diffusion.color.amber"].exists)
        app.sliders["diffusion.strength"].adjust(toNormalizedSliderPosition: 0.25)
        let mistValue = app.sliders["diffusion.strength"].value as? String
        attachScreenshot("Black Mist controls")

        app.buttons["diffusion.effect.hdf"].tap()
        XCTAssertEqual(app.sliders["diffusion.strength"].value as? String, hdfValue)
        XCTAssertTrue(app.buttons["diffusion.color.amber"].isSelected)
        app.buttons["diffusion.effect.off"].tap()
        XCTAssertFalse(app.sliders["diffusion.strength"].exists)
        app.buttons["diffusion.effect.blackMist"].tap()
        XCTAssertEqual(app.sliders["diffusion.strength"].value as? String, mistValue)
        XCTAssertEqual(shutter.frame.minY, shutterFrame.minY, accuracy: 1)
    }

    func testDiffusionSurvivesLookAndMenuChangesButResetsOnFreshLaunch() {
        launch()
        app.buttons["diffusion.toggle"].tap()
        app.buttons["diffusion.effect.hdf"].tap()
        app.buttons["diffusion.color.rose"].tap()
        app.buttons["diffusion.close"].tap()

        let warmLook = app.buttons["camera.look.builtin:warm400"]
        XCTAssertTrue(warmLook.waitForExistence(timeout: 5))
        if !warmLook.isHittable { app.scrollViews["camera.lookStrip"].swipeLeft() }
        warmLook.tap()
        let lookIntensity = app.sliders["camera.lookIntensity"]
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: lookIntensity)
        waitForExpectations(timeout: 5)
        lookIntensity.adjust(toNormalizedSliderPosition: 0.30)

        app.buttons["App menu"].tap()
        app.buttons["Close app menu"].tap()
        XCTAssertTrue((app.buttons["diffusion.toggle"].value as? String)?.contains("HDF") == true)
        app.buttons["diffusion.toggle"].tap()
        XCTAssertTrue(app.buttons["diffusion.color.rose"].isSelected)
        app.buttons["diffusion.close"].tap()

        app.terminate()
        launch()
        XCTAssertTrue((app.buttons["diffusion.toggle"].value as? String) == "Off")
    }

    func testLargeTextKeepsChoicesAndShutterWithinScreen() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch()
        let shutter = app.buttons["camera.shutter"]
        let originalFrame = shutter.frame
        app.buttons["diffusion.toggle"].tap()
        let hdf = app.buttons["diffusion.effect.hdf"]
        XCTAssertTrue(hdf.isHittable)
        hdf.tap()
        XCTAssertTrue(app.buttons["diffusion.close"].isHittable)
        XCTAssertGreaterThan(shutter.frame.height, 0)
        XCTAssertEqual(shutter.frame.minY, originalFrame.minY, accuracy: 1)
        XCTAssertLessThanOrEqual(shutter.frame.maxY, app.windows.firstMatch.frame.maxY)
        attachScreenshot("Diffusion with accessibility text")
    }

    private func launch() {
        app.launch()
        // Simulator may report unavailable camera hardware. Dismiss its actual
        // alert; do not replace camera or diffusion state with a test fixture.
        let cameraAlert = app.alerts["Lutli"]
        if cameraAlert.waitForExistence(timeout: 3) {
            cameraAlert.buttons["OK"].tap()
        }
        XCTAssertTrue(app.buttons["diffusion.toggle"].waitForExistence(timeout: 10))
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
