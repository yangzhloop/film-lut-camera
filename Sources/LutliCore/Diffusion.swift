import Foundation

/// The diffusion stage is independent of the selected LUT look.
public enum DiffusionEffect: String, CaseIterable, Sendable {
    case off
    case hdf
    case blackMist
}

/// Opaque, normalized sRGB components suitable for a glow tint.
public struct RGBColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = normalized(red)
        self.green = normalized(green)
        self.blue = normalized(blue)
    }
}

public enum GlowColor: Equatable, Sendable {
    case neutral
    case amber
    case rose
    case red
    case custom(RGBColor)

    public static let presets: [GlowColor] = [.neutral, .amber, .rose, .red]

    /// A nil tint preserves the source highlight's color; it is not white paint.
    public var rgb: RGBColor? {
        switch self {
        case .neutral: return nil
        case .amber: return RGBColor(red: 1, green: 0.62, blue: 0.28)
        case .rose: return RGBColor(red: 1, green: 0.45, blue: 0.55)
        case .red: return RGBColor(red: 1, green: 0.22, blue: 0.16)
        case .custom(let color): return color
        }
    }

    public var label: String {
        switch self {
        case .neutral: return "Neutral"
        case .amber: return "Amber"
        case .rose: return "Rose"
        case .red: return "Red"
        case .custom: return "Custom"
        }
    }
}

/// A value snapshot that can be frozen together with the LUT at shutter time.
public struct DiffusionSettings: Equatable, Sendable {
    public let effect: DiffusionEffect
    public let strength: Double
    public let glowColor: GlowColor

    public init(effect: DiffusionEffect = .off, strength: Double = 0, glowColor: GlowColor = .neutral) {
        self.effect = effect
        self.strength = normalized(strength)
        // Color belongs to HDF. Black Mist must not inherit an old HDF tint.
        self.glowColor = effect == .hdf ? glowColor : .neutral
    }

    public var isEnabled: Bool { effect != .off && strength > 0 }
}

/// In-memory state for one app session. A new instance always starts with Off.
/// The initial amounts are tuning candidates, not physical-filter equivalents.
public struct DiffusionState: Equatable, Sendable {
    public private(set) var effect: DiffusionEffect = .off
    public private(set) var hdfStrength: Double = 0.35
    public private(set) var blackMistStrength: Double = 0.20
    public private(set) var glowColor: GlowColor = .neutral

    public init() {}

    public mutating func select(_ effect: DiffusionEffect) {
        self.effect = effect
    }

    public mutating func setStrength(_ value: Double) {
        // Ignore invalid UI input rather than unexpectedly resetting an active effect.
        guard value.isFinite else { return }
        switch effect {
        case .off: break
        case .hdf: hdfStrength = normalized(value)
        case .blackMist: blackMistStrength = normalized(value)
        }
    }

    public mutating func setGlowColor(_ color: GlowColor) {
        glowColor = color
    }

    public var strength: Double {
        switch effect {
        case .off: return 0
        case .hdf: return hdfStrength
        case .blackMist: return blackMistStrength
        }
    }

    public var settings: DiffusionSettings {
        DiffusionSettings(effect: effect, strength: strength, glowColor: glowColor)
    }
}

/// Reject nonfinite values before they reach a renderer; clamp finite input.
private func normalized(_ value: Double) -> Double {
    value.isFinite ? min(max(value, 0), 1) : 0
}
