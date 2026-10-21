import Foundation

public enum LabelColor: String, Codable, CaseIterable, Sendable {
    case indigo, yellow, green, cream, red, violet, charcoal, slate

    public var hex: String {
        switch self {
        case .indigo: return "414BCB"
        case .yellow: return "F7D934"
        case .green: return "3F6F4D"
        case .cream: return "EFE6CC"
        case .red: return "C95D56"
        case .violet: return "8355B4"
        case .charcoal: return "3E3E42"
        case .slate: return "29465B"
        }
    }

    /// Choose the stronger WCAG contrast of black and white for each fixed palette color.
    public var foregroundHex: String {
        let rgb = UInt32(hex, radix: 16) ?? 0
        func linear(_ component: UInt32) -> Double {
            let value = Double(component) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear((rgb >> 16) & 255)
            + 0.7152 * linear((rgb >> 8) & 255)
            + 0.0722 * linear(rgb & 255)
        return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? "000000" : "FFFFFF"
    }
}

public enum FilterLabelError: Error, Equatable, LocalizedError {
    case emptyText
    case textTooLong
    case invalidCharacters

    public var errorDescription: String? {
        switch self {
        case .emptyText: return "Enter text for both sections of the label."
        case .textTooLong: return "Keep each label section to 12 characters or fewer."
        case .invalidCharacters: return "Use a single line of text for each label section."
        }
    }
}

public struct FilterLabel: Codable, Equatable, Sendable {
    public static let maxTextLength = 12
    public var topText: String
    public var bottomText: String
    public var topColor: LabelColor
    public var bottomColor: LabelColor

    public init(topText: String, bottomText: String, topColor: LabelColor, bottomColor: LabelColor) {
        self.topText = topText
        self.bottomText = bottomText
        self.topColor = topColor
        self.bottomColor = bottomColor
    }

    public func validated() throws -> FilterLabel {
        let top = topText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bottom = bottomText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !top.isEmpty, !bottom.isEmpty else { throw FilterLabelError.emptyText }
        guard top.count <= Self.maxTextLength, bottom.count <= Self.maxTextLength else {
            throw FilterLabelError.textTooLong
        }
        let forbidden = CharacterSet.controlCharacters.union(.newlines)
        guard !top.unicodeScalars.contains(where: { forbidden.contains($0) }),
              !bottom.unicodeScalars.contains(where: { forbidden.contains($0) }) else {
            throw FilterLabelError.invalidCharacters
        }
        return FilterLabel(topText: top, bottomText: bottom, topColor: topColor, bottomColor: bottomColor)
    }
}
