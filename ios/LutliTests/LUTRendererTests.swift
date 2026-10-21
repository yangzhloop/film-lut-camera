import CoreImage
import ImageIO
import LutliCore
import UniformTypeIdentifiers
import XCTest
@testable import Lutli

/// Apple-framework integration tests. These must run on an iOS simulator or device;
/// portable Swift tests do not validate Core Image's color-space behavior.
final class LUTRendererTests: XCTestCase {
    private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    func testIdentityPreservesSRGBChannels() throws {
        let renderer = LUTRenderer()
        let result = try renderer.render(pixel(red: 64, green: 128, blue: 192))
        assertPixel(result, equals: [64, 128, 192, 255], tolerance: 2)
    }

    func testCubeRedFastestOrderingReachesCoreImage() throws {
        let renderer = LUTRenderer()
        renderer.setLUT(try channelRotation())
        let result = try renderer.render(pixel(red: 64, green: 128, blue: 192))
        assertPixel(result, equals: [192, 64, 128, 255], tolerance: 2)
    }

    func testZeroIntensityPreservesInput() throws {
        let renderer = LUTRenderer()
        renderer.setLUT(try channelRotation().blended(intensity: 0))
        let result = try renderer.render(pixel(red: 48, green: 144, blue: 224))
        assertPixel(result, equals: [48, 144, 224, 255], tolerance: 2)
    }

    func testCaptureRecipeDoesNotFollowLaterLookChanges() throws {
        let renderer = LUTRenderer()
        renderer.setLUT(try channelRotation())
        let shutterRecipe = renderer.snapshot()
        renderer.setLUT(.identity())
        let source = pixel(red: 64, green: 128, blue: 192)
        assertPixel(try renderer.render(source, recipe: shutterRecipe), equals: [192, 64, 128, 255], tolerance: 2)
        assertPixel(try renderer.render(source), equals: [64, 128, 192, 255], tolerance: 2)
    }

    func testCaptureNormalizesEXIFOrientationOnceAndIncludesCleanCopy() throws {
        let renderer = LUTRenderer()
        let source = CIImage(color: CIColor(red: 0.25, green: 0.5, blue: 0.75))
            .cropped(to: CGRect(x: 0, y: 0, width: 80, height: 60))
        let context = CIContext(options: [.workingColorSpace: sRGB, .outputColorSpace: sRGB])
        let cgImage = try XCTUnwrap(context.createCGImage(source, from: source.extent, format: .RGBA8, colorSpace: sRGB))
        let input = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(input, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let capture = try renderer.renderCapture(data: input as Data, recipe: renderer.snapshot(), saveOriginal: true)
        XCTAssertEqual(capture.image.width, 60)
        XCTAssertEqual(capture.image.height, 80)
        for data in [capture.filteredJPEG, try XCTUnwrap(capture.originalJPEG)] {
            let decoded = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
            XCTAssertEqual(image.width, 60)
            XCTAssertEqual(image.height, 80)
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil) as? [CFString: Any])
            XCTAssertEqual(properties[kCGImagePropertyOrientation] as? Int, 1)
        }
    }

    func testCaptureConvertsEmbeddedDisplayP3RatherThanReinterpretingIt() throws {
        let p3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let p3Context = CIContext(options: [.workingColorSpace: p3, .outputColorSpace: p3])
        let source = CIImage(bitmapData: Data([100, 180, 70, 255]), bytesPerRow: 4,
                             size: CGSize(width: 1, height: 1), format: .RGBA8, colorSpace: p3)
        let cgImage = try XCTUnwrap(p3Context.createCGImage(source, from: source.extent, format: .RGBA8, colorSpace: p3))
        let encoded = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let data = encoded as Data
        let decoded = try XCTUnwrap(CIImage(data: data, options: [.applyOrientationProperty: true]))
        let referenceContext = CIContext(options: [.workingColorSpace: sRGB, .outputColorSpace: sRGB])
        let reference = try XCTUnwrap(referenceContext.createCGImage(decoded, from: decoded.extent, format: .RGBA8, colorSpace: sRGB))
        let renderer = LUTRenderer()
        let capture = try renderer.renderCapture(data: data, recipe: renderer.snapshot(), saveOriginal: true)
        var expected = [UInt8](repeating: 0, count: 4)
        referenceContext.render(CIImage(cgImage: reference), toBitmap: &expected, rowBytes: 4,
                                bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: sRGB)
        assertPixel(capture.image, equals: expected, tolerance: 2)
    }

    func testCaptureRejectsInvalidImageData() {
        let renderer = LUTRenderer()
        XCTAssertThrowsError(try renderer.renderCapture(data: Data("not a photograph".utf8), recipe: renderer.snapshot(), saveOriginal: false))
    }

    private func pixel(red: UInt8, green: UInt8, blue: UInt8) -> CIImage {
        CIImage(bitmapData: Data([red, green, blue, 255]), bytesPerRow: 4,
                size: CGSize(width: 1, height: 1), format: .RGBA8, colorSpace: sRGB)
    }

    private func assertPixel(_ image: CGImage, equals expected: [UInt8], tolerance: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: sRGB, .outputColorSpace: sRGB])
        context.render(CIImage(cgImage: image), toBitmap: &bytes, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: sRGB)
        for (actual, target) in zip(bytes, expected) {
            XCTAssertLessThanOrEqual(abs(Int(actual) - Int(target)), tolerance, file: file, line: line)
        }
    }

    private func channelRotation() throws -> CubeLUT {
        let dimension = 17
        var lines = ["TITLE \"Channel rotation\"", "LUT_3D_SIZE 17"]
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    lines.append("\(Double(blue) / 16) \(Double(red) / 16) \(Double(green) / 16)")
                }
            }
        }
        return try CubeLUT.parse(data: Data(lines.joined(separator: "\n").utf8))
    }
}
