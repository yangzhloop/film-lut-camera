import XCTest
@testable import LutliCore

final class DiffusionTests: XCTestCase {
    func testFreshSessionStartsOffWithoutRestoringAnEarlierSession() {
        var previousSession = DiffusionState()
        previousSession.select(.hdf)
        previousSession.setStrength(0.8)
        previousSession.setGlowColor(.rose)

        let freshSession = DiffusionState()
        XCTAssertEqual(freshSession.effect, .off)
        XCTAssertEqual(freshSession.strength, 0)
        XCTAssertEqual(freshSession.glowColor, .neutral)
        XCTAssertFalse(freshSession.settings.isEnabled)
        XCTAssertTrue(previousSession.settings.isEnabled)
    }

    func testSwitchingEffectsAndOffRetainsEachAmountAndHDFColor() {
        var state = DiffusionState()
        state.select(.hdf)
        state.setStrength(0.64)
        state.setGlowColor(.custom(RGBColor(red: 0.3, green: 0.7, blue: 1)))
        let hdf = state.settings

        state.select(.blackMist)
        state.setStrength(0.18)
        XCTAssertEqual(state.settings.glowColor, .neutral)
        state.select(.off)
        XCTAssertEqual(state.strength, 0)
        XCTAssertFalse(state.settings.isEnabled)
        state.select(.blackMist)
        XCTAssertEqual(state.strength, 0.18)
        state.select(.hdf)
        XCTAssertEqual(state.settings, hdf)
    }

    func testZeroStrengthBypassesWithoutLosingTheSelectedModeOrTint() {
        var state = DiffusionState()
        state.select(.hdf)
        state.setGlowColor(.amber)
        state.setStrength(0)
        XCTAssertEqual(state.effect, .hdf)
        XCTAssertEqual(state.glowColor, .amber)
        XCTAssertFalse(state.settings.isEnabled)

        state.select(.off)
        state.select(.hdf)
        XCTAssertEqual(state.strength, 0)
        XCTAssertEqual(state.settings.glowColor, .amber)
        state.setStrength(0.01)
        XCTAssertTrue(state.settings.isEnabled)
    }

    func testStrengthChangeWhileOffCannotOverwriteAnInactiveEffect() {
        var state = DiffusionState()
        state.select(.hdf)
        state.setStrength(0.65)
        state.select(.blackMist)
        state.setStrength(0.27)
        state.select(.off)
        state.setStrength(0.9)

        XCTAssertEqual(state.hdfStrength, 0.65)
        XCTAssertEqual(state.blackMistStrength, 0.27)
        XCTAssertEqual(state.strength, 0)
    }

    func testMutableStrengthClampsFiniteValuesAndIgnoresNonfiniteInput() {
        for effect in [DiffusionEffect.hdf, .blackMist] {
            var state = DiffusionState()
            state.select(effect)
            state.setStrength(-2)
            XCTAssertEqual(state.strength, 0)
            state.setStrength(5)
            XCTAssertEqual(state.strength, 1)
            state.setStrength(0.43)
            for invalid in [Double.nan, .infinity, -.infinity] {
                state.setStrength(invalid)
                XCTAssertEqual(state.strength, 0.43)
            }
        }
    }

    func testSettingsSnapshotDoesNotFollowLaterSessionEdits() {
        var state = DiffusionState()
        state.select(.hdf)
        state.setStrength(0.6)
        state.setGlowColor(.red)
        let capture = state.settings

        state.setStrength(0.1)
        state.setGlowColor(.neutral)
        state.select(.blackMist)
        XCTAssertEqual(capture.effect, .hdf)
        XCTAssertEqual(capture.strength, 0.6)
        XCTAssertEqual(capture.glowColor, .red)
        XCTAssertNotEqual(capture, state.settings)
    }

    func testDirectSettingsSanitizeStrengthAndRespectOffBypass() {
        XCTAssertEqual(DiffusionSettings(effect: .hdf, strength: -1).strength, 0)
        XCTAssertEqual(DiffusionSettings(effect: .blackMist, strength: 2).strength, 1)
        for invalid in [Double.nan, .infinity, -.infinity] {
            let settings = DiffusionSettings(effect: .hdf, strength: invalid)
            XCTAssertEqual(settings.strength, 0)
            XCTAssertFalse(settings.isEnabled)
        }
        XCTAssertFalse(DiffusionSettings(effect: .off, strength: 1).isEnabled)
        XCTAssertFalse(DiffusionSettings().isEnabled)
    }

    func testNonHDFRecipesCannotInheritAColoredHalo() {
        for effect in [DiffusionEffect.off, .blackMist] {
            let settings = DiffusionSettings(effect: effect, strength: 0.5, glowColor: .rose)
            XCTAssertEqual(settings.glowColor, .neutral)
            XCTAssertNil(settings.glowColor.rgb)
        }
        let hdf = DiffusionSettings(effect: .hdf, strength: 0.5, glowColor: .rose)
        XCTAssertEqual(hdf.glowColor, .rose)
    }

    func testNeutralIsSourcePreservingAndDifferentFromAWhiteCustomTint() {
        XCTAssertNil(GlowColor.neutral.rgb)
        let white = GlowColor.custom(RGBColor(red: 1, green: 1, blue: 1))
        XCTAssertNotEqual(GlowColor.neutral, white)
        XCTAssertEqual(white.rgb, RGBColor(red: 1, green: 1, blue: 1))
        XCTAssertEqual(white.label, "Custom")
    }

    func testRGBComponentsStayFiniteAndNormalized() {
        let clamped = RGBColor(red: -0.5, green: 1.5, blue: 0.37)
        XCTAssertEqual(clamped, RGBColor(red: 0, green: 1, blue: 0.37))
        let invalid = RGBColor(red: .nan, green: .infinity, blue: -.infinity)
        XCTAssertEqual(invalid, RGBColor(red: 0, green: 0, blue: 0))

        for color in GlowColor.presets {
            guard let rgb = color.rgb else { continue }
            for component in [rgb.red, rgb.green, rgb.blue] {
                XCTAssertTrue(component.isFinite)
                XCTAssertTrue((0...1).contains(component))
            }
        }
    }

    func testGlowPaletteProvidesDistinctNamedTints() throws {
        XCTAssertEqual(GlowColor.presets.map(\.label), ["Neutral", "Amber", "Rose", "Red"])
        let amber = try XCTUnwrap(GlowColor.amber.rgb)
        let rose = try XCTUnwrap(GlowColor.rose.rgb)
        let red = try XCTUnwrap(GlowColor.red.rgb)
        XCTAssertGreaterThan(amber.red, amber.green)
        XCTAssertGreaterThan(amber.green, amber.blue)
        XCTAssertGreaterThan(rose.blue, rose.green)
        XCTAssertGreaterThan(red.red, red.green)
        XCTAssertNotEqual(amber, rose)
        XCTAssertNotEqual(rose, red)
    }
}
