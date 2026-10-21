import CoreImage
import Foundation
import ImageIO
import LutliCore
import UniformTypeIdentifiers

/// Uses the same SDR sRGB rendering path for the preview and captured photos.
/// CIContext is reused; CIFilter instances are local to each render operation.
final class LUTRenderer {
    struct Recipe {
        let dimension: Int
        let rgbaData: Data
    }

    private let lock = NSLock()
    private var recipe: Recipe
    private let colorSpace: CGColorSpace
    private let context: CIContext

    init() {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        self.colorSpace = colorSpace
        context = CIContext(options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .cacheIntermediates: false
        ])
        let identity = CubeLUT.identity()
        recipe = Recipe(dimension: identity.dimension, rgbaData: identity.rgbaData)
    }

    func setLUT(_ cube: CubeLUT) {
        let value = Recipe(dimension: cube.dimension, rgbaData: cube.rgbaData)
        lock.lock()
        recipe = value
        lock.unlock()
    }

    func snapshot() -> Recipe {
        lock.lock()
        defer { lock.unlock() }
        return recipe
    }

    func renderPreview(_ input: CIImage) throws -> CGImage {
        // Keep CPU-side preview images bounded even when the capture session
        // delivers large buffers for its photo-oriented active format.
        let longestEdge = max(input.extent.width, input.extent.height)
        let scale = longestEdge > 1_280 ? 1_280 / longestEdge : 1
        return try render(input.transformed(by: CGAffineTransform(scaleX: scale, y: scale)))
    }

    func render(_ input: CIImage, recipe: Recipe? = nil) throws -> CGImage {
        let recipe = recipe ?? snapshot()
        guard let clamp = CIFilter(name: "CIColorClamp"),
              let cube = CIFilter(name: "CIColorCubeWithColorSpace") else {
            throw CameraFailure.unavailableFilter
        }
        clamp.setValue(input, forKey: kCIInputImageKey)
        clamp.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputMinComponents")
        clamp.setValue(CIVector(x: 1, y: 1, z: 1, w: 1), forKey: "inputMaxComponents")
        guard let clamped = clamp.outputImage else { throw CameraFailure.renderingFailed }
        cube.setValue(clamped, forKey: kCIInputImageKey)
        cube.setValue(recipe.dimension, forKey: "inputCubeDimension")
        cube.setValue(recipe.rgbaData, forKey: "inputCubeData")
        cube.setValue(colorSpace, forKey: "inputColorSpace")
        guard let output = cube.outputImage,
              let image = context.createCGImage(output, from: input.extent, format: .RGBA8, colorSpace: colorSpace) else {
            throw CameraFailure.renderingFailed
        }
        return image
    }

    func renderCapture(data: Data, recipe: Recipe, saveOriginal: Bool) throws -> CapturedPhoto {
        // AVCapturePhoto encodes orientation/mirroring in its processed output.
        // Applying its orientation property exactly once produces upright pixels.
        // Preserve the file's embedded profile (which can be Display P3). The
        // sRGB context converts it; assigning sRGB here would reinterpret the
        // original channel values and change the captured colors.
        guard let input = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw CameraFailure.invalidPhotoData
        }
        let image = try render(input, recipe: recipe)
        let filteredJPEG = try encodeJPEG(image)
        var originalJPEG: Data?
        if saveOriginal {
            guard let original = context.createCGImage(input, from: input.extent, format: .RGBA8, colorSpace: colorSpace) else {
                throw CameraFailure.renderingFailed
            }
            originalJPEG = try encodeJPEG(original)
        }
        return CapturedPhoto(
            id: UUID(), createdAt: Date(), image: image,
            filteredJPEG: filteredJPEG, originalJPEG: originalJPEG
        )
    }

    private func encodeJPEG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CameraFailure.encodingFailed
        }
        // Pixels are already upright, so the output has no additional rotation.
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.95,
            kCGImagePropertyOrientation: 1
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CameraFailure.encodingFailed }
        return data as Data
    }
}
