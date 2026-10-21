import Foundation
import XCTest
@testable import LutliCore

final class LookLibraryTests: XCTestCase {
    private var directory: URL!
    private let label = FilterLabel(topText: "DAYLIGHT", bottomText: "400", topColor: .indigo, bottomColor: .yellow)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("lutli-library-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testImportPersistsRecordsAndCubeAcrossReload() async throws {
        let library = try LookLibrary(directory: directory)
        let expected = try CubeLUT.parse(data: identityCubeData())
        let record = try await library.importLUT(data: identityCubeData(), label: label)
        let records = await library.looks
        XCTAssertEqual(records, [record])
        XCTAssertEqual(record.intensity, 1)
        let reloaded = try LookLibrary(directory: directory)
        let stored = await reloaded.looks
        let cube = try await reloaded.lut(for: record.id)
        XCTAssertEqual(stored, [record])
        XCTAssertEqual(cube, expected)
        let filenames = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(Set(filenames), ["library.json", record.id.uuidString.lowercased() + ".cube"])
    }

    func testCapacityRejectsSixthImportWithoutChangingLibrary() async throws {
        let library = try LookLibrary(directory: directory)
        for _ in 0..<5 { try await library.importLUT(data: constantCubeData(), label: label) }
        let before = await library.looks
        let beforeIndex = try Data(contentsOf: directory.appendingPathComponent("library.json"))
        do {
            try await library.importLUT(data: constantCubeData(), label: label)
            XCTFail("A sixth custom look should not fit.")
        } catch {
            XCTAssertEqual(error as? LookLibraryError, .capacityReached(maximum: 5))
        }
        let after = await library.looks
        XCTAssertEqual(after, before)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("library.json")), beforeIndex)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 6)
    }

    func testConcurrentImportsCannotExceedCapacity() async throws {
        let library = try LookLibrary(directory: directory)
        let label = self.label
        let data = constantCubeData()
        let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    do {
                        try await library.importLUT(data: data, label: label)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var count = 0
            for await success in group where success { count += 1 }
            return count
        }
        let records = await library.looks
        XCTAssertEqual(successes, 5)
        XCTAssertEqual(records.count, 5)
        XCTAssertEqual(Set(records.map(\.id)).count, 5)
    }

    func testInvalidImportLeavesExistingFilesAndRecordsUntouched() async throws {
        let library = try LookLibrary(directory: directory)
        let record = try await library.importLUT(data: constantCubeData(), label: label)
        let beforeIndex = try Data(contentsOf: directory.appendingPathComponent("library.json"))
        do {
            try await library.importLUT(data: Data("LUT_3D_SIZE 17\n0 0 0".utf8), label: label)
            XCTFail("Malformed import should fail.")
        } catch { XCTAssertTrue(error is CubeLUTError) }
        let records = await library.looks
        XCTAssertEqual(records, [record])
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("library.json")), beforeIndex)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2)
    }

    func testReplaceAtCapacityPreservesIdentityLabelIntensityAndPosition() async throws {
        let library = try LookLibrary(directory: directory, capacity: 1)
        let record = try await library.importLUT(data: constantCubeData(), label: label)
        try await library.updateIntensity(id: record.id, intensity: 0.42)
        let before = await library.looks
        try await library.replaceLUT(id: record.id, data: constantCubeData(rgb: "0.1 0.2 0.3"))
        let after = await library.looks
        let cube = try await library.lut(for: record.id)
        XCTAssertEqual(after, before)
        XCTAssertEqual(Array(cube.values.prefix(4)), [0.1, 0.2, 0.3, 1])
        let reloaded = try LookLibrary(directory: directory, capacity: 1)
        let reloadedCube = try await reloaded.lut(for: record.id)
        XCTAssertEqual(reloadedCube, cube)
    }

    func testInvalidReplacementPreservesOldCube() async throws {
        let library = try LookLibrary(directory: directory)
        let record = try await library.importLUT(data: constantCubeData(rgb: "0.1 0.2 0.3"), label: label)
        let before = try await library.lut(for: record.id)
        do {
            try await library.replaceLUT(id: record.id, data: Data("bad".utf8))
            XCTFail("Invalid replacement should fail.")
        } catch { XCTAssertTrue(error is CubeLUTError) }
        let after = try await library.lut(for: record.id)
        XCTAssertEqual(after, before)
    }

    func testLabelAndIntensityUpdatesPersist() async throws {
        let library = try LookLibrary(directory: directory)
        let record = try await library.importLUT(data: constantCubeData(), label: label)
        let newLabel = FilterLabel(topText: "  BLUE ", bottomText: "HOUR", topColor: .slate, bottomColor: .violet)
        try await library.updateLabel(id: record.id, label: newLabel)
        try await library.updateIntensity(id: record.id, intensity: 0)
        let reloaded = try LookLibrary(directory: directory)
        let records = await reloaded.looks
        XCTAssertEqual(records.first?.label, try newLabel.validated())
        XCTAssertEqual(records.first?.intensity, 0)
    }

    func testInvalidIntensityDoesNotChangeStoredValue() async throws {
        let library = try LookLibrary(directory: directory)
        let record = try await library.importLUT(data: constantCubeData(), label: label)
        for intensity in [Double.nan, Double.infinity, -0.1, 1.1] {
            do {
                try await library.updateIntensity(id: record.id, intensity: intensity)
                XCTFail("Invalid intensity should fail.")
            } catch { XCTAssertEqual(error as? LookLibraryError, .invalidIntensity) }
        }
        let records = await library.looks
        XCTAssertEqual(records, [record])
    }

    func testDeleteFreesSlotAndRemovesOnlyTargetFile() async throws {
        let library = try LookLibrary(directory: directory, capacity: 2)
        let first = try await library.importLUT(data: constantCubeData(), label: label)
        let second = try await library.importLUT(data: identityCubeData(), label: label)
        try await library.delete(id: first.id)
        let after = await library.looks
        XCTAssertEqual(after, [second])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(first.id.uuidString.lowercased() + ".cube").path))
        let third = try await library.importLUT(data: constantCubeData(), label: label)
        let final = await library.looks
        XCTAssertEqual(final.map(\.id), [second.id, third.id])
        let reloaded = try LookLibrary(directory: directory, capacity: 2)
        let durable = await reloaded.looks
        XCTAssertEqual(durable, final)
    }

    func testUnknownIdentityDoesNotMutateLibrary() async throws {
        let library = try LookLibrary(directory: directory)
        do {
            try await library.delete(id: UUID())
            XCTFail("Unknown look should fail.")
        } catch { XCTAssertEqual(error as? LookLibraryError, .lookNotFound) }
        let records = await library.looks
        XCTAssertTrue(records.isEmpty)
    }

    func testFailedIndexWriteRollsBackImportAndInMemoryState() async throws {
        let library = try LookLibrary(directory: directory)
        // An index path occupied by a directory makes atomic JSON replacement fail.
        let blocker = directory.appendingPathComponent("library.json", isDirectory: true)
        try FileManager.default.createDirectory(at: blocker, withIntermediateDirectories: false)
        do {
            try await library.importLUT(data: constantCubeData(), label: label)
            XCTFail("Index write must fail.")
        } catch { }
        let records = await library.looks
        XCTAssertTrue(records.isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["library.json"])
    }

    func testFailedIndexWritePreservesExistingRecordAndCube() async throws {
        let library = try LookLibrary(directory: directory)
        let record = try await library.importLUT(data: constantCubeData(), label: label)
        let indexURL = directory.appendingPathComponent("library.json")
        try FileManager.default.removeItem(at: indexURL)
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: false)
        do {
            try await library.delete(id: record.id)
            XCTFail("Failed index update must not delete the cube.")
        } catch { }
        let records = await library.looks
        let cube = try await library.lut(for: record.id)
        XCTAssertEqual(records, [record])
        XCTAssertEqual(cube.dimension, 17)
    }

    func testCorruptMetadataIsPreservedAndReported() throws {
        let url = directory.appendingPathComponent("library.json")
        let original = Data("not valid JSON".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try LookLibrary(directory: directory)) {
            XCTAssertEqual($0 as? LookLibraryError, .corruptLibrary)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testMissingReferencedCubeIsReportedWithoutResettingIndex() async throws {
        let library = try LookLibrary(directory: directory)
        let record = try await library.importLUT(data: constantCubeData(), label: label)
        let index = try Data(contentsOf: directory.appendingPathComponent("library.json"))
        try FileManager.default.removeItem(at: directory.appendingPathComponent(record.id.uuidString.lowercased() + ".cube"))
        XCTAssertThrowsError(try LookLibrary(directory: directory)) {
            XCTAssertEqual($0 as? LookLibraryError, .corruptLibrary)
        }
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("library.json")), index)
    }

    func testDuplicateIDsAndUnknownIndexVersionsAreRejected() async throws {
        let library = try LookLibrary(directory: directory)
        let record = try await library.importLUT(data: constantCubeData(), label: label)
        let indexURL = directory.appendingPathComponent("library.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: indexURL)) as! [String: Any]
        var duplicate = object
        let records = object["looks"] as! [[String: Any]]
        duplicate["looks"] = records + records
        try JSONSerialization.data(withJSONObject: duplicate).write(to: indexURL)
        XCTAssertThrowsError(try LookLibrary(directory: directory))
        var unknownVersion = object
        unknownVersion["version"] = 99
        try JSONSerialization.data(withJSONObject: unknownVersion).write(to: indexURL)
        XCTAssertThrowsError(try LookLibrary(directory: directory))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(record.id.uuidString.lowercased() + ".cube").path))
    }

    func testSymlinkedCubeIsRejectedOnReload() async throws {
        let library = try LookLibrary(directory: directory)
        let record = try await library.importLUT(data: constantCubeData(), label: label)
        let path = directory.appendingPathComponent(record.id.uuidString.lowercased() + ".cube")
        let replacement = directory.appendingPathComponent("external.cube")
        try constantCubeData().write(to: replacement)
        try FileManager.default.removeItem(at: path)
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: replacement)
        XCTAssertThrowsError(try LookLibrary(directory: directory)) {
            XCTAssertEqual($0 as? LookLibraryError, .corruptLibrary)
        }
    }
}
