import Foundation
import XCTest
@testable import LutliCore

final class FilterLabelTests: XCTestCase {
    func testTrimsTextAndAllowsWordsInBothSections() throws {
        let label = FilterLabel(topText: "  Daylight ", bottomText: " Soft ", topColor: .indigo, bottomColor: .yellow)
        let result = try label.validated()
        XCTAssertEqual(result.topText, "Daylight")
        XCTAssertEqual(result.bottomText, "Soft")
        XCTAssertEqual(result.topColor, .indigo)
        XCTAssertEqual(result.bottomColor, .yellow)
    }

    func testRejectsEmptyLongAndMultilineLabels() {
        for top in [" ", "ABCDEFGHIJKLM", "Two\nLines", "Bad\tLabel"] {
            let label = FilterLabel(topText: top, bottomText: "400", topColor: .indigo, bottomColor: .yellow)
            XCTAssertThrowsError(try label.validated())
        }
        XCTAssertThrowsError(try FilterLabel(topText: "Good", bottomText: "", topColor: .green, bottomColor: .cream).validated())
    }

    func testUnicodeLengthUsesUserVisibleCharacters() throws {
        let label = FilterLabel(topText: "日光", bottomText: "🌅", topColor: .red, bottomColor: .slate)
        XCTAssertEqual(try label.validated(), label)
    }

    func testPaletteIsFixedAndBothColorsSurviveCoding() throws {
        XCTAssertEqual(LabelColor.allCases.count, 8)
        let label = FilterLabel(topText: "Night", bottomText: "800", topColor: .violet, bottomColor: .slate)
        let data = try JSONEncoder().encode(label)
        XCTAssertEqual(try JSONDecoder().decode(FilterLabel.self, from: data), label)
    }

    func testChosenTextColorMeetsNormalTextContrast() {
        for color in LabelColor.allCases {
            let background = luminance(color.hex)
            let foreground = luminance(color.foregroundHex)
            let contrast = (max(background, foreground) + 0.05) / (min(background, foreground) + 0.05)
            XCTAssertGreaterThanOrEqual(contrast, 4.5, "Insufficient contrast for \(color.rawValue)")
        }
        XCTAssertEqual(LabelColor.yellow.foregroundHex, "000000")
        XCTAssertEqual(LabelColor.indigo.foregroundHex, "FFFFFF")
    }

    private func luminance(_ hex: String) -> Double {
        let rgb = UInt32(hex, radix: 16)!
        let channels = [(rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255].map { Double($0) / 255 }
        let linear = channels.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
