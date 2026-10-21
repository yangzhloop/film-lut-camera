import CoreImage
import Foundation
import LutliCore

/// Spatial effects operate after the creative LUT, using a highlight mask from
/// the ungraded input. This keeps glow-color selection independent of the LUT
/// while Neutral follows the graded light's color. These are initial artistic
/// parameters, not calibrated simulations of physical diffusion filters.
enum DiffusionRenderer {
    /// Only the soft light/softening layers are reduced. The graded base retains
    /// full capture resolution. This bounds Gaussian work for large photos.
    static let maximumWorkingEdge: CGFloat = 640

    static func apply(to graded: CIImage, source: CIImage, settings: DiffusionSettings) throws -> CIImage {
        // Preserve the old LUT path exactly when disabled, including its extent.
        guard settings.isEnabled else { return graded }
        let bounds = graded.extent
        guard !bounds.isEmpty, !bounds.isInfinite, !bounds.isNull,
              bounds.width.isFinite, bounds.height.isFinite else {
            throw CameraFailure.renderingFailed
        }

        let origin = CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
        let base = graded.cropped(to: bounds).transformed(by: origin)
        let raw = source.cropped(to: bounds).transformed(by: origin)
        let scale = min(1, maximumWorkingEdge / max(bounds.width, bounds.height))
        let workingBounds = CGRect(x: 0, y: 0, width: bounds.width * scale, height: bounds.height * scale)
        let workingBase = try scaled(base, by: scale).cropped(to: workingBounds)
        let workingSource = try scaled(raw, by: scale).cropped(to: workingBounds)
        let edge = max(workingBounds.width, workingBounds.height)
        let isHDF = settings.effect == .hdf

        // Peak RGB recognizes saturated lights as well as white lights. The
        // linear ramp has no contribution below its threshold; dark areas do
        // not acquire a global color cast from selecting a halo color.
        let threshold: CGFloat = isHDF ? 0.65 : 0.55
        let maximum = try filtered("CIMaximumComponent", workingSource)
        let gain = 1 / (1 - threshold)
        let mask = try clamped(filtered("CIColorMatrix", maximum, [
            "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
            "inputBiasVector": CIVector(x: -threshold * gain, y: -threshold * gain, z: -threshold * gain, w: 0)
        ]))

        let highlights: CIImage
        if isHDF, let color = settings.glowColor.rgb {
            highlights = try rgbScaled(mask, red: color.red, green: color.green, blue: color.blue)
        } else {
            highlights = try filtered("CIMultiplyBlendMode", workingBase, [kCIInputBackgroundImageKey: mask])
        }

        let closeRadius = edge * (isHDF ? 0.012 : 0.020)
        let wideRadius = edge * (isHDF ? 0.028 : 0.045)
        let close = try blurred(highlights, radius: closeRadius, bounds: workingBounds)
        let wide = try blurred(highlights, radius: wideRadius, bounds: workingBounds)
        let bloom = try mixed(close, with: wide, amount: isHDF ? 0.30 : 0.25)
        let contribution = settings.strength * (isHDF ? 0.85 : 0.60)
        let weightedBloom = try rgbScaled(bloom, red: contribution, green: contribution, blue: contribution)
        let fullBloom = try scaled(weightedBloom, by: 1 / scale).cropped(to: base.extent)

        let softenedBase: CIImage
        if isHDF {
            softenedBase = base
        } else {
            // Black Mist softens local contrast gently, rather than lifting the
            // entire image with a constant gray/white overlay. Even at 100%,
            // 90% of the full-resolution base detail remains in this blend.
            let soft = try blurred(workingBase, radius: edge * 0.003, bounds: workingBounds)
            let fullSoft = try scaled(soft, by: 1 / scale).cropped(to: base.extent)
            softenedBase = try mixed(base, with: fullSoft, amount: settings.strength * 0.10)
        }
        let combined = try filtered("CIScreenBlendMode", fullBloom, [kCIInputBackgroundImageKey: softenedBase])
        return try clamped(combined)
            .cropped(to: base.extent)
            .transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
            .cropped(to: bounds)
    }

    private static func filtered(_ name: String, _ input: CIImage, _ values: [String: Any] = [:]) throws -> CIImage {
        guard let filter = CIFilter(name: name) else { throw CameraFailure.unavailableFilter }
        filter.setValue(input, forKey: kCIInputImageKey)
        for (key, value) in values { filter.setValue(value, forKey: key) }
        guard let output = filter.outputImage else { throw CameraFailure.renderingFailed }
        return output
    }

    private static func clamped(_ input: CIImage) throws -> CIImage {
        try filtered("CIColorClamp", input, [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])
    }

    private static func rgbScaled(_ input: CIImage, red: Double, green: Double, blue: Double) throws -> CIImage {
        try filtered("CIColorMatrix", input, [
            "inputRVector": CIVector(x: CGFloat(red), y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: CGFloat(green), z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(blue), w: 0)
        ])
    }

    private static func mixed(_ input: CIImage, with target: CIImage, amount: Double) throws -> CIImage {
        try filtered("CIDissolveTransition", input, [kCIInputTargetImageKey: target, kCIInputTimeKey: amount])
    }

    private static func blurred(_ input: CIImage, radius: CGFloat, bounds: CGRect) throws -> CIImage {
        try filtered("CIGaussianBlur", input.clampedToExtent(), [kCIInputRadiusKey: radius]).cropped(to: bounds)
    }

    private static func scaled(_ input: CIImage, by scale: CGFloat) throws -> CIImage {
        guard scale != 1 else { return input }
        // Extend through the Lanczos sampling footprint before resizing. A
        // transparent border would otherwise dim the bloom and soften alpha
        // near frame edges, especially when reducing a large still photo.
        let padding = ceil(3 / min(scale, 1))
        let extended = input.clampedToExtent().cropped(to: input.extent.insetBy(dx: -padding, dy: -padding))
        let bounds = input.extent.applying(CGAffineTransform(scaleX: scale, y: scale))
        return try filtered("CILanczosScaleTransform", extended, [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
            .cropped(to: bounds)
    }
}
