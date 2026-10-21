import Foundation

public struct CustomLook: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var label: FilterLabel
    public var intensity: Double

    public init(id: UUID = UUID(), label: FilterLabel, intensity: Double = 1) {
        self.id = id
        self.label = label
        self.intensity = intensity
    }
}

public enum LookLibraryError: Error, Equatable, LocalizedError {
    case capacityReached(maximum: Int)
    case lookNotFound
    case invalidIntensity
    case invalidCapacity
    case corruptLibrary

    public var errorDescription: String? {
        switch self {
        case .capacityReached(let maximum): return "All \(maximum) custom slots are in use. Replace or remove a look before importing another."
        case .lookNotFound: return "This custom look is no longer in your library."
        case .invalidIntensity: return "Look intensity must be between 0% and 100%."
        case .invalidCapacity: return "The custom look capacity must be between one and five."
        case .corruptLibrary: return "Your saved looks could not be loaded. Their files have been preserved; do not reset the library without a backup."
        }
    }
}

/// Serializes mutation of an on-device collection. Imported filenames never become paths:
/// this store generates UUID-based filenames, and its JSON index contains no paths.
public actor LookLibrary {
    public static let maximumCapacity = 5
    public private(set) var looks: [CustomLook]
    public let capacity: Int

    private let directory: URL
    private let indexURL: URL
    private let fileManager: FileManager

    private struct Index: Codable {
        let version: Int
        let looks: [CustomLook]
    }

    public init(directory: URL, capacity: Int = 5) throws {
        guard (1...Self.maximumCapacity).contains(capacity) else { throw LookLibraryError.invalidCapacity }
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let indexURL = directory.appendingPathComponent("library.json", isDirectory: false)
        let loaded: [CustomLook]
        if manager.fileExists(atPath: indexURL.path) {
            do {
                try Self.validateRegularFile(indexURL, maximumSize: 64 * 1024)
                let index = try JSONDecoder().decode(Index.self, from: Data(contentsOf: indexURL))
                guard index.version == 1, index.looks.count <= capacity,
                      Set(index.looks.map(\.id)).count == index.looks.count else {
                    throw LookLibraryError.corruptLibrary
                }
                for look in index.looks {
                    guard try look.label.validated() == look.label,
                          look.intensity.isFinite, (0...1).contains(look.intensity) else {
                        throw LookLibraryError.corruptLibrary
                    }
                    let file = Self.fileURL(id: look.id, directory: directory)
                    try Self.validateRegularFile(file, maximumSize: CubeLUT.maximumFileSize)
                    _ = try CubeLUT.parse(data: Data(contentsOf: file))
                }
                loaded = index.looks
            } catch {
                // Never reset the index or delete LUTs when saved data is unreadable.
                throw LookLibraryError.corruptLibrary
            }
        } else {
            loaded = []
        }
        self.directory = directory
        self.indexURL = indexURL
        self.capacity = capacity
        self.fileManager = manager
        self.looks = loaded
    }

    @discardableResult
    public func importLUT(data: Data, label: FilterLabel) throws -> CustomLook {
        guard looks.count < capacity else { throw LookLibraryError.capacityReached(maximum: capacity) }
        let validatedLabel = try label.validated()
        _ = try CubeLUT.parse(data: data)
        let look = CustomLook(label: validatedLabel)
        let file = Self.fileURL(id: look.id, directory: directory)
        try data.write(to: file, options: .atomic)
        let updated = looks + [look]
        do {
            try persist(updated)
        } catch {
            // A failed index update must not consume a slot or change the active collection.
            // Only the new, unreferenced file may remain if cleanup itself fails.
            try? fileManager.removeItem(at: file)
            throw error
        }
        looks = updated
        return look
    }

    public func updateLabel(id: UUID, label: FilterLabel) throws {
        let label = try label.validated()
        guard let index = looks.firstIndex(where: { $0.id == id }) else { throw LookLibraryError.lookNotFound }
        var updated = looks
        updated[index].label = label
        try persist(updated)
        looks = updated
    }

    public func updateIntensity(id: UUID, intensity: Double) throws {
        guard intensity.isFinite, (0...1).contains(intensity) else { throw LookLibraryError.invalidIntensity }
        guard let index = looks.firstIndex(where: { $0.id == id }) else { throw LookLibraryError.lookNotFound }
        var updated = looks
        updated[index].intensity = intensity
        try persist(updated)
        looks = updated
    }

    /// Replacement preserves identity, label, intensity and position, including at full capacity.
    public func replaceLUT(id: UUID, data: Data) throws {
        guard looks.contains(where: { $0.id == id }) else { throw LookLibraryError.lookNotFound }
        _ = try CubeLUT.parse(data: data)
        // Atomic replacement leaves the old LUT intact if writing the new file fails.
        try data.write(to: Self.fileURL(id: id, directory: directory), options: .atomic)
    }

    public func delete(id: UUID) throws {
        guard looks.contains(where: { $0.id == id }) else { throw LookLibraryError.lookNotFound }
        let updated = looks.filter { $0.id != id }
        // Commit the index first. A crash during cleanup can leave an unreferenced file,
        // but can never leave the live index referring to a deleted LUT.
        try persist(updated)
        looks = updated
        try? fileManager.removeItem(at: Self.fileURL(id: id, directory: directory))
    }

    public func lut(for id: UUID) throws -> CubeLUT {
        guard looks.contains(where: { $0.id == id }) else { throw LookLibraryError.lookNotFound }
        let file = Self.fileURL(id: id, directory: directory)
        try Self.validateRegularFile(file, maximumSize: CubeLUT.maximumFileSize)
        return try CubeLUT.parse(data: Data(contentsOf: file))
    }

    private func persist(_ updated: [CustomLook]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Index(version: 1, looks: updated))
        try data.write(to: indexURL, options: .atomic)
    }

    private static func fileURL(id: UUID, directory: URL) -> URL {
        directory.appendingPathComponent(id.uuidString.lowercased() + ".cube", isDirectory: false)
    }

    private static func validateRegularFile(_ file: URL, maximumSize: Int) throws {
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= maximumSize else {
            throw LookLibraryError.corruptLibrary
        }
    }
}
