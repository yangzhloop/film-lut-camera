import Foundation
import XCTest
@testable import LutliCore

final class CubeLUTTests: XCTestCase {
    func testParsesIdentityAndPreservesRedFastestOrdering() throws {
        let cube = try CubeLUT.parse(data: identityCubeData())
        XCTAssertEqual(cube.dimension, 17)
        XCTAssertEqual(cube.values.count, 17 * 17 * 17 * 4)
        XCTAssertEqual(Array(cube.values[0..<4]), [0, 0, 0, 1])
        XCTAssertEqual(Array(cube.values[4..<8]), [1 / Float(16), 0, 0, 1])
        XCTAssertEqual(Array(cube.values[(17 * 4)..<(17 * 4 + 4)]), [0, 1 / Float(16), 0, 1])
        XCTAssertEqual(Array(cube.values[(17 * 17 * 4)..<(17 * 17 * 4 + 4)]), [0, 0, 1 / Float(16), 1])
        XCTAssertEqual(Array(cube.values.suffix(4)), [1, 1, 1, 1])
    }

    func testAcceptsBOMCommentsQuotedHashCRLFAndStandardDomain() throws {
        let text = "\u{FEFF}# Exported LUT\r\nTITLE \"Warm # one\" # outside title\r\n"
            + "DOMAIN_MIN 0 0 0\r\nLUT_3D_SIZE 17\r\nDOMAIN_MAX 1 1 1\r\n\r\n"
            + String(repeating: "0.1\t0.2  0.3 # sample\r\n", count: 17 * 17 * 17)
        let cube = try CubeLUT.parse(data: Data(text.utf8))
        XCTAssertEqual(Array(cube.values.prefix(4)), [0.1, 0.2, 0.3, 1])
    }

    func testAcceptsThirtyThreePointCube() throws {
        let cube = try CubeLUT.parse(data: constantCubeData(dimension: 33))
        XCTAssertEqual(cube.values.count, 33 * 33 * 33 * 4)
    }

    func testRejectsUnsupportedAndOneDimensionalLUTs() {
        assertParseError("LUT_3D_SIZE 65\n", .unsupportedDimension(65))
        assertParseError("LUT_3D_SIZE -17\n", .unsupportedDimension(-17))
        assertParseError("LUT_1D_SIZE 17\n", .unsupportedOneDimensional)
    }

    func testRejectsMissingDuplicateAndMalformedHeaders() {
        assertParseError("# empty\n", .missingSize)
        assertParseError("0 0 0\n", .missingSize)
        assertParseError("LUT_3D_SIZE 17\nLUT_3D_SIZE 17\n", .duplicateDirective("LUT_3D_SIZE"))
        assertParseError("TITLE \"a\"\nTITLE \"b\"\n", .duplicateDirective("TITLE"))
        assertParseError("LUT_3D_SIZE 17.0\n", .invalidDirective(line: 1))
        assertParseError("TITLE unquoted\n", .invalidDirective(line: 1))
        assertParseError("LUT_3D_SIZE 17\n0 0 0\nTITLE \"late\"\n", .invalidDirective(line: 3))
        assertParseError("LUT_3D_INPUT_RANGE 0 1\n", .unexpectedContent(line: 1))
    }

    func testRejectsNonstandardOrMalformedDomains() {
        assertParseError("DOMAIN_MIN -0.1 0 0\n", .unsupportedDomain)
        assertParseError("DOMAIN_MAX 1 1 1023\n", .unsupportedDomain)
        assertParseError("DOMAIN_MIN 0 0\n", .invalidDirective(line: 1))
        assertParseError("DOMAIN_MAX 1 nan 1\n", .invalidDirective(line: 1))
        assertParseError("DOMAIN_MIN 0 0 0\nDOMAIN_MIN 0 0 0\n", .duplicateDirective("DOMAIN_MIN"))
    }

    func testRejectsInvalidNumbersAndChannelCounts() {
        for sample in ["nan 0 0", "0 inf 0", "-0.1 0 0", "0 1.01 0", "0 0", "0 0 0 1", "0 nope 0"] {
            assertParseError("LUT_3D_SIZE 17\n" + sample + "\n", .invalidSample(line: 2))
        }
    }

    func testRejectsTooFewAndTooManySamples() {
        assertParseError("LUT_3D_SIZE 17\n0 0 0\n", .wrongSampleCount(expected: 4913, actual: 1))
        let text = "LUT_3D_SIZE 17\n" + String(repeating: "0 0 0\n", count: 4914)
        assertParseError(text, .wrongSampleCount(expected: 4913, actual: 4914))
    }

    func testRejectsOversizedAndNonUTF8Data() {
        XCTAssertThrowsError(try CubeLUT.parse(data: Data(repeating: 32, count: CubeLUT.maximumFileSize + 1))) {
            XCTAssertEqual($0 as? CubeLUTError, .fileTooLarge)
        }
        XCTAssertThrowsError(try CubeLUT.parse(data: Data([0xFF, 0xFE, 0x00]))) {
            XCTAssertEqual($0 as? CubeLUTError, .invalidEncoding)
        }
    }

    func testIntensityEndpointsClampingAndMidpoint() throws {
        let cube = try CubeLUT.parse(data: constantCubeData(rgb: "0.2 0.4 0.6"))
        let neutral = CubeLUT.identity()
        XCTAssertEqual(cube.blended(intensity: 0), neutral)
        XCTAssertEqual(cube.blended(intensity: 1), cube)
        XCTAssertEqual(cube.blended(intensity: -2), neutral)
        XCTAssertEqual(cube.blended(intensity: 3), cube)
        XCTAssertEqual(cube.blended(intensity: .nan), neutral)
        let half = cube.blended(intensity: 0.5)
        XCTAssertEqual(Array(half.values.prefix(4)), [0.1, 0.2, 0.3, 1])
        XCTAssertEqual(half.values[half.values.count - 4], 0.6, accuracy: 0.00001)
        XCTAssertEqual(half.values[half.values.count - 3], 0.7, accuracy: 0.00001)
        XCTAssertEqual(half.values[half.values.count - 2], 0.8, accuracy: 0.00001)
    }

    func testRGBADataIsPackedFloatBytes() throws {
        let cube = try CubeLUT.parse(data: constantCubeData(rgb: "0.2 0.4 0.6"))
        XCTAssertEqual(cube.rgbaData.count, 4913 * 4 * MemoryLayout<Float>.size)
        var firstPixel = [Float](repeating: 0, count: 4)
        firstPixel.withUnsafeMutableBytes { destination in
            _ = cube.rgbaData.copyBytes(to: destination, from: 0..<destination.count)
        }
        XCTAssertEqual(firstPixel, [0.2, 0.4, 0.6, 1])
    }

    func testProgrammaticCubeRejectsInvalidStorage() {
        XCTAssertThrowsError(try CubeLUT(dimension: 65, values: []))
        XCTAssertThrowsError(try CubeLUT(dimension: 17, values: [0, 0, 0]))
        var values = CubeLUT.identity().values
        values[3] = 0.5
        XCTAssertThrowsError(try CubeLUT(dimension: 17, values: values))
    }

    func testBundledGradesAreValidDistinctAndMonochromeIsNeutral() throws {
        XCTAssertEqual(BuiltInLook.allCases.count, 7)
        var firstSamples = Set<String>()
        for look in BuiltInLook.allCases {
            let cube = look.makeLUT()
            XCTAssertNoThrow(try CubeLUT(dimension: cube.dimension, values: cube.values))
            XCTAssertNoThrow(try look.label.validated())
            firstSamples.insert(cube.values.map { String($0) }.joined(separator: ","))
        }
        XCTAssertEqual(firstSamples.count, 7)
        XCTAssertEqual(BuiltInLook.original.makeLUT(), .identity())
        let mono = BuiltInLook.mono800.makeLUT()
        for offset in stride(from: 0, to: mono.values.count, by: 4) {
            XCTAssertEqual(mono.values[offset], mono.values[offset + 1])
            XCTAssertEqual(mono.values[offset + 1], mono.values[offset + 2])
        }
    }

    private func assertParseError(_ text: String, _ expected: CubeLUTError, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try CubeLUT.parse(data: Data(text.utf8)), file: file, line: line) {
            XCTAssertEqual($0 as? CubeLUTError, expected, file: file, line: line)
        }
    }
}

func constantCubeData(dimension: Int = 17, rgb: String = "0 0 0") -> Data {
    Data(("TITLE \"Test cube\"\nLUT_3D_SIZE \(dimension)\n" + String(repeating: rgb + "\n", count: dimension * dimension * dimension)).utf8)
}

func identityCubeData() -> Data {
    var lines = ["LUT_3D_SIZE 17"]
    for blue in 0..<17 {
        for green in 0..<17 {
            for red in 0..<17 {
                lines.append("\(Float(red) / 16) \(Float(green) / 16) \(Float(blue) / 16)")
            }
        }
    }
    return Data((lines.joined(separator: "\n") + "\n").utf8)
}
