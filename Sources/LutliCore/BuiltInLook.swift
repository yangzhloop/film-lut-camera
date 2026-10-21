import Foundation

/// Original starter grades generated as sampled LUTs, not reproductions of named film stocks.
/// These assets need photographic tuning and device validation before release.
public enum BuiltInLook: String, Codable, CaseIterable, Sendable {
    case original, warm400, soft200, chrome100, night800, fade400, mono800

    public var label: FilterLabel {
        switch self {
        case .original: return .init(topText: "ORIGINAL", bottomText: "RGB", topColor: .charcoal, bottomColor: .cream)
        case .warm400: return .init(topText: "WARM", bottomText: "400", topColor: .indigo, bottomColor: .yellow)
        case .soft200: return .init(topText: "SOFT", bottomText: "200", topColor: .green, bottomColor: .cream)
        case .chrome100: return .init(topText: "CHROME", bottomText: "100", topColor: .red, bottomColor: .cream)
        case .night800: return .init(topText: "NIGHT", bottomText: "800", topColor: .violet, bottomColor: .slate)
        case .fade400: return .init(topText: "FADE", bottomText: "400", topColor: .slate, bottomColor: .yellow)
        case .mono800: return .init(topText: "MONO", bottomText: "800", topColor: .charcoal, bottomColor: .cream)
        }
    }

    public func makeLUT() -> CubeLUT {
        guard self != .original else { return .identity() }
        return .sampled { red, green, blue in
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            func color(_ value: Float, saturation: Float, contrast: Float, lift: Float = 0) -> Float {
                let saturated = luminance + (value - luminance) * saturation
                return (saturated - 0.5) * contrast + 0.5 + lift
            }
            switch self {
            case .original: return (red, green, blue)
            case .warm400:
                return (color(red, saturation: 0.94, contrast: 0.92, lift: 0.035),
                        color(green, saturation: 0.94, contrast: 0.92, lift: 0.009),
                        color(blue, saturation: 0.94, contrast: 0.92, lift: -0.025))
            case .soft200:
                return (color(red, saturation: 0.80, contrast: 0.83, lift: 0.018),
                        color(green, saturation: 0.84, contrast: 0.87, lift: 0.015),
                        color(blue, saturation: 0.80, contrast: 0.86, lift: 0.005))
            case .chrome100:
                return (color(red, saturation: 1.14, contrast: 1.08),
                        color(green, saturation: 1.10, contrast: 1.08),
                        color(blue, saturation: 1.12, contrast: 1.08, lift: -0.01))
            case .night800:
                return (color(red, saturation: 0.87, contrast: 1.08, lift: -0.018),
                        color(green, saturation: 0.87, contrast: 1.04, lift: 0.003),
                        color(blue, saturation: 0.91, contrast: 1.03, lift: 0.035))
            case .fade400:
                return (color(red, saturation: 0.72, contrast: 0.80, lift: 0.018),
                        color(green, saturation: 0.72, contrast: 0.80, lift: 0.009),
                        color(blue, saturation: 0.72, contrast: 0.80, lift: 0.002))
            case .mono800:
                let mono = (luminance - 0.5) * 1.10 + 0.515
                return (mono, mono, mono)
            }
        }
    }
}
