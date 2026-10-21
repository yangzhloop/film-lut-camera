import Foundation
import LutliCore
import SwiftUI
import UIKit

enum LookSelection: Hashable, Identifiable {
    case builtIn(BuiltInLook)
    case custom(UUID)

    var id: String {
        switch self {
        case .builtIn(let look): return "builtin:\(look.rawValue)"
        case .custom(let id): return "custom:\(id.uuidString)"
        }
    }
}

struct LookItem: Identifiable {
    let id: LookSelection
    let label: FilterLabel
}

struct LabelEditorDraft: Identifiable {
    enum Purpose {
        case imported(data: Data, lut: CubeLUT)
        case edit(id: UUID)
    }

    let id = UUID()
    let purpose: Purpose
    let label: FilterLabel
}

enum AppOperationError: LocalizedError {
    case libraryUnavailable
    case fileTooLarge
    case notAFile
    case missingLook

    var errorDescription: String? {
        switch self {
        case .libraryUnavailable:
            return "Your saved looks could not be opened. Existing files have been preserved. Built-in looks are still available."
        case .fileTooLarge:
            return "Choose a .cube file smaller than 8 MB."
        case .notAFile:
            return "Choose a .cube file, rather than a folder."
        case .missingLook:
            return "This look is no longer in your collection."
        }
    }
}

@MainActor
final class LutliAppModel: ObservableObject {
    let camera = CameraController()
    let customLookLimit = 5

    @Published private(set) var customLooks: [CustomLook] = []
    @Published private(set) var selection: LookSelection = .builtIn(.original)
    @Published private(set) var intensity: Double = 1
    // Diffusion belongs to this app session, independently of persisted LUT looks.
    @Published private(set) var diffusion = DiffusionState()
    @Published private(set) var isApplyingLook = false
    @Published private(set) var isLoadingLibrary = true
    @Published private(set) var libraryIssue: String?
    @Published var errorMessage: String?
    @Published private(set) var countdown: Int?

    @Published var saveOriginal: Bool {
        didSet { defaults.set(saveOriginal, forKey: Keys.saveOriginal) }
    }
    @Published var showGrid: Bool {
        didSet { defaults.set(showGrid, forKey: Keys.showGrid) }
    }
    @Published var timerSeconds: Int {
        didSet { defaults.set(timerSeconds, forKey: Keys.timer) }
    }
    @Published var rememberLastLook: Bool {
        didSet {
            defaults.set(rememberLastLook, forKey: Keys.rememberLook)
            if rememberLastLook {
                defaults.set(selection.id, forKey: Keys.selection)
            } else {
                defaults.removeObject(forKey: Keys.selection)
            }
        }
    }
    @Published var haptics: Bool {
        didSet { defaults.set(haptics, forKey: Keys.haptics) }
    }

    private let defaults: UserDefaults
    private let directory: URL
    private var library: LookLibrary?
    private var selectedLUT = CubeLUT.identity()
    private var builtinIntensities: [String: Double]
    private var prepared = false
    private var selectionRevision = 0
    private var countdownTask: Task<Void, Never>?

    private enum Keys {
        static let saveOriginal = "lutli.saveOriginal"
        static let showGrid = "lutli.showGrid"
        static let timer = "lutli.timerSeconds"
        static let rememberLook = "lutli.rememberLastLook"
        static let selection = "lutli.selectedLook"
        static let haptics = "lutli.haptics"
        static let intensities = "lutli.builtinIntensities"
    }

    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults
        self.directory = directory ?? URL.applicationSupportDirectory.appending(path: "Lutli/Looks", directoryHint: .isDirectory)
        saveOriginal = defaults.bool(forKey: Keys.saveOriginal)
        showGrid = defaults.bool(forKey: Keys.showGrid)
        let timer = defaults.integer(forKey: Keys.timer)
        timerSeconds = [0, 3, 10].contains(timer) ? timer : 0
        rememberLastLook = defaults.object(forKey: Keys.rememberLook) as? Bool ?? true
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        builtinIntensities = (defaults.dictionary(forKey: Keys.intensities) as? [String: Double] ?? [:])
            .filter { $0.value.isFinite && (0...1).contains($0.value) }
    }

    var lookItems: [LookItem] {
        BuiltInLook.allCases.map { LookItem(id: .builtIn($0), label: $0.label) }
            + customLooks.map { LookItem(id: .custom($0.id), label: $0.label) }
    }

    var selectedLabel: FilterLabel {
        lookItems.first(where: { $0.id == selection })?.label ?? BuiltInLook.original.label
    }

    var canImport: Bool {
        !isLoadingLibrary && libraryIssue == nil && customLooks.count < customLookLimit
    }

    func prepare() async {
        guard !prepared else { return }
        prepared = true
        let startupRevision = selectionRevision
        do {
            let location = directory
            let capacity = customLookLimit
            let repository = try await Task.detached(priority: .userInitiated) {
                try LookLibrary(directory: location, capacity: capacity)
            }.value
            library = repository
            customLooks = await repository.looks
        } catch {
            libraryIssue = error.localizedDescription
        }
        isLoadingLibrary = false
        // A look chosen while the library loads is more recent than launch restoration.
        guard selectionRevision == startupRevision else { return }
        let restored = rememberLastLook ? storedSelection() : nil
        await select(restored ?? .builtIn(.original))
    }

    func select(_ next: LookSelection) async {
        persistCurrentIntensity()
        selectionRevision += 1
        let revision = selectionRevision
        isApplyingLook = true
        do {
            let lut: CubeLUT
            let strength: Double
            switch next {
            case .builtIn(let builtIn):
                lut = builtIn.makeLUT()
                strength = builtinIntensities[builtIn.rawValue] ?? 1
            case .custom(let id):
                guard let record = customLooks.first(where: { $0.id == id }), let library else {
                    throw AppOperationError.missingLook
                }
                lut = try await library.lut(for: id)
                strength = record.intensity
            }
            guard revision == selectionRevision else { return }
            selection = next
            intensity = strength
            selectedLUT = lut
            camera.setLUT(lut.blended(intensity: strength))
            if rememberLastLook { defaults.set(next.id, forKey: Keys.selection) }
        } catch {
            guard revision == selectionRevision else { return }
            errorMessage = error.localizedDescription
            // Do not leave a failed look selected while another look is rendering.
            selection = .builtIn(.original)
            intensity = 1
            selectedLUT = CubeLUT.identity()
            camera.setLUT(selectedLUT)
            defaults.removeObject(forKey: Keys.selection)
        }
        if revision == selectionRevision { isApplyingLook = false }
    }

    func setIntensity(_ value: Double) {
        guard value.isFinite else { return }
        intensity = min(max(value, 0), 1)
        switch selection {
        case .builtIn(let look): builtinIntensities[look.rawValue] = intensity
        case .custom(let id):
            if let index = customLooks.firstIndex(where: { $0.id == id }) { customLooks[index].intensity = intensity }
        }
        camera.setLUT(selectedLUT.blended(intensity: intensity))
    }

    func selectDiffusion(_ effect: DiffusionEffect) {
        guard countdown == nil, !camera.isCapturing, !isApplyingLook else { return }
        var next = diffusion
        next.select(effect)
        applyDiffusion(next)
    }

    func setDiffusionStrength(_ value: Double) {
        guard countdown == nil, !camera.isCapturing, !isApplyingLook else { return }
        var next = diffusion
        next.setStrength(value)
        applyDiffusion(next)
    }

    func setDiffusionGlowColor(_ color: GlowColor) {
        guard countdown == nil, !camera.isCapturing, !isApplyingLook else { return }
        var next = diffusion
        next.setGlowColor(color)
        applyDiffusion(next)
    }

    private func applyDiffusion(_ next: DiffusionState) {
        guard next != diffusion else { return }
        diffusion = next
        camera.setDiffusion(next.settings)
    }

    func persistIntensity() async {
        await persistIntensity(for: selection, strength: intensity)
    }

    func persistCurrentIntensity() {
        // Capture the source look synchronously, before another tap can change selection.
        let source = selection
        let strength = intensity
        if case .custom(let id) = source, !customLooks.contains(where: { $0.id == id }) { return }
        Task { await persistIntensity(for: source, strength: strength) }
    }

    private func persistIntensity(for source: LookSelection, strength: Double) async {
        switch source {
        case .builtIn(let look):
            builtinIntensities[look.rawValue] = strength
            defaults.set(builtinIntensities, forKey: Keys.intensities)
        case .custom(let id):
            guard let library, customLooks.contains(where: { $0.id == id }) else { return }
            do {
                try await library.updateIntensity(id: id, intensity: strength)
                // The in-memory value was updated by the slider. Avoid replacing newer
                // slider edits with the snapshot from this completed disk write.
            } catch {
                if customLooks.contains(where: { $0.id == id }) { errorMessage = error.localizedDescription }
            }
        }
    }

    func importedDraft(from url: URL) async throws -> LabelEditorDraft {
        guard library != nil else { throw AppOperationError.libraryUnavailable }
        let (data, lut) = try await Task.detached(priority: .userInitiated) {
            let data = try Self.readLUTFile(url)
            return (data, try CubeLUT.parse(data: data))
        }.value
        let filename = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = String((filename.isEmpty ? "MY LOOK" : filename.uppercased()).prefix(FilterLabel.maxTextLength))
        let label = FilterLabel(topText: title, bottomText: "LUT", topColor: .indigo, bottomColor: .yellow)
        return LabelEditorDraft(purpose: .imported(data: data, lut: lut), label: label)
    }

    func saveLabel(_ label: FilterLabel, draft: LabelEditorDraft) async throws {
        guard let library else { throw AppOperationError.libraryUnavailable }
        let checked = try label.validated()
        let newlyImported: LookSelection?
        switch draft.purpose {
        case .imported(let data, _):
            let record = try await library.importLUT(data: data, label: checked)
            newlyImported = .custom(record.id)
        case .edit(let id):
            try await library.updateLabel(id: id, label: checked)
            // Label editing must not select an inactive look behind the editor.
            newlyImported = nil
        }
        customLooks = await library.looks
        if let newlyImported { await select(newlyImported) }
    }

    func replaceLook(id: UUID, from url: URL) async throws {
        guard let library else { throw AppOperationError.libraryUnavailable }
        let data = try await Task.detached(priority: .userInitiated) { try Self.readLUTFile(url) }.value
        try await library.replaceLUT(id: id, data: data)
        customLooks = await library.looks
        if selection == .custom(id) { await select(.custom(id)) }
    }

    func deleteLook(id: UUID) async throws {
        guard let library else { throw AppOperationError.libraryUnavailable }
        try await library.delete(id: id)
        customLooks = await library.looks
        if selection == .custom(id) { await select(.builtIn(.original)) }
    }

    func previewLUT(for draft: LabelEditorDraft) async throws -> CubeLUT {
        switch draft.purpose {
        case .imported(_, let lut): return lut
        case .edit(let id):
            guard let library else { throw AppOperationError.libraryUnavailable }
            return try await library.lut(for: id)
        }
    }

    func restoreSelectedPreview() {
        camera.setLUT(selectedLUT.blended(intensity: intensity))
    }

    func capture() {
        if countdown != nil {
            cancelCountdown()
            return
        }
        guard camera.isRunning, !camera.isCapturing, !camera.isSaving, !isApplyingLook, !isLoadingLibrary else { return }
        let delay = [0, 3, 10].contains(timerSeconds) ? timerSeconds : 0
        if delay == 0 {
            triggerHaptic()
            camera.capture(saveOriginal: saveOriginal)
            return
        }
        countdown = delay
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for remaining in stride(from: delay, through: 1, by: -1) {
                countdown = remaining
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            countdown = nil
            countdownTask = nil
            guard camera.isRunning else { return }
            triggerHaptic()
            camera.capture(saveOriginal: saveOriginal)
        }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
    }

    func triggerHaptic() {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func storedSelection() -> LookSelection? {
        guard let stored = defaults.string(forKey: Keys.selection) else { return nil }
        if stored.hasPrefix("builtin:"), let look = BuiltInLook(rawValue: String(stored.dropFirst(8))) {
            return .builtIn(look)
        }
        if stored.hasPrefix("custom:"), let id = UUID(uuidString: String(stored.dropFirst(7))), customLooks.contains(where: { $0.id == id }) {
            return .custom(id)
        }
        return nil
    }

    private nonisolated static func readLUTFile(_ url: URL) throws -> Data {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let resource = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard resource.isRegularFile != false else { throw AppOperationError.notAFile }
        guard (resource.fileSize ?? 0) <= 8 * 1_024 * 1_024 else { throw AppOperationError.fileTooLarge }
        // Bounded reading also handles providers that do not report a file size.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let maximum = 8 * 1_024 * 1_024
        var data = Data()
        while data.count <= maximum {
            let chunk = try handle.read(upToCount: min(64 * 1_024, maximum + 1 - data.count)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        guard data.count <= maximum else { throw AppOperationError.fileTooLarge }
        return data
    }
}
