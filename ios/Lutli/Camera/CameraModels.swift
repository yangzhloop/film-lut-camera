import AVFoundation
import CoreGraphics
import Foundation

enum CameraAuthorization: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum CameraWhiteBalance: Equatable {
    case auto
    case locked
    case manual(temperature: Float, tint: Float)
}

enum CameraFlashMode: String, CaseIterable {
    case off, auto, on

    var captureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .auto: return .auto
        case .on: return .on
        }
    }
}

struct CameraLens: Identifiable, Equatable {
    let id: String
    let title: String
    let isFront: Bool
}

struct CapturedPhoto: Identifiable {
    let id: UUID
    let createdAt: Date
    let image: CGImage
    let filteredJPEG: Data
    let originalJPEG: Data?
}

enum PhotoSavePhase: Equatable {
    case saving
    case saved
    case failed(message: String, needsPermission: Bool)
}

/// Ties the save outcome to the specific capture shown by a review sheet.
struct PhotoSaveStatus: Equatable {
    let photoID: UUID
    let phase: PhotoSavePhase
}

struct CameraCapabilities {
    let lenses: [CameraLens]
    let currentLensID: String
    let isFront: Bool
    let exposureBounds: ClosedRange<Double>
    let exposure: Double
    let supportsWhiteBalanceLock: Bool
    let supportsManualWhiteBalance: Bool
    let supportsFlash: Bool
}

enum CameraEvent {
    case preview(CGImage)
    case running(Bool)
    case capabilities(CameraCapabilities)
    case whiteBalanceChanged(CameraWhiteBalance)
    case captureFinished(CapturedPhoto)
    case captureFailed(String)
    case error(String)
    case interrupted(String)
    case interruptionEnded
}

enum CameraFailure: LocalizedError {
    case noCamera
    case unavailableInput
    case unavailableOutput
    case notRunning
    case noPhotoData
    case invalidPhotoData
    case unavailableFilter
    case renderingFailed
    case encodingFailed
    case whiteBalanceUnavailable

    var errorDescription: String? {
        switch self {
        case .noCamera: return "No camera is available on this device. You can still manage your looks."
        case .unavailableInput: return "This camera could not be connected. Try another lens or reopen the camera."
        case .unavailableOutput: return "The camera could not prepare photo capture. Please reopen the camera."
        case .notRunning: return "The camera is not ready to take a photo yet."
        case .noPhotoData: return "The camera did not return a photo. Please try again."
        case .invalidPhotoData: return "The captured photo could not be read. Please try again."
        case .unavailableFilter: return "The look could not be prepared on this device."
        case .renderingFailed: return "The photo could not be rendered. Please try again."
        case .encodingFailed: return "The photo could not be encoded. Please try again."
        case .whiteBalanceUnavailable: return "This camera does not support that white-balance mode."
        }
    }
}
