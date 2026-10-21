import Foundation
import Photos

struct PhotoLibraryWriter {
    enum Failure: LocalizedError, Equatable {
        case accessDenied
        case savingFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Photo saving access was not allowed. Your photo is still available to review or share. You can enable photo saving in Settings."
            case .savingFailed:
                return "The photo could not be saved to Photos. It is still available to review or share."
            }
        }
    }

    /// Requests only add access. The app never needs to read the user's library.
    /// Both copies are created in one Photos transaction when an original is requested.
    func save(_ photo: CapturedPhoto) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw Failure.accessDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let filtered = PHAssetCreationRequest.forAsset()
                filtered.creationDate = photo.createdAt
                filtered.addResource(with: .photo, data: photo.filteredJPEG, options: nil)
                if let originalJPEG = photo.originalJPEG {
                    let original = PHAssetCreationRequest.forAsset()
                    original.creationDate = photo.createdAt
                    original.addResource(with: .photo, data: originalJPEG, options: nil)
                }
            }
        } catch {
            let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if currentStatus == .denied || currentStatus == .restricted { throw Failure.accessDenied }
            throw Failure.savingFailed
        }
    }
}
