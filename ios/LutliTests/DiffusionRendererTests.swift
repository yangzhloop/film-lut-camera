import CoreImage
import ImageIO
import LutliCore
import UniformTypeIdentifiers
import XCTest
@testable import Lutli

/// Synthetic light fixtures establish rendering invariants. Photographic tuning
/// and live-camera/thermal behavior still require physical-device validation.
final class DiffusionRendererTests: XCTestCase {
    private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    func testOffAndZeroStrengthExactlyPreserveTheSelectedLUT() throws {
        let renderer = LUTRenderer()
        renderer.setLUT(BuiltInLook.warm400.makeLUT())
        let source = lightFixture(side: 128, background: [20, 40, 60], light: [255, 240, 200])
        let baseline = bytes(try renderer.render(source))
        for effect in [DiffusionSettings(effect: .off, strength: 1, glowColor: .red),
                       DiffusionSettings(effect: .hdf, strength: 0, glowColor: .amber),
                       DiffusionSettings(effect: .blackMist, strength: 0)] {
            renderer.setDiffusion(effect)
            XCTAssertEqual(bytes(try renderer.render(source)), baseline)
        }
    }

    func testHDFAddsColoredHaloWithoutTintingDistantDarkPixels() throws {
        let renderer = LUTRenderer()
        let source = lightFixture(side: 256)
        let baseline = try renderer.render(source)
        renderer.setDiffusion(DiffusionSettings(effect: .hdf, strength: 1, glowColor: pureRed))
        let output = try renderer.render(source)
        let before = pixel(baseline, x: 148, y: 128)
        let halo = pixel(output, x: 148, y: 128)
        XCTAssertGreaterThan(Int(halo[0]), Int(before[0]) + 8)
        XCTAssertGreaterThan(Int(halo[0]), Int(halo[1]) + 8)
        assertNear(pixel(output, x: 16, y: 16), pixel(baseline, x: 16, y: 16), tolerance: 1)
        XCTAssertEqual(output.width, baseline.width)
        XCTAssertEqual(output.height, baseline.height)
        XCTAssertTrue(bytes(output).enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 255 })
    }

    func testNeutralHDFPreservesTheColorOfASaturatedLight() throws {
        let renderer = LUTRenderer()
        let source = lightFixture(side: 256, light: [40, 100, 255])
        renderer.setDiffusion(DiffusionSettings(effect: .hdf, strength: 1, glowColor: .neutral))
        let halo = pixel(try renderer.render(source), x: 148, y: 128)
        XCTAssertGreaterThan(Int(halo[2]), Int(halo[1]) + 5)
        XCTAssertGreaterThan(Int(halo[1]), Int(halo[0]) + 2)

        renderer.setDiffusion(DiffusionSettings(effect: .hdf, strength: 1, glowColor: pureRed))
        let tinted = pixel(try renderer.render(source), x: 148, y: 128)
        XCTAssertGreaterThan(Int(tinted[0]), Int(tinted[2]) + 8)
    }

    func testHDFDoesNotAddGlowToAnImageWithoutHighlights() throws {
        let renderer = LUTRenderer()
        let source = lightFixture(side: 128, background: [24, 35, 48], light: [80, 100, 120])
        let baseline = try renderer.render(source)
        renderer.setDiffusion(DiffusionSettings(effect: .hdf, strength: 1, glowColor: .red))
        let output = try renderer.render(source)
        assertNear(pixel(output, x: 64, y: 64), pixel(baseline, x: 64, y: 64), tolerance: 1)
        assertNear(pixel(output, x: 20, y: 20), pixel(baseline, x: 20, y: 20), tolerance: 1)
    }

    func testBlackMistCreatesNeutralGlowAndRetainsDarkBackground() throws {
        let renderer = LUTRenderer()
        let source = lightFixture(side: 256)
        let baseline = try renderer.render(source)
        // A stale HDF color must not make Black Mist colored.
        renderer.setDiffusion(DiffusionSettings(effect: .blackMist, strength: 1, glowColor: pureRed))
        let output = try renderer.render(source)
        let halo = pixel(output, x: 148, y: 128)
        XCTAssertGreaterThan(Int(halo[0]), Int(pixel(baseline, x: 148, y: 128)[0]) + 5)
        XCTAssertLessThanOrEqual(abs(Int(halo[0]) - Int(halo[1])), 1)
        XCTAssertLessThanOrEqual(abs(Int(halo[1]) - Int(halo[2])), 1)
        assertNear(pixel(output, x: 16, y: 16), pixel(baseline, x: 16, y: 16), tolerance: 1)
    }

    func testHaloSizeScalesAcrossTheBoundedWorkingResolution() throws {
        let renderer = LUTRenderer()
        renderer.setDiffusion(DiffusionSettings(effect: .hdf, strength: 1, glowColor: pureRed))
        let small = try renderer.render(lightFixture(side: 256))
        let large = try renderer.render(lightFixture(side: 1_024))
        // The large fixture crosses the 640-pixel glow working cap. Compare the
        // measured halo radius, not implementation constants or raw pixel blur.
        let smallRadius = try normalizedHaloRadius(small)
        let largeRadius = try normalizedHaloRadius(large)
        XCTAssertGreaterThan(smallRadius, 0.06)
        XCTAssertEqual(smallRadius, largeRadius, accuracy: 0.004)
        XCTAssertTrue(bytes(large).enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 255 })
    }

    func testChangingLUTPreservesDiffusionAndChangingDiffusionPreservesLUT() {
        let renderer = LUTRenderer()
        let effect = DiffusionSettings(effect: .hdf, strength: 0.45, glowColor: .rose)
        renderer.setDiffusion(effect)
        let cube = BuiltInLook.chrome100.makeLUT().blended(intensity: 0.7)
        renderer.setLUT(cube)
        XCTAssertEqual(renderer.snapshot().diffusion, effect)
        XCTAssertEqual(renderer.snapshot().rgbaData, cube.rgbaData)
        renderer.setDiffusion(DiffusionSettings(effect: .blackMist, strength: 0.2))
        XCTAssertEqual(renderer.snapshot().rgbaData, cube.rgbaData)
        XCTAssertEqual(renderer.snapshot().dimension, cube.dimension)
    }

    func testCapturedPhotoUsesFrozenDiffusionRecipeAfterControlsChange() throws {
        let renderer = LUTRenderer()
        let source = lightFixture(side: 256)
        renderer.setDiffusion(DiffusionSettings(effect: .hdf, strength: 1, glowColor: pureRed))
        let shutterRecipe = renderer.snapshot()
        renderer.setDiffusion(DiffusionSettings())
        renderer.setLUT(BuiltInLook.mono800.makeLUT())

        let capture = try renderer.renderCapture(data: encodedPNG(source), recipe: shutterRecipe, saveOriginal: false)
        let halo = pixel(capture.image, x: 148, y: 128)
        XCTAssertGreaterThan(Int(halo[0]), Int(halo[1]) + 8)
        XCTAssertEqual(shutterRecipe.diffusion.glowColor, pureRed)
        XCTAssertNil(capture.originalJPEG)
    }

    func testCleanOriginalExcludesBothLUTAndDiffusion() throws {
        let renderer = LUTRenderer()
        let source = lightFixture(side: 256, background: [24, 60, 100])
        renderer.setLUT(BuiltInLook.mono800.makeLUT())
        renderer.setDiffusion(DiffusionSettings(effect: .hdf, strength: 1, glowColor: pureRed))
        let capture = try renderer.renderCapture(data: encodedPNG(source), recipe: renderer.snapshot(), saveOriginal: true)
        let original = try decoded(try XCTUnwrap(capture.originalJPEG))

        assertNear(pixel(original, x: 16, y: 16), [24, 60, 100, 255], tolerance: 4)
        assertNear(pixel(original, x: 148, y: 128), [24, 60, 100, 255], tolerance: 5)
        let graded = pixel(capture.image, x: 16, y: 16)
        XCTAssertLessThanOrEqual(abs(Int(graded[0]) - Int(graded[2])), 2)
        let halo = pixel(capture.image, x: 148, y: 128)
        XCTAssertGreaterThan(Int(halo[0]), Int(halo[1]) + 8)
    }

    private var pureRed: GlowColor { .custom(RGBColor(red: 1, green: 0, blue: 0)) }

    /// Exact power-of-two geometry makes independently generated resolutions
    /// represent the same scene without changing the source highlight area.
    private func lightFixture(side: Int, background: [UInt8] = [10, 10, 10], light: [UInt8] = [255, 255, 255]) -> CIImage {
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        let lower = side * 7 / 16
        let upper = side * 9 / 16
        for y in 0..<side {
            for x in 0..<side {
                let color = (lower..<upper).contains(x) && (lower..<upper).contains(y) ? light : background
                let offset = (y * side + x) * 4
                pixels[offset] = color[0]
                pixels[offset + 1] = color[1]
                pixels[offset + 2] = color[2]
            }
        }
        return CIImage(bitmapData: Data(pixels), bytesPerRow: side * 4,
                       size: CGSize(width: side, height: side), format: .RGBA8, colorSpace: sRGB)
    }

    private func bytes(_ image: CGImage) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        context().render(CIImage(cgImage: image), toBitmap: &result, rowBytes: image.width * 4,
                         bounds: CGRect(x: 0, y: 0, width: image.width, height: image.height),
                         format: .RGBA8, colorSpace: sRGB)
        return result
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        let data = bytes(image)
        let start = (y * image.width + x) * 4
        return Array(data[start..<(start + 4)])
    }

    private func normalizedHaloRadius(_ image: CGImage) throws -> Double {
        let data = bytes(image)
        let center = Double(image.width) / 2
        let upper = image.width * 9 / 16
        var energy = 0.0
        var moment = 0.0
        for x in upper..<image.width {
            let amount = Double(max(0, Int(data[(image.height / 2 * image.width + x) * 4]) - 10))
            energy += amount
            moment += amount * (Double(x) + 0.5 - center)
        }
        XCTAssertGreaterThan(energy, 0)
        guard energy > 0 else { throw CameraFailure.renderingFailed }
        return moment / energy / Double(image.width)
    }

    private func context() -> CIContext {
        CIContext(options: [.workingColorSpace: sRGB, .outputColorSpace: sRGB])
    }

    private func encodedPNG(_ input: CIImage) throws -> Data {
        let image = try XCTUnwrap(context().createCGImage(input, from: input.extent, format: .RGBA8, colorSpace: sRGB))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func decoded(_ data: Data) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func assertNear(_ actual: [UInt8], _ expected: [UInt8], tolerance: Int,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actual, expected) in zip(actual, expected) {
            XCTAssertLessThanOrEqual(abs(Int(actual) - Int(expected)), tolerance, file: file, line: line)
        }
    }
}
