import Foundation

public enum CubeLUTError: Error, Equatable, LocalizedError {
    case fileTooLarge
    case invalidEncoding
    case missingSize
    case unsupportedDimension(Int)
    case unsupportedOneDimensional
    case duplicateDirective(String)
    case invalidDirective(line: Int)
    case unexpectedContent(line: Int)
    case unsupportedDomain
    case invalidSample(line: Int)
    case wrongSampleCount(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .fileTooLarge: return "Choose a .cube file no larger than 8 MB."
        case .invalidEncoding: return "This LUT must be a UTF-8 text .cube file."
        case .missingSize: return "The file is missing its LUT_3D_SIZE header."
        case .unsupportedDimension(let size): return "Lutli supports 17- and 33-point 3D LUTs, not \(size)-point LUTs."
        case .unsupportedOneDimensional: return "1D LUTs are not supported. Choose a 3D .cube LUT."
        case .duplicateDirective(let directive): return "The LUT repeats its \(directive) header."
        case .invalidDirective(let line): return "A LUT header on line \(line) is malformed or appears after sample data."
        case .unexpectedContent(let line): return "The LUT contains an unsupported header or invalid data on line \(line)."
        case .unsupportedDomain: return "Use a standard RGB LUT with DOMAIN_MIN 0 0 0 and DOMAIN_MAX 1 1 1."
        case .invalidSample(let line): return "LUT values on line \(line) must be finite RGB numbers from 0 to 1."
        case .wrongSampleCount(let expected, let actual): return "The LUT needs \(expected) RGB samples but contains \(actual)."
        }
    }
}

/// An SDR RGB cube in Core Image order: red changes fastest, then green, then blue.
/// Each sample has four Float components, with alpha fixed to 1.
public struct CubeLUT: Equatable, Sendable {
    public static let supportedDimensions: Set<Int> = [17, 33]
    public static let maximumFileSize = 8 * 1024 * 1024
    public static let maximumSampleCount = 33 * 33 * 33

    public let dimension: Int
    public let values: [Float]

    public init(dimension: Int, values: [Float]) throws {
        guard Self.supportedDimensions.contains(dimension) else {
            throw CubeLUTError.unsupportedDimension(dimension)
        }
        let expected = dimension * dimension * dimension
        guard values.count == expected * 4 else {
            throw CubeLUTError.wrongSampleCount(expected: expected, actual: values.count / 4)
        }
        for index in stride(from: 0, to: values.count, by: 4) {
            guard values[index..<(index + 3)].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
                  values[index + 3] == 1 else {
                throw CubeLUTError.invalidSample(line: index / 4 + 1)
            }
        }
        self.dimension = dimension
        self.values = values
    }

    // Used only by the parser and deterministic generators after validating their inputs.
    init(validatedDimension: Int, values: [Float]) {
        self.dimension = validatedDimension
        self.values = values
    }

    public var rgbaData: Data {
        values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    public static func parse(data: Data) throws -> CubeLUT {
        guard data.count <= maximumFileSize else { throw CubeLUTError.fileTooLarge }
        guard var content = String(data: data, encoding: .utf8) else { throw CubeLUTError.invalidEncoding }
        if content.first == "\u{FEFF}" { content.removeFirst() }

        var dimension: Int?
        var headers = Set<String>()
        var values: [Float] = []
        var sampleCount = 0

        // CRLF is one extended grapheme cluster in Swift; matching only "\n" misses it.
        for (offset, rawLine) in content.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).enumerated() {
            let lineNumber = offset + 1
            let line = removingComment(from: String(rawLine)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard let first = parts.first else { continue }

            if first == "LUT_1D_SIZE" { throw CubeLUTError.unsupportedOneDimensional }
            if ["TITLE", "LUT_3D_SIZE", "DOMAIN_MIN", "DOMAIN_MAX"].contains(first) {
                guard sampleCount == 0 else { throw CubeLUTError.invalidDirective(line: lineNumber) }
                guard headers.insert(first).inserted else { throw CubeLUTError.duplicateDirective(first) }
                switch first {
                case "TITLE":
                    let title = line.dropFirst(first.count).trimmingCharacters(in: .whitespaces)
                    guard title.count >= 2, title.first == "\"", title.last == "\"",
                          title.dropFirst().dropLast().filter({ $0 == "\"" }).isEmpty else {
                        throw CubeLUTError.invalidDirective(line: lineNumber)
                    }
                case "LUT_3D_SIZE":
                    guard parts.count == 2, let size = Int(parts[1]) else {
                        throw CubeLUTError.invalidDirective(line: lineNumber)
                    }
                    guard supportedDimensions.contains(size) else { throw CubeLUTError.unsupportedDimension(size) }
                    dimension = size
                    values.reserveCapacity(size * size * size * 4)
                default:
                    guard parts.count == 4 else { throw CubeLUTError.invalidDirective(line: lineNumber) }
                    let domain = parts.dropFirst().compactMap { Float($0) }
                    guard domain.count == 3, domain.allSatisfy(\.isFinite) else {
                        throw CubeLUTError.invalidDirective(line: lineNumber)
                    }
                    let expected: Float = first == "DOMAIN_MIN" ? 0 : 1
                    guard domain.allSatisfy({ $0 == expected }) else { throw CubeLUTError.unsupportedDomain }
                }
                continue
            }

            guard Float(first) != nil else { throw CubeLUTError.unexpectedContent(line: lineNumber) }
            guard let size = dimension else { throw CubeLUTError.missingSize }
            guard parts.count == 3 else { throw CubeLUTError.invalidSample(line: lineNumber) }
            let rgb = parts.compactMap { Float($0) }
            guard rgb.count == 3, rgb.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
                throw CubeLUTError.invalidSample(line: lineNumber)
            }
            sampleCount += 1
            let expected = size * size * size
            guard sampleCount <= expected else {
                throw CubeLUTError.wrongSampleCount(expected: expected, actual: sampleCount)
            }
            values.append(contentsOf: rgb)
            values.append(1)
        }

        guard let size = dimension else { throw CubeLUTError.missingSize }
        let expected = size * size * size
        guard sampleCount == expected else {
            throw CubeLUTError.wrongSampleCount(expected: expected, actual: sampleCount)
        }
        return CubeLUT(validatedDimension: size, values: values)
    }

    public static func identity(dimension: Int = 17) -> CubeLUT {
        precondition(supportedDimensions.contains(dimension), "Use a supported 17- or 33-point cube.")
        return sampled(dimension: dimension) { ($0, $1, $2) }
    }

    /// Interpolating each sample with identity preserves the LUT's grid and channel order.
    /// Invalid intensity becomes neutral; finite values are clamped to 0...1.
    public func blended(intensity: Double) -> CubeLUT {
        let amount = intensity.isFinite ? Float(min(1, max(0, intensity))) : 0
        guard amount != 1 else { return self }
        let neutral = Self.identity(dimension: dimension)
        guard amount != 0 else { return neutral }
        var output = values
        for index in output.indices where index % 4 != 3 {
            output[index] = neutral.values[index] + amount * (values[index] - neutral.values[index])
        }
        return CubeLUT(validatedDimension: dimension, values: output)
    }

    static func sampled(dimension: Int = 17, transform: (Float, Float, Float) -> (Float, Float, Float)) -> CubeLUT {
        var samples: [Float] = []
        samples.reserveCapacity(dimension * dimension * dimension * 4)
        let divisor = Float(dimension - 1)
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    let rgb = transform(Float(red) / divisor, Float(green) / divisor, Float(blue) / divisor)
                    samples.append(contentsOf: [rgb.0, rgb.1, rgb.2].map { min(1, max(0, $0)) })
                    samples.append(1)
                }
            }
        }
        return CubeLUT(validatedDimension: dimension, values: samples)
    }

    private static func removingComment(from line: String) -> String {
        var quoted = false
        for index in line.indices {
            if line[index] == "\"" { quoted.toggle() }
            if line[index] == "#", !quoted { return String(line[..<index]) }
        }
        return line
    }
}
